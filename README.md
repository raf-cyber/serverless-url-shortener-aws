# Serverless URL Shortener on AWS (LocalStack)

A serverless URL shortener built on AWS architecture, simulated locally using LocalStack. Takes a long URL, stores it in DynamoDB with a generated short code, and redirects users when they visit the short URL.

## Architecture

```
API Gateway → Lambda (Python) → DynamoDB
```

- **API Gateway** — exposes two routes: `POST /shorten` and `GET /{short_code}`
- **Lambda** — single handler that checks the HTTP method and either shortens or redirects
- **DynamoDB** — stores short code → long URL mappings
- **CloudWatch Logs** — captures Lambda logs with 14-day retention
- **IAM** — least-privilege role allowing only `PutItem`, `GetItem`, and CloudWatch log writes

## Project Structure

```
serverless-url-shortener/
├── lambda/
│   └── handler.py       # Lambda function — handles POST and GET logic
├── main.tf              # All AWS infrastructure defined in Terraform
└── README.md
```

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) — LocalStack runs inside Docker
- [LocalStack](https://localstack.cloud/) — simulates AWS locally (no real AWS account needed)
- [Terraform](https://developer.hashicorp.com/terraform/install) v1.0+
- [AWS CLI](https://aws.amazon.com/cli/) — configured with dummy credentials for LocalStack
- Python 3.x

## Setup

### 1. Configure AWS CLI for LocalStack

```bash
aws configure
# Access Key: test
# Secret Key: test
# Region: us-east-1
# Output: json
```

### 2. Start LocalStack

```bash
# Terminal 1
localstack start
```

### 3. Deploy Infrastructure

```bash
# Terminal 2 — in project root
terraform init
terraform apply
```

## Testing

### Shorten a URL

```powershell
Invoke-WebRequest -Uri "http://localhost:4566/restapis/<api-id>/dev/_user_request_/shorten" `
  -Method POST `
  -ContentType "application/json" `
  -Body '{"url": "https://google.com"}'
```

Response:

```json
{
  "short_code": "oK0gcp",
  "short_url": "http://localhost:4566/oK0gcp"
}
```

### Redirect via Short Code

```powershell
Invoke-WebRequest -Uri "http://localhost:4566/restapis/<api-id>/dev/_user_request_/oK0gcp" `
  -Method GET
```

Returns the contents of the original long URL (302 redirect).

> **Note:** Replace `<api-id>` with the actual API Gateway ID from your `terraform apply` output.

### View CloudWatch Logs

```bash
# List log streams
aws --endpoint-url=http://localhost:4566 logs describe-log-streams \
  --log-group-name /aws/lambda/url-shortener

# View log events (replace stream name with actual value)
aws --endpoint-url=http://localhost:4566 logs get-log-events \
  --log-group-name /aws/lambda/url-shortener \
  --log-stream-name "2026/03/14/[$LATEST]<stream-id>"
```

### Invoke Lambda Directly

```bash
aws --endpoint-url=http://localhost:4566 lambda invoke \
  --function-name url-shortener \
  --payload fileb://payload.json \
  --cli-binary-format raw-in-base64-out \
  response.json
```

## Restarting a Session

Each time you restart your machine:

1. Open Docker Desktop and wait for "Engine running"
2. Terminal 1: `localstack start`
3. Terminal 2: navigate to project folder and run `terraform apply`

## What I Learned

- How to build a serverless architecture using API Gateway, Lambda, and DynamoDB
- Writing Infrastructure as Code with Terraform — defining every AWS resource declaratively
- IAM least-privilege principle — scoping policies to only the exact actions and resources needed
- How CloudWatch Logs works — log groups, streams, and events
- Simulating AWS locally with LocalStack — no credit card or real AWS account required
- Debugging cloud infrastructure on Windows using PowerShell
