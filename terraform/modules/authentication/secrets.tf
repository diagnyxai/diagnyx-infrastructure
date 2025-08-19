# Secrets Manager Configuration for Authentication Module

# Generate random internal API key for Lambda functions
resource "random_password" "internal_api_key" {
  length  = 64
  special = true
}

# Generate random JWT secret for token signing
resource "random_password" "jwt_secret" {
  length  = 64
  special = true
}

# API Keys Secret
resource "aws_secretsmanager_secret" "api_keys" {
  name        = "${local.name_prefix}/api-keys"
  description = "Internal API keys and JWT secrets"

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-api-keys"
    Type = "Credentials"
  })
}

resource "aws_secretsmanager_secret_version" "api_keys" {
  secret_id = aws_secretsmanager_secret.api_keys.id
  secret_string = jsonencode({
    internal_api_key = random_password.internal_api_key.result
    jwt_secret       = random_password.jwt_secret.result
    jwt_issuer       = "https://cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.main.id}"
    jwt_audience     = aws_cognito_user_pool_client.main.id
  })
}

# Cognito Configuration Secret
resource "aws_secretsmanager_secret" "cognito_config" {
  name        = "${local.name_prefix}/cognito/config"
  description = "Cognito User Pool configuration"

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-cognito-config"
    Type = "Configuration"
  })
}

resource "aws_secretsmanager_secret_version" "cognito_config" {
  secret_id = aws_secretsmanager_secret.cognito_config.id
  secret_string = jsonencode({
    user_pool_id                = aws_cognito_user_pool.main.id
    user_pool_client_id         = aws_cognito_user_pool_client.main.id
    user_pool_client_secret     = aws_cognito_user_pool_client.main.client_secret
    user_pool_domain           = aws_cognito_user_pool_domain.main.domain
    user_pool_endpoint         = "https://cognito-idp.${var.aws_region}.amazonaws.com"
    jwks_uri                   = "https://cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.main.id}/.well-known/jwks.json"
    region                     = var.aws_region
  })
}

# SES Configuration Secret
resource "aws_secretsmanager_secret" "ses_config" {
  name        = "${local.name_prefix}/ses/config"
  description = "SES email service configuration"

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-ses-config"
    Type = "Configuration"
  })
}

resource "aws_secretsmanager_secret_version" "ses_config" {
  secret_id = aws_secretsmanager_secret.ses_config.id
  secret_string = jsonencode({
    domain                = var.ses_domain
    from_email           = var.from_email
    configuration_set    = aws_ses_configuration_set.main.name
    region               = var.aws_region
    welcome_template     = aws_ses_template.welcome_email.name
    verification_template = aws_ses_template.verification_email.name
    password_reset_template = aws_ses_template.password_reset.name
  })
}

# Application Configuration Secret (for user-service and api-gateway)
resource "aws_secretsmanager_secret" "app_config" {
  name        = "${local.name_prefix}/application/config"
  description = "Application configuration for microservices"

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-app-config"
    Type = "Configuration"
  })
}

resource "aws_secretsmanager_secret_version" "app_config" {
  secret_id = aws_secretsmanager_secret.app_config.id
  secret_string = jsonencode({
    environment      = var.environment
    region          = var.aws_region
    api_gateway_url = var.api_gateway_endpoint
    frontend_urls = [
      var.environment == "production" ? "https://app.diagnyx.ai" : "http://localhost:3002",
      var.environment == "production" ? "https://diagnyx.ai" : "http://localhost:3001"
    ]
    cors_origins = [
      var.environment == "production" ? "https://app.diagnyx.ai" : "http://localhost:3002",
      var.environment == "production" ? "https://diagnyx.ai" : "http://localhost:3001"
    ]
    session_timeout_hours = 24
    refresh_token_days    = 7
    password_policy = {
      min_length        = var.password_policy.minimum_length
      require_lowercase = var.password_policy.require_lowercase
      require_uppercase = var.password_policy.require_uppercase
      require_numbers   = var.password_policy.require_numbers
      require_symbols   = var.password_policy.require_symbols
    }
  })
}

# Lambda Environment Variables Secret
resource "aws_secretsmanager_secret" "lambda_env" {
  name        = "${local.name_prefix}/lambda/environment"
  description = "Environment variables for Lambda functions"

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-lambda-env"
    Type = "Configuration"
  })
}

resource "aws_secretsmanager_secret_version" "lambda_env" {
  secret_id = aws_secretsmanager_secret.lambda_env.id
  secret_string = jsonencode({
    API_ENDPOINT     = var.api_gateway_endpoint
    INTERNAL_API_KEY = random_password.internal_api_key.result
    ENVIRONMENT      = var.environment
    AWS_REGION       = var.aws_region
    LOG_LEVEL        = var.environment == "production" ? "INFO" : "DEBUG"
  })
}

# Monitoring and Alerting Configuration
resource "aws_secretsmanager_secret" "monitoring_config" {
  name        = "${local.name_prefix}/monitoring/config"
  description = "Monitoring and alerting configuration"

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-monitoring-config"
    Type = "Configuration"
  })
}

resource "aws_secretsmanager_secret_version" "monitoring_config" {
  secret_id = aws_secretsmanager_secret.monitoring_config.id
  secret_string = jsonencode({
    cloudwatch_log_groups = [
      "/aws/lambda/${local.name_prefix}-post-confirmation",
      "/aws/lambda/${local.name_prefix}-pre-token-generation",
      "/aws/rds/instance/${local.name_prefix}-postgres/postgresql",
      "/aws/ses/${local.name_prefix}"
    ]
    alert_email = var.owner_email
    slack_webhook_url = ""  # To be filled later if Slack integration is needed
    enable_detailed_monitoring = var.environment == "production"
  })
}

# Backup Configuration Secret
resource "aws_secretsmanager_secret" "backup_config" {
  name        = "${local.name_prefix}/backup/config"
  description = "Backup and disaster recovery configuration"

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-backup-config"
    Type = "Configuration"
  })
}

resource "aws_secretsmanager_secret_version" "backup_config" {
  secret_id = aws_secretsmanager_secret.backup_config.id
  secret_string = jsonencode({
    rds_backup_retention_days = var.environment == "production" ? 30 : 7
    automated_backups_enabled = true
    backup_window            = "03:00-04:00"
    maintenance_window       = "sun:04:00-sun:05:00"
    snapshot_identifier_prefix = "${local.name_prefix}-snapshot"
    backup_bucket           = "diagnyx-backups-${var.environment}"
  })
}