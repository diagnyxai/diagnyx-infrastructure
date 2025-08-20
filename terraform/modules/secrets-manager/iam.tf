# IAM policies for services to access their secrets

# Policy document for reading secrets
data "aws_iam_policy_document" "read_secrets" {
  statement {
    sid    = "AllowSecretsManagerRead"
    effect = "Allow"
    
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetResourcePolicy"
    ]
    
    resources = [
      for secret in aws_secretsmanager_secret.secrets : secret.arn
    ]
  }
  
  statement {
    sid    = "AllowKMSDecrypt"
    effect = "Allow"
    
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey"
    ]
    
    resources = ["*"]
    
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["secretsmanager.${data.aws_region.current.name}.amazonaws.com"]
    }
  }
}

# Data source for current AWS region
data "aws_region" "current" {}

# IAM policy for ECS task execution role
resource "aws_iam_policy" "ecs_secrets_policy" {
  name        = "${var.project_name}-${var.environment}-ecs-secrets-policy"
  description = "Policy for ECS tasks to read secrets from AWS Secrets Manager"
  policy      = data.aws_iam_policy_document.read_secrets.json
  
  tags = local.common_tags
}

# IAM policy for Lambda functions
resource "aws_iam_policy" "lambda_secrets_policy" {
  name        = "${var.project_name}-${var.environment}-lambda-secrets-policy"
  description = "Policy for Lambda functions to read secrets from AWS Secrets Manager"
  policy      = data.aws_iam_policy_document.read_secrets.json
  
  tags = local.common_tags
}

# IAM policy for EC2 instances (if using EC2 instead of ECS)
resource "aws_iam_policy" "ec2_secrets_policy" {
  name        = "${var.project_name}-${var.environment}-ec2-secrets-policy"
  description = "Policy for EC2 instances to read secrets from AWS Secrets Manager"
  policy      = data.aws_iam_policy_document.read_secrets.json
  
  tags = local.common_tags
}

# Service-specific IAM policies with restricted access
locals {
  services = [
    "user-service",
    "api-gateway"
  ]
}

# Create service-specific policies
resource "aws_iam_policy" "service_specific_policy" {
  for_each = toset(local.services)
  
  name        = "${var.project_name}-${var.environment}-${each.key}-secrets-policy"
  description = "Policy for ${each.key} to access its specific secrets"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowServiceSpecificSecrets"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          "arn:aws:secretsmanager:*:*:secret:${local.secret_prefix}/common/*",
          "arn:aws:secretsmanager:*:*:secret:${local.secret_prefix}/api-keys/*",
          "arn:aws:secretsmanager:*:*:secret:${local.secret_prefix}/services/${each.key}-api-key*"
        ]
      },
      {
        Sid    = "AllowKMSDecrypt"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = ["*"]
        Condition = {
          StringEquals = {
            "kms:ViaService" = "secretsmanager.${data.aws_region.current.name}.amazonaws.com"
          }
        }
      }
    ]
  })
  
  tags = merge(
    local.common_tags,
    {
      Service = each.key
    }
  )
}

# Example ECS task execution role (to be used by ECS services)
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.project_name}-${var.environment}-ecs-task-execution-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
  
  tags = local.common_tags
}

# Attach the AWS managed policy for ECS task execution
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Attach our custom secrets policy to the ECS task execution role
resource "aws_iam_role_policy_attachment" "ecs_task_execution_secrets_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.ecs_secrets_policy.arn
}