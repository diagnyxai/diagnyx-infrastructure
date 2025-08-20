# Variables for Account Bootstrap Module

variable "environment" {
  description = "Environment name (development, staging, uat, production, shared, security)"
  type        = string
  
  validation {
    condition     = contains(["development", "staging", "uat", "production", "shared", "security"], var.environment)
    error_message = "Environment must be one of: development, staging, uat, production, shared, security."
  }
}

variable "monthly_budget_limit" {
  description = "Monthly budget limit for this account in USD"
  type        = number
  default     = 500  # Conservative default
}

variable "alarm_email" {
  description = "Email address for CloudWatch alarms"
  type        = string
}

variable "budget_alert_email" {
  description = "Email address for budget alerts"
  type        = string
}

variable "ecr_repositories" {
  description = "List of ECR repositories to create"
  type        = list(string)
  default = [
    "user-service",
    "api-gateway",
    "diagnyx-ui"
  ]
}

variable "initial_parameters" {
  description = "Initial SSM parameters to create"
  type        = map(string)
  default     = {}
}

# Environment-specific budget limits (no recurring cost)
variable "environment_budgets" {
  description = "Budget limits per environment"
  type        = map(number)
  default = {
    development = 200   # $200/month for dev
    staging     = 400   # $400/month for staging
    uat         = 300   # $300/month for UAT
    production  = 2000  # $2000/month for production
    shared      = 100   # $100/month for shared services
    security    = 50    # $50/month for security account
  }
}