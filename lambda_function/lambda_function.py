# lambda_function/lambda_function.py

import boto3
import base64
import os
import requests
import json

def lambda_handler(event, context):
    secret_name = os.getenv('SECRET_NAME')
    region_name = os.getenv('REGION_NAME', 'ap-southeast-2')
    s3_bucket_name = os.getenv('S3_BUCKET_NAME')
    sns_topic_arn = os.getenv('SNS_TOPIC_ARN')
    file_name = 'access_token.txt'

    session = boto3.session.Session()
    client = session.client(
        service_name='secretsmanager',
        region_name=region_name
    )

    try:
        get_secret_value_response = client.get_secret_value(
            SecretId=secret_name
        )
        secret = json.loads(get_secret_value_response['SecretString'])
        api_key = secret['api_key']
        api_secret = secret['api_secret']
        authorization_header = f"Basic {base64.b64encode(f'{api_key}:{api_secret}'.encode()).decode()}"
    except Exception as e:
        print(f"Error retrieving secrets: {e}")
        raise e

    url = "https://api.onegov.nsw.gov.au/oauth/client_credential/accesstoken"
    querystring = {"grant_type": "client_credentials"}
    headers = {'authorization': authorization_header}

    try:
        response = requests.get(url, headers=headers, params=querystring)
        response.raise_for_status()
        response_data = response.json()
    except requests.exceptions.RequestException as e:
        print(f"HTTP Request failed: {e}")
        raise e

    access_token = response_data.get('access_token')

    if access_token:
        try:
            s3_client = boto3.client('s3')
            s3_client.put_object(
                Bucket=s3_bucket_name,
                Key=file_name,
                Body=access_token
            )
            print(f"Access token uploaded to S3 bucket {s3_bucket_name} as {file_name}")

            sns_client = boto3.client('sns', region_name=region_name)
            sns_message = f"Lambda function executed successfully. Access token stored in S3 bucket {s3_bucket_name} as {file_name}."
            sns_subject = "Lambda Function Execution Success"

            sns_client.publish(
                TopicArn=sns_topic_arn,
                Message=sns_message,
                Subject=sns_subject
            )
            print("Success notification sent via SNS.")
        except Exception as e:
            print(f"Error uploading to S3 or sending SNS notification: {e}")
            raise e
    else:
        print("Error: 'access_token' not found in the response")
        print("Response data:", response_data)
        raise Exception("'access_token' not found in the response")
