# Development Environment Configuration
environment = "dev"
aws_region  = "us-east-1"
owner_email = "admin@diagnyx.ai"

# VPC Configuration (disabled for local development)
# vpc_cidr = "10.0.0.0/16"

# Cognito Configuration
cognito_user_pool_name = "diagnyx-dev-user-pool"
cognito_client_name    = "diagnyx-dev-client"

password_policy = {
  minimum_length    = 12
  require_lowercase = true
  require_numbers   = true
  require_symbols   = true
  require_uppercase = true
}

# SES Configuration (using individual email verification)
ses_domain = "diagnyx.ai"
from_email = "noreply@diagnyx.ai"

# Database Configuration (local PostgreSQL)
database_name            = "diagnyx_users"
database_master_username = "postgres"

# API Gateway Configuration
api_gateway_endpoint = "http://localhost:8443"

# Environment-specific settings
enable_detailed_monitoring = false
enable_backup_encryption   = false
backup_retention_days      = 7