provider "aws" {
  access_key                  = "test"
  secret_key                  = "test"
  region                      = "us-east-1"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    s3         = "http://localhost:4566"
    dynamodb   = "http://localhost:4566"
    lambda     = "http://localhost:4566"
    iam        = "http://localhost:4566"
    apigateway = "http://localhost:4566"
  }
}

resource "aws_dynamodb_table" "url_table" {
  name = "url-shortener"
  billing_mode = "PAY_PER_REQUEST"
  hash_key = "short_code"

  attribute {
    name = "short_code"
    type = "S"
  }
}


resource "aws_iam_role" "lambda_role" {
  name = "lambda-url-shortener-role"

  assume_role_policy = jsonencode ({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {Service = "lambda.amazonaws.com"}
    }]
  })
}


resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda-dynamodb-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode ({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:PutItem",
        "dynamodb:GetItem"
      ]
      Resource = aws_dynamodb_table.url_table.arn
    }]
  })
}

data "archive_file" "lambda_zip" {
  type = "zip"
  source_file = "lambda/handler.py"
  output_path = "lambda/handler.zip"
}

resource "aws_lambda_function" "url_shortener" {
  filename = "lambda/handler.zip"
  function_name = "url-shortener"
  role = aws_iam_role.lambda_role.arn
  handler = "handler.lambda_handler"
  runtime = "python3.11"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
}


resource "aws_api_gateway_rest_api" "url_shortener_api" {
  name = "url-shortener-api"
}

resource "aws_api_gateway_resource" "shorten_resource" {
  rest_api_id = aws_api_gateway_rest_api.url_shortener_api.id
  parent_id = aws_api_gateway_rest_api.url_shortener_api.root_resource_id
  path_part = "shorten"
}

resource "aws_api_gateway_resource" "redirect_resource" {
  rest_api_id = aws_api_gateway_rest_api.url_shortener_api.id
  parent_id = aws_api_gateway_rest_api.url_shortener_api.root_resource_id
  path_part = "{short_code}"
}

resource "aws_api_gateway_method" "shorten_method" {
  rest_api_id = aws_api_gateway_rest_api.url_shortener_api.id
  resource_id = aws_api_gateway_resource.shorten_resource.id
  http_method = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "redirect_method" {
  rest_api_id = aws_api_gateway_rest_api.url_shortener_api.id
  resource_id = aws_api_gateway_resource.redirect_resource.id
  http_method = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "shorten_integration" {
  rest_api_id = aws_api_gateway_rest_api.url_shortener_api.id
  resource_id = aws_api_gateway_resource.shorten_resource.id
  http_method = "POST"
  integration_http_method = "POST"
  type = "AWS_PROXY"
  uri = aws_lambda_function.url_shortener.invoke_arn
}

resource "aws_api_gateway_integration" "redirect_integration" {
  rest_api_id = aws_api_gateway_rest_api.url_shortener_api.id
  resource_id = aws_api_gateway_resource.redirect_resource.id
  http_method = "GET"
  integration_http_method = "POST"
  type = "AWS_PROXY"
  uri = aws_lambda_function.url_shortener.invoke_arn
}

resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.url_shortener_api.id

  depends_on = [
    aws_api_gateway_integration.shorten_integration,
    aws_api_gateway_integration.redirect_integration
  ]
}

resource "aws_api_gateway_stage" "api_stage" {
  rest_api_id   = aws_api_gateway_rest_api.url_shortener_api.id
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  stage_name    = "dev"
}

resource "aws_lambda_permission" "api_gateway_permission" {
  statement_id = "AllowAPIGatewayInvoke"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.url_shortener.function_name
  principal = "apigateway.amazonaws.com"
  source_arn = "${aws_api_gateway_rest_api.url_shortener_api.execution_arn}/*/*"
}