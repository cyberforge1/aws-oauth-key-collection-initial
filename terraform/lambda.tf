# terraform/lambda.tf

variable "lambda_aws_region" {
  description = "AWS region for Lambda"
  default     = "ap-southeast-2"
}

variable "sns_email" {
  description = "Email for SNS notifications"
  type        = string
}

provider "aws" {
  alias  = "lambda"
  region = var.lambda_aws_region
}

# Generate unique IDs for resources
resource "random_id" "token_bucket_id" {
  byte_length = 4
}

# S3 Bucket for storing the access token
resource "aws_s3_bucket" "oauth_token_bucket" {
  provider = aws.lambda
  bucket   = "oauth-token-storage-${random_id.token_bucket_id.hex}"
}

# SNS Topic
resource "aws_sns_topic" "lambda_success_topic" {
  name = "lambda-success-topic"
}

# SNS Topic Subscription (Email)
resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.lambda_success_topic.arn
  protocol  = "email"
  endpoint  = var.sns_email
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_execution_role" {
  provider = aws.lambda
  name     = "lambda_execution_role"

  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Effect": "Allow",
        "Principal": {
          "Service": "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Role Policy for Lambda (S3, Secrets Manager, and SNS access)
resource "aws_iam_role_policy" "lambda_policy" {
  provider = aws.lambda
  name     = "lambda_execution_policy"
  role     = aws_iam_role.lambda_execution_role.id

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": [
          "s3:ListBucket"
        ],
        "Effect": "Allow",
        "Resource": "arn:aws:s3:::${aws_s3_bucket.oauth_token_bucket.bucket}"
      },
      {
        "Action": [
          "s3:PutObject",
          "s3:GetObject"
        ],
        "Effect": "Allow",
        "Resource": "arn:aws:s3:::${aws_s3_bucket.oauth_token_bucket.bucket}/*"
      },
      {
        "Action": [
          "secretsmanager:GetSecretValue"
        ],
        "Effect": "Allow",
        "Resource": data.aws_secretsmanager_secret.existing_oauth_secret.arn
      },
      {
        "Action": [
          "sns:Publish"
        ],
        "Effect": "Allow",
        "Resource": aws_sns_topic.lambda_success_topic.arn
      },
      {
        "Action": [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Effect": "Allow",
        "Resource": "arn:aws:logs:*:*:*"
      }
    ]
  })
}


# Reference the existing secret instead of creating a new one
data "aws_secretsmanager_secret" "existing_oauth_secret" {
  name = "oauth_secret"
}

# Create a new secret version for the existing secret
resource "aws_secretsmanager_secret_version" "oauth_secret_version" {
  provider      = aws.lambda
  secret_id     = data.aws_secretsmanager_secret.existing_oauth_secret.id
  secret_string = jsonencode({
    api_key    = var.api_key,
    api_secret = var.api_secret
  })
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda_function/lambda_package"
  output_path = "${path.module}/lambda_function_payload.zip"
}

# Lambda Function to collect OAuth2 token and upload it to S3
resource "aws_lambda_function" "oauth2_lambda" {
  provider         = aws.lambda
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "oauth2-token-lambda"
  role             = aws_iam_role.lambda_execution_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.9"
  memory_size      = 128
  timeout          = 30

  environment {
    variables = {
      S3_BUCKET_NAME = aws_s3_bucket.oauth_token_bucket.bucket
      SECRET_NAME    = data.aws_secretsmanager_secret.existing_oauth_secret.name
      REGION_NAME    = var.lambda_aws_region
      SNS_TOPIC_ARN  = aws_sns_topic.lambda_success_topic.arn
    }
  }

  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
}

# EventBridge Rule to schedule the Lambda function monthly
# resource "aws_cloudwatch_event_rule" "monthly_schedule" {
#   provider            = aws.lambda
#   name                = "invoke-oauth2-lambda-monthly"
#   description         = "Triggers the oauth2-token-lambda function monthly"
#   schedule_expression = "cron(0 0 1 * ? *)"
# }

# EventBridge Rule to schedule the Lambda function at 15 minutes past each hour
resource "aws_cloudwatch_event_rule" "monthly_schedule" {
  provider            = aws.lambda
  name                = "invoke-oauth2-lambda-hourly"
  description         = "Triggers the oauth2-token-lambda function at 15 minutes past each hour"
  schedule_expression = "cron(15 * * * ? *)"
}

# EventBridge Target to link the rule to the Lambda function
resource "aws_cloudwatch_event_target" "invoke_lambda" {
  provider  = aws.lambda
  rule      = aws_cloudwatch_event_rule.monthly_schedule.name
  target_id = "oauth2-lambda-target"
  arn       = aws_lambda_function.oauth2_lambda.arn
}

# Lambda permission to allow EventBridge to invoke the Lambda function
resource "aws_lambda_permission" "allow_eventbridge" {
  provider      = aws.lambda
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.oauth2_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.monthly_schedule.arn
}

# Input Variables
variable "api_key" {
  description = "The API key for the OAuth request"
  type        = string
}

variable "api_secret" {
  description = "The API secret for the OAuth request"
  type        = string
}
