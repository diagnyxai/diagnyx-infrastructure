# Secrets Manager Structure - Pre-created for applications
# Cost: $0.40 per secret per month ($6.00 total for 15 secrets)
# Purpose: Create secret structure, values added during deployment

locals {
  # Core application secrets needed across services
  application_secrets = [
    "database-password",
    "jwt-secret",
    "jwt-refresh-secret"
  ]
  
  # API keys for external services
  api_secrets = [
    "openai-api-key",
    "anthropic-api-key",
    "datadog-api-key",
    "slack-webhook",
    "github-token"
  ]
  
  # Service-specific secrets
  service_secrets = [
    "user-service-key",
    "admin-api-key"
  ]
}

# Create application secrets structure
resource "aws_secretsmanager_secret" "application_secrets" {
  for_each = toset(local.application_secrets)
  
  name                    = "diagnyx/${var.environment}/${each.key}"
  description            = "Secret for ${each.key} in ${var.environment} environment"
  recovery_window_in_days = var.environment == "production" ? 30 : 7
  
  tags = merge(
    local.common_tags,
    {
      Type = "application"
      Name = each.key
    }
  )
}

# Create API key secrets structure
resource "aws_secretsmanager_secret" "api_secrets" {
  for_each = toset(local.api_secrets)
  
  name                    = "diagnyx/${var.environment}/api/${each.key}"
  description            = "API key for ${each.key} in ${var.environment} environment"
  recovery_window_in_days = var.environment == "production" ? 30 : 7
  
  tags = merge(
    local.common_tags,
    {
      Type = "api-key"
      Name = each.key
    }
  )
}

# Create service-specific secrets structure
resource "aws_secretsmanager_secret" "service_secrets" {
  for_each = toset(local.service_secrets)
  
  name                    = "diagnyx/${var.environment}/services/${each.key}"
  description            = "Service key for ${each.key} in ${var.environment} environment"
  recovery_window_in_days = var.environment == "production" ? 30 : 7
  
  tags = merge(
    local.common_tags,
    {
      Type = "service-key"
      Name = each.key
    }
  )
}

# Placeholder secret versions (empty, to be populated during deployment)
resource "aws_secretsmanager_secret_version" "application_secrets" {
  for_each = aws_secretsmanager_secret.application_secrets
  
  secret_id     = each.value.id
  secret_string = jsonencode({
    value       = "PLACEHOLDER_${upper(each.key)}_${upper(var.environment)}"
    description = "This secret will be populated during application deployment"
    created_at  = timestamp()
  })
  
  lifecycle {
    ignore_changes = [secret_string]
  }
}

resource "aws_secretsmanager_secret_version" "api_secrets" {
  for_each = aws_secretsmanager_secret.api_secrets
  
  secret_id     = each.value.id
  secret_string = jsonencode({
    value       = "PLACEHOLDER_${upper(each.key)}_${upper(var.environment)}"
    description = "This API key will be configured during deployment"
    created_at  = timestamp()
  })
  
  lifecycle {
    ignore_changes = [secret_string]
  }
}

resource "aws_secretsmanager_secret_version" "service_secrets" {
  for_each = aws_secretsmanager_secret.service_secrets
  
  secret_id     = each.value.id
  secret_string = jsonencode({
    value       = "PLACEHOLDER_${upper(each.key)}_${upper(var.environment)}"
    description = "This service key will be generated during deployment"
    created_at  = timestamp()
  })
  
  lifecycle {
    ignore_changes = [secret_string]
  }
}

# Outputs for reference
output "secret_arns" {
  value = merge(
    { for k, v in aws_secretsmanager_secret.application_secrets : k => v.arn },
    { for k, v in aws_secretsmanager_secret.api_secrets : k => v.arn },
    { for k, v in aws_secretsmanager_secret.service_secrets : k => v.arn }
  )
  description = "ARNs of all created secrets"
  sensitive   = true
}