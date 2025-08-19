output "cognito_user_pool_id" {
  description = "ID of the Cognito User Pool"
  value       = aws_cognito_user_pool.main.id
}

output "cognito_user_pool_arn" {
  description = "ARN of the Cognito User Pool"
  value       = aws_cognito_user_pool.main.arn
}

output "cognito_user_pool_client_id" {
  description = "ID of the Cognito User Pool Client"
  value       = aws_cognito_user_pool_client.main.id
}

output "cognito_user_pool_client_secret" {
  description = "Secret of the Cognito User Pool Client"
  value       = aws_cognito_user_pool_client.main.client_secret
  sensitive   = true
}

output "cognito_user_pool_domain" {
  description = "Domain of the Cognito User Pool"
  value       = aws_cognito_user_pool_domain.main.domain
}

# Lambda Function Outputs
output "post_confirmation_lambda_arn" {
  description = "ARN of the post confirmation Lambda function"
  value       = aws_lambda_function.post_confirmation.arn
}

output "pre_token_generation_lambda_arn" {
  description = "ARN of the pre token generation Lambda function"
  value       = aws_lambda_function.pre_token_generation.arn
}

# SES Outputs
output "ses_domain_identity_arn" {
  description = "ARN of the SES domain identity"
  value       = aws_ses_domain_identity.main.arn
}

output "ses_from_email" {
  description = "Verified from email address"
  value       = var.from_email
}

# IAM User Outputs
output "ci_cd_user_name" {
  description = "Name of the CI/CD IAM user"
  value       = aws_iam_user.ci_cd_user.name
}

output "app_deployer_user_name" {
  description = "Name of the app deployer IAM user"
  value       = aws_iam_user.app_deployer_user.name
}

output "monitoring_user_name" {
  description = "Name of the monitoring IAM user"
  value       = aws_iam_user.monitoring_user.name
}

output "backup_user_name" {
  description = "Name of the backup IAM user"
  value       = aws_iam_user.backup_user.name
}

# Secrets Manager Outputs
output "database_secret_arn" {
  description = "ARN of the database credentials secret"
  value       = aws_secretsmanager_secret.database_credentials.arn
}

output "cognito_secret_arn" {
  description = "ARN of the Cognito configuration secret"
  value       = aws_secretsmanager_secret.cognito_config.arn
}

output "api_keys_secret_arn" {
  description = "ARN of the API keys secret"
  value       = aws_secretsmanager_secret.api_keys.arn
}

# Service Role Outputs
output "lambda_execution_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_execution_role.arn
}

output "microservice_role_arn" {
  description = "ARN of the microservice role"
  value       = aws_iam_role.microservice_role.arn
}

output "ses_sending_role_arn" {
  description = "ARN of the SES sending role"
  value       = aws_iam_role.ses_sending_role.arn
}

# Database Outputs
output "database_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.main.endpoint
  sensitive   = true
}

output "database_port" {
  description = "RDS instance port"
  value       = aws_db_instance.main.port
}

# Operational User Credentials (for local secure storage)
output "operational_credentials" {
  description = "Operational user credentials for local secure storage"
  value = {
    app_deployer = {
      user_name         = aws_iam_user.app_deployer_user.name
      access_key_id     = aws_iam_access_key.app_deployer_user_key.id
      secret_access_key = aws_iam_access_key.app_deployer_user_key.secret
    }
    monitoring = {
      user_name         = aws_iam_user.monitoring_user.name
      access_key_id     = aws_iam_access_key.monitoring_user_key.id
      secret_access_key = aws_iam_access_key.monitoring_user_key.secret
    }
    backup = {
      user_name         = aws_iam_user.backup_user.name
      access_key_id     = aws_iam_access_key.backup_user_key.id
      secret_access_key = aws_iam_access_key.backup_user_key.secret
    }
  }
  sensitive = true
}