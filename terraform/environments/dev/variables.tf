# Core Environment Variables
variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
  
  validation {
    condition     = var.environment == "dev"
    error_message = "This configuration is specifically for dev environment."
  }
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "owner_email" {
  description = "Email of the infrastructure owner"
  type        = string
  default     = "dev-team@diagnyx.ai"
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

# Authentication Module Variables
variable "cognito_user_pool_name" {
  description = "Name for the Cognito User Pool"
  type        = string
  default     = "diagnyx-dev-user-pool"
}

variable "cognito_client_name" {
  description = "Name for the Cognito User Pool Client"
  type        = string
  default     = "diagnyx-dev-client"
}

variable "password_policy" {
  description = "Password policy configuration for development"
  type = object({
    minimum_length    = number
    require_lowercase = bool
    require_numbers   = bool
    require_symbols   = bool
    require_uppercase = bool
  })
  default = {
    minimum_length    = 6  # Relaxed for development
    require_lowercase = true
    require_numbers   = true
    require_symbols   = false  # Relaxed for development
    require_uppercase = true
  }
}

variable "ses_domain" {
  description = "Domain for SES email sending"
  type        = string
  default     = "dev.diagnyx.ai"
}

variable "from_email" {
  description = "From email address for notifications"
  type        = string
  default     = "noreply@dev.diagnyx.ai"
}

variable "database_name" {
  description = "Name of the user service database"
  type        = string
  default     = "diagnyx_users_dev"
}

variable "database_master_username" {
  description = "Master username for RDS instance"
  type        = string
  default     = "postgres"
}

variable "api_gateway_endpoint" {
  description = "API Gateway endpoint for Lambda callbacks"
  type        = string
  default     = "https://api-dev.diagnyx.ai"
}

# Development-specific overrides
variable "enable_monitoring" {
  description = "Enable detailed monitoring"
  type        = bool
  default     = false  # Reduced monitoring for dev
}

variable "backup_retention_days" {
  description = "Database backup retention period"
  type        = number
  default     = 1  # Minimal backups for dev
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = false  # Allow easy cleanup in dev
}