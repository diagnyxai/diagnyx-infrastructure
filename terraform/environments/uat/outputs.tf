# UAT Environment Outputs

# VPC Outputs
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnets
}

# Load Balancer Outputs
output "alb_dns_name" {
  description = "Application Load Balancer DNS name"
  value       = module.app_services.alb_dns_name
}

output "alb_zone_id" {
  description = "Application Load Balancer zone ID"
  value       = module.app_services.alb_zone_id
}

# ECR Outputs
output "ecr_repositories" {
  description = "ECR repository URLs"
  value       = module.shared_resources.ecr_repositories
  sensitive   = true
}

# Database Outputs
output "database_endpoint" {
  description = "Database endpoint"
  value       = module.authentication.database_endpoint
  sensitive   = true
}

# Security Group Outputs
output "ecs_security_group_id" {
  description = "ECS security group ID"
  value       = module.app_services.ecs_security_group_id
}

output "database_secret_arn" {
  description = "Database password secret ARN"
  value       = module.authentication.database_secret_arn
  sensitive   = true
}

# Environment Info
output "environment" {
  description = "Environment name"
  value       = var.environment
}

output "region" {
  description = "AWS region"
  value       = var.aws_region
}