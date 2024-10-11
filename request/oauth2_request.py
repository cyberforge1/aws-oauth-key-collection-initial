# request/oauth2_request.py

# For testing only

import base64
import os
import requests
import json
from dotenv import load_dotenv

load_dotenv()

api_key = os.getenv('API_KEY')
api_secret = os.getenv('API_SECRET')
authorization_header = f"Basic {base64.b64encode(f'{api_key}:{api_secret}'.encode()).decode()}"

file_name = 'credentials.txt'

s3_bucket_name = os.getenv('S3_BUCKET_NAME')
sns_topic_arn = os.getenv('SNS_TOPIC_ARN')
region_name = os.getenv('REGION_NAME', 'ap-southeast-2')

url = "https://api.onegov.nsw.gov.au/oauth/client_credential/accesstoken"
querystring = {"grant_type": "client_credentials"}
headers = {'authorization': authorization_header}

try:
    response = requests.get(url, headers=headers, params=querystring)
    response.raise_for_status()
    response_data = response.json()
except requests.exceptions.RequestException as e:
    print(f"HTTP Request failed: {e}")
    exit(1)

access_token = response_data.get('access_token')

if access_token:
    credentials = {
        'api_key': api_key,
        'api_secret': api_secret,
        'access_token': access_token
    }

    try:
        with open(file_name, 'w') as file:
            json.dump(credentials, file)
        print(f"Credentials saved locally as {file_name}")
    except Exception as e:
        print(f"Error saving credentials to file: {e}")

    # # CLOUD UPLOAD
    # s3_client = boto3.client('s3')
    # s3_client.put_object(
    #     Bucket=s3_bucket_name,
    #     Key=file_name,
    #     Body=access_token
    # )
    # print(f"Access token uploaded to S3 bucket {s3_bucket_name} as {file_name}")

    # # Publish a message to SNS topic
    # sns_client = boto3.client('sns', region_name=region_name)
    # sns_message = f"Local script executed successfully. Access token stored in S3 bucket {s3_bucket_name} as {file_name}."
    # sns_subject = "Local Script Execution Success"

    # sns_client.publish(
    #     TopicArn=sns_topic_arn,
    #     Message=sns_message,
    #     Subject=sns_subject
    # )
    # print("Success notification sent via SNS.")

else:
    print("Error: 'access_token' not found in the response")
    print("Response data:", response_data)
