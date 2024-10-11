# AWS OAuth Key Collection Project

## Project Overview
A Terraform-provisioned AWS pipeline automating OAuth token retrieval from an external API, utilising Lambda, EventBridge, and S3 for efficient orchestration and storage.

AWS Lambda automates the token retrieval process, S3 ensures secure storage with encryption, Secrets Manager safely stores and manages credentials, and SNS sends notifications for successful or failed executions. The entire process is triggered automatically on a schedule managed by CloudWatch Events.

## Screenshot
![Project Diagram](diagrams/aws-oauth-key-diagram-dark.png)

## AWS Services

### 1. AWS Lambda
- **Function**: The core of this project. A Lambda function is used to retrieve an OAuth access token from an external API and store it in an S3 bucket.
- **Handler**: The Lambda function handler is `lambda_function.lambda_handler`, written in Python. It performs the following tasks:
  1. Fetches the OAuth access token using API credentials.
  2. Stores the token in an S3 bucket.
  3. Sends a notification through SNS.

### 2. AWS S3 (Simple Storage Service)
- **Function**: S3 is used to store the OAuth access token securely.
- **Bucket**: A dynamically named S3 bucket is created by Terraform, and the access token is stored as a text file (`access_token.txt`).

### 3. AWS SNS (Simple Notification Service)
- **Function**: SNS is used to send notifications about the success or failure of the Lambda function.
- **Topic**: Terraform creates an SNS topic `lambda-success-topic`, and a notification is sent to the email subscription when the function executes successfully.

### 4. AWS IAM (Identity and Access Management)
- **Function**: IAM roles and policies grant permissions to the Lambda function to access S3, Secrets Manager, and SNS.
- **Role**: The Lambda function is assigned an execution role that allows it to interact with the required services.

### 5. AWS Secrets Manager
- **Function**: Stores sensitive API credentials (API key and secret) securely.
- **Purpose**: The Lambda function retrieves the stored secrets to authenticate the request for the OAuth token.

### 6. AWS CloudWatch Events (EventBridge)
- **Function**: CloudWatch Events is used to trigger the Lambda function automatically at 15 minutes past every hour.
- **Event Rule**: The rule is defined using a cron schedule (`cron(15 * * * ? *)`) to run the Lambda function periodically.

### 7. Terraform
- **Function**: Terraform is used to define and provision the AWS infrastructure (Lambda, S3, SNS, IAM, Secrets Manager, and CloudWatch Event rules).
- **Benefits**: Infrastructure as code allows for easy deployment and management of cloud resources.

## Usage
- The Lambda function runs automatically every hour, fetching the OAuth token and storing it in the S3 bucket.
- Upon successful execution, an email notification is sent to the specified email via SNS.
- The token can be retrieved from the S3 bucket as needed.


## Future Plans
- ETL Pipeline: Integrate this OAuth token with a future ETL pipeline to fetch data from the API and store it in an S3 bucket or an RDS database.
- RDS Integration: Extend the project to transfer data collected via the API into an RDS database for further processing and analysis.

## Contact Me
- Visit my [LinkedIn](https://www.linkedin.com/in/obj809/) for more details.
- Check out my [GitHub](https://github.com/cyberforge1) for more projects.
- Or send me an email at obj809@gmail.com
<br />
Thanks for your interest in this project. Feel free to reach out with any thoughts or questions.
<br />
<br />
Oliver Jenkins © 2024
