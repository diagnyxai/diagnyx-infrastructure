# Data source for Lambda function packages
data "archive_file" "post_confirmation_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../../lambda/cognito-triggers/post-confirmation"
  output_path = "${path.module}/../../lambda/cognito-triggers/post-confirmation.zip"
}

data "archive_file" "pre_token_generation_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../../lambda/cognito-triggers/pre-token-generation"
  output_path = "${path.module}/../../lambda/cognito-triggers/pre-token-generation.zip"
}

# IAM Role for Lambda Execution
resource "aws_iam_role" "lambda_execution_role" {
  name = "${local.name_prefix}-lambda-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-lambda-execution-role"
    Type = "IAM"
  })
}

# IAM Policy for Lambda Execution
resource "aws_iam_role_policy" "lambda_execution_policy" {
  name = "${local.name_prefix}-lambda-execution-policy"
  role = aws_iam_role.lambda_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          aws_secretsmanager_secret.api_keys.arn
        ]
      }
    ]
  })
}

# Attach AWS managed policy for basic Lambda execution
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Post Confirmation Lambda Function
resource "aws_lambda_function" "post_confirmation" {
  filename         = data.archive_file.post_confirmation_zip.output_path
  function_name    = "${local.name_prefix}-post-confirmation"
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = "index.handler"
  source_code_hash = data.archive_file.post_confirmation_zip.output_base64sha256
  runtime         = var.lambda_runtime
  timeout         = var.lambda_timeout
  memory_size     = var.lambda_memory_size

  environment {
    variables = {
      API_ENDPOINT     = var.api_gateway_endpoint
      INTERNAL_API_KEY = "{{resolve:secretsmanager:${aws_secretsmanager_secret.api_keys.name}:SecretString:internal_api_key}}"
      ENVIRONMENT      = var.environment
    }
  }

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-post-confirmation"
    Type = "Lambda"
  })

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic_execution,
    aws_cloudwatch_log_group.post_confirmation_logs
  ]
}

# Pre Token Generation Lambda Function
resource "aws_lambda_function" "pre_token_generation" {
  filename         = data.archive_file.pre_token_generation_zip.output_path
  function_name    = "${local.name_prefix}-pre-token-generation"
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = "index.handler"
  source_code_hash = data.archive_file.pre_token_generation_zip.output_base64sha256
  runtime         = var.lambda_runtime
  timeout         = var.lambda_timeout
  memory_size     = var.lambda_memory_size

  environment {
    variables = {
      API_ENDPOINT     = var.api_gateway_endpoint
      INTERNAL_API_KEY = "{{resolve:secretsmanager:${aws_secretsmanager_secret.api_keys.name}:SecretString:internal_api_key}}"
      ENVIRONMENT      = var.environment
    }
  }

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-pre-token-generation"
    Type = "Lambda"
  })

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic_execution,
    aws_cloudwatch_log_group.pre_token_generation_logs
  ]
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "post_confirmation_logs" {
  name              = "/aws/lambda/${local.name_prefix}-post-confirmation"
  retention_in_days = 14

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-post-confirmation-logs"
    Type = "Logs"
  })
}

resource "aws_cloudwatch_log_group" "pre_token_generation_logs" {
  name              = "/aws/lambda/${local.name_prefix}-pre-token-generation"
  retention_in_days = 14

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-pre-token-generation-logs"
    Type = "Logs"
  })
}