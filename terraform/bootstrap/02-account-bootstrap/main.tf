# Account Bootstrap Module
# This module is run in EACH account after creation to set up base resources
# No recurring costs - only one-time setup or free resources

terraform {
  required_version = ">= 1.5.0"
  
  backend "s3" {
    # Backend configuration provided by backend-config.hcl
  }
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
  
  common_tags = {
    Environment = var.environment
    AccountId   = local.account_id
    Project     = "diagnyx"
    ManagedBy   = "terraform"
    Purpose     = "account-bootstrap"
  }
}

# S3 Bucket for Terraform State (one-time, minimal cost)
resource "aws_s3_bucket" "terraform_state" {
  bucket = "diagnyx-terraform-state-${var.environment}-${local.account_id}"
  
  tags = merge(
    local.common_tags,
    {
      Name = "terraform-state"
      Purpose = "terraform-backend"
    }
  )
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB Table for Terraform State Locking (minimal cost - pay per request)
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "diagnyx-terraform-locks-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"  # No recurring costs, only pay for actual use
  hash_key     = "LockID"
  
  attribute {
    name = "LockID"
    type = "S"
  }
  
  tags = merge(
    local.common_tags,
    {
      Name = "terraform-locks"
      Purpose = "state-locking"
    }
  )
}

# CloudTrail for Audit (first trail is free)
resource "aws_cloudtrail" "audit" {
  name                          = "diagnyx-audit-trail-${var.environment}"
  s3_bucket_name               = aws_s3_bucket.audit_logs.id
  include_global_service_events = true
  is_multi_region_trail        = true
  enable_logging               = true
  
  event_selector {
    read_write_type           = "All"
    include_management_events = true
    
    # Track S3 bucket-level events
    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::diagnyx-*/*"]
    }
  }
  
  tags = merge(
    local.common_tags,
    {
      Name = "audit-trail"
      Compliance = "required"
    }
  )
}

# S3 Bucket for CloudTrail Logs
resource "aws_s3_bucket" "audit_logs" {
  bucket = "diagnyx-audit-logs-${var.environment}-${local.account_id}"
  
  tags = merge(
    local.common_tags,
    {
      Name = "audit-logs"
      Compliance = "required"
    }
  )
}

resource "aws_s3_bucket_lifecycle_configuration" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id
  
  rule {
    id     = "archive-old-logs"
    status = "Enabled"
    
    filter {}  # Apply to all objects
    
    transition {
      days          = 30
      storage_class = "GLACIER_IR"
    }
    
    expiration {
      days = var.environment == "production" ? 2555 : 90  # 7 years for prod, 90 days for non-prod
    }
  }
}

resource "aws_s3_bucket_policy" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.audit_logs.arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.audit_logs.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

# IAM Password Policy (free)
resource "aws_iam_account_password_policy" "strict" {
  minimum_password_length        = 14
  require_lowercase_characters   = true
  require_numbers               = true
  require_uppercase_characters   = true
  require_symbols               = true
  allow_users_to_change_password = true
  max_password_age              = 90
  password_reuse_prevention     = 24
}

# SNS Topic for Alarms (free tier: 1,000 notifications)
resource "aws_sns_topic" "alarms" {
  name = "diagnyx-${var.environment}-alarms"
  
  tags = merge(
    local.common_tags,
    {
      Name = "alarm-notifications"
    }
  )
}

resource "aws_sns_topic_subscription" "alarm_email" {
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# CloudWatch Log Groups (minimal cost with short retention)
resource "aws_cloudwatch_log_group" "application" {
  name              = "/aws/diagnyx/${var.environment}"
  retention_in_days = var.environment == "production" ? 30 : 7
  
  tags = merge(
    local.common_tags,
    {
      Name = "application-logs"
    }
  )
}

# Budget Alert (free - up to 2 budgets)
resource "aws_budgets_budget" "account_budget" {
  name              = "diagnyx-${var.environment}-budget"
  budget_type       = "COST"
  limit_amount      = var.monthly_budget_limit
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_email_addresses = [var.budget_alert_email]
  }
  
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_email_addresses = [var.budget_alert_email]
    subscriber_sns_topic_arns  = [aws_sns_topic.alarms.arn]
  }
}

# KMS Key for Encryption (free for AWS managed keys)
resource "aws_kms_key" "main" {
  description             = "KMS key for ${var.environment} environment"
  deletion_window_in_days = var.environment == "production" ? 30 : 7
  enable_key_rotation     = true
  
  tags = merge(
    local.common_tags,
    {
      Name = "main-encryption-key"
    }
  )
}

resource "aws_kms_alias" "main" {
  name          = "alias/diagnyx-${var.environment}"
  target_key_id = aws_kms_key.main.key_id
}

# Systems Manager Parameter Store (free tier: 10,000 parameters)
resource "aws_ssm_parameter" "config" {
  for_each = var.initial_parameters
  
  name  = "/diagnyx/${var.environment}/${each.key}"
  type  = "SecureString"
  value = each.value
  
  tags = merge(
    local.common_tags,
    {
      Name = each.key
    }
  )
}

# EventBridge Rule for Cost Optimization (free)
resource "aws_cloudwatch_event_rule" "daily_cost_check" {
  name                = "diagnyx-${var.environment}-daily-cost-check"
  description         = "Trigger daily cost optimization check"
  schedule_expression = "cron(0 8 * * ? *)"
  
  tags = local.common_tags
}

# ECR Repository for Shared Container Images (pay only for storage)
resource "aws_ecr_repository" "app_images" {
  for_each = toset(var.ecr_repositories)
  
  name                 = "diagnyx/${var.environment}/${each.value}"
  image_tag_mutability = "MUTABLE"
  
  image_scanning_configuration {
    scan_on_push = var.environment == "production" ? true : false
  }
  
  
  tags = merge(
    local.common_tags,
    {
      Name = each.value
      Service = each.value
    }
  )
}

# Outputs
output "terraform_state_bucket" {
  value       = aws_s3_bucket.terraform_state.id
  description = "S3 bucket for Terraform state"
}

output "terraform_locks_table" {
  value       = aws_dynamodb_table.terraform_locks.id
  description = "DynamoDB table for Terraform state locking"
}

output "kms_key_id" {
  value       = aws_kms_key.main.id
  description = "KMS key ID for encryption"
}

output "sns_topic_arn" {
  value       = aws_sns_topic.alarms.arn
  description = "SNS topic ARN for alarms"
}

output "ecr_repositories" {
  value = {
    for k, v in aws_ecr_repository.app_images : k => v.repository_url
  }
  description = "ECR repository URLs"
}