import json
import boto3
import string
import random


dynamo_db = boto3.resource('dynamodb', endpoint_url = 'http://host.docker.internal:4566')
table = dynamo_db.Table('url-shortener')


def generate_short_code():
    return ''.join(random.choices(string.ascii_letters + string.digits, k = 6))

def lambda_handler(event, context):
    

    if event.get('httpMethod') == 'POST':
        body = json.loads(event.get('body', '{}'))
        long_url = body.get('url')
        if not long_url:
            return{
                'statusCode' : 400,
                'body' : json.dumps({'error' : 'url is required'})
            }
        
        short_code = generate_short_code()

        table.put_item(Item ={
            'short_code' : short_code,
            'long_url' : long_url
        })

        return {
            'statusCode' : 200,
            'body' : json.dumps(
                {
                    'short_code' : short_code,
                    'short_url' : f'http://localhost:4566/{short_code}'
                }
            )
        }
    elif event.get('httpMethod') == 'GET':
        shortCode = event.get('pathParameters', {}).get('short_code')

        response = table.get_item(
            Key = {
            'short_code' : shortCode
        })

        item = response.get('Item')
        

        if not item:
            return {'statusCode' : 404, 'body' : json.dumps({'error' : 'URL not found'})}

        longUrl = item.get('long_url')
        
        return {
            'statusCode' : 302,
            'headers' : {'Location' : longUrl}
        }

        
