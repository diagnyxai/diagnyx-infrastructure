variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "diagnyx"
}

variable "owner_email" {
  description = "Email of the project owner"
  type        = string
}

# Cognito Configuration
variable "cognito_user_pool_name" {
  description = "Name for the Cognito User Pool"
  type        = string
  default     = null
}

variable "cognito_client_name" {
  description = "Name for the Cognito User Pool Client"
  type        = string
  default     = null
}

variable "password_policy" {
  description = "Password policy configuration"
  type = object({
    minimum_length    = number
    require_lowercase = bool
    require_numbers   = bool
    require_symbols   = bool
    require_uppercase = bool
  })
  default = {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }
}

# SES Configuration
variable "ses_domain" {
  description = "Domain for SES email sending"
  type        = string
  default     = "diagnyx.ai"
}

variable "from_email" {
  description = "From email address for notifications"
  type        = string
  default     = "noreply@diagnyx.ai"
}

# Database Configuration
variable "database_name" {
  description = "Name of the user service database"
  type        = string
  default     = "diagnyx_users"
}

variable "database_master_username" {
  description = "Master username for RDS instance"
  type        = string
  default     = "postgres"
}

# Lambda Configuration
variable "lambda_runtime" {
  description = "Runtime for Lambda functions"
  type        = string
  default     = "nodejs18.x"
}

variable "lambda_timeout" {
  description = "Timeout for Lambda functions in seconds"
  type        = number
  default     = 30
}

variable "lambda_memory_size" {
  description = "Memory size for Lambda functions in MB"
  type        = number
  default     = 128
}

# API Gateway Configuration
variable "api_gateway_endpoint" {
  description = "API Gateway endpoint for Lambda callbacks"
  type        = string
  default     = "https://api.diagnyx.ai"
}

# Security Configuration
variable "ecs_services_security_group_id" {
  description = "Security group ID for ECS services (optional)"
  type        = string
  default     = ""
}

# Tags
variable "common_tags" {
  description = "Common tags to be applied to all resources"
  type        = map(string)
  default     = {}
}