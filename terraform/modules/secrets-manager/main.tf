# AWS Secrets Manager Module for Diagnyx
# Pragmatic approach - only essential secrets, no over-engineering

locals {
  secret_prefix = "${var.project_name}/${var.environment}"
  
  # Common secrets used by multiple services
  common_secrets = {
    "jwt-secret" = {
      description = "JWT signing secret for authentication"
      rotation    = true
    }
    "jwt-refresh-secret" = {
      description = "JWT refresh token secret"
      rotation    = true
    }
    "postgres-password" = {
      description = "PostgreSQL database password"
      rotation    = true
    }
    "redis-password" = {
      description = "Redis cache password"
      rotation    = false
    }
    "clickhouse-password" = {
      description = "ClickHouse analytics database password"
      rotation    = false
    }
  }
  
  # External API keys
  api_keys = {
    "openai-api-key" = {
      description = "OpenAI API key for LLM services"
      rotation    = false
    }
    "anthropic-api-key" = {
      description = "Anthropic Claude API key"
      rotation    = false
    }
    "datadog-api-key" = {
      description = "DataDog monitoring API key"
      rotation    = false
    }
    "slack-webhook-url" = {
      description = "Slack webhook for notifications"
      rotation    = false
    }
  }
  
  # Service-to-service authentication keys
  service_keys = {
    "user-service-api-key" = {
      description = "API key for user service"
      rotation    = true
    }
    "observability-service-api-key" = {
      description = "API key for observability service"
      rotation    = true
    }
    "ai-quality-service-api-key" = {
      description = "API key for AI quality service"
      rotation    = true
    }
    "optimization-service-api-key" = {
      description = "API key for optimization service"
      rotation    = true
    }
  }
  
  # Combine all secrets
  all_secrets = merge(
    { for k, v in local.common_secrets : "common/${k}" => v },
    { for k, v in local.api_keys : "api-keys/${k}" => v },
    { for k, v in local.service_keys : "services/${k}" => v }
  )
  
  common_tags = merge(
    var.tags,
    {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
      Module      = "secrets-manager"
    }
  )
}

# Create secrets in AWS Secrets Manager
resource "aws_secretsmanager_secret" "secrets" {
  for_each = local.all_secrets
  
  name                    = "${local.secret_prefix}/${each.key}"
  description            = each.value.description
  recovery_window_in_days = var.recovery_window_in_days
  
  tags = merge(
    local.common_tags,
    {
      Name         = "${local.secret_prefix}/${each.key}"
      Type         = split("/", each.key)[0]
      RotationEnabled = tostring(each.value.rotation)
    }
  )
}

# Create placeholder secret versions (to be populated by script)
resource "aws_secretsmanager_secret_version" "secrets" {
  for_each = aws_secretsmanager_secret.secrets
  
  secret_id = each.value.id
  
  # Placeholder value - will be replaced by populate-secrets.sh script
  secret_string = jsonencode({
    value = "PLACEHOLDER_${upper(replace(each.key, "/", "_"))}_${upper(var.environment)}"
    note  = "This secret must be populated using the populate-secrets.sh script"
    created_at = timestamp()
  })
  
  lifecycle {
    # Ignore changes to the secret value after initial creation
    # This allows manual updates or script updates without Terraform conflicts
    ignore_changes = [secret_string]
  }
}

# Optional: Setup rotation for secrets that need it
resource "aws_secretsmanager_secret_rotation" "rotation" {
  for_each = var.enable_rotation ? {
    for k, v in local.all_secrets : k => v if v.rotation
  } : {}
  
  secret_id           = aws_secretsmanager_secret.secrets[each.key].id
  rotation_lambda_arn = aws_lambda_function.rotation[0].arn
  
  rotation_rules {
    automatically_after_days = var.rotation_days
  }
  
  depends_on = [aws_lambda_permission.rotation[0]]
}

# Lambda function for secret rotation (only created if rotation is enabled)
resource "aws_lambda_function" "rotation" {
  count = var.enable_rotation ? 1 : 0
  
  filename         = "${path.module}/lambda/rotation.zip"
  function_name    = "${var.project_name}-${var.environment}-secret-rotation"
  role            = aws_iam_role.rotation[0].arn
  handler         = "index.handler"
  runtime         = "python3.11"
  timeout         = 30
  
  environment {
    variables = {
      ENVIRONMENT = var.environment
    }
  }
  
  tags = local.common_tags
}

# IAM role for rotation Lambda (only created if rotation is enabled)
resource "aws_iam_role" "rotation" {
  count = var.enable_rotation ? 1 : 0
  
  name = "${var.project_name}-${var.environment}-secret-rotation-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
  
  tags = local.common_tags
}

# Lambda permission for Secrets Manager to invoke rotation function
resource "aws_lambda_permission" "rotation" {
  count = var.enable_rotation ? 1 : 0
  
  statement_id  = "AllowSecretsManagerInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rotation[0].function_name
  principal     = "secretsmanager.amazonaws.com"
}