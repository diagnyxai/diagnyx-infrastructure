# Staging Environment Outputs

# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "IDs of the private subnets"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnets
}

# Authentication Outputs
output "cognito_user_pool_id" {
  description = "ID of the Cognito User Pool"
  value       = module.authentication.cognito_user_pool_id
}

output "cognito_user_pool_client_id" {
  description = "ID of the Cognito User Pool Client"
  value       = module.authentication.cognito_user_pool_client_id
}

output "cognito_user_pool_domain" {
  description = "Domain of the Cognito User Pool"
  value       = module.authentication.cognito_user_pool_domain
}

output "database_endpoint" {
  description = "RDS instance endpoint"
  value       = module.authentication.database_endpoint
  sensitive   = true
}

# IAM User Names (for GitHub Secrets setup)
output "ci_cd_user_name" {
  description = "Name of the CI/CD IAM user for GitHub Actions"
  value       = module.authentication.ci_cd_user_name
}

# Secret ARNs for application configuration
output "cognito_config_secret_arn" {
  description = "ARN of the Cognito configuration secret"
  value       = module.authentication.cognito_secret_arn
}

output "database_secret_arn" {
  description = "ARN of the database credentials secret"
  value       = module.authentication.database_secret_arn
}

output "api_keys_secret_arn" {
  description = "ARN of the API keys secret"
  value       = module.authentication.api_keys_secret_arn
}

# ECS Cluster
output "ecs_cluster_id" {
  description = "ID of the ECS cluster"
  value       = module.ecs_cluster.cluster_id
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs_cluster.cluster_name
}

# Environment Info
output "environment" {
  description = "Environment name"
  value       = var.environment
}

output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}