# Certificate Management Module Variables

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
  
  validation {
    condition     = contains(["dev", "staging", "production", "uat"], var.environment)
    error_message = "Environment must be one of: dev, staging, production, uat."
  }
}

variable "domain_name" {
  description = "Primary domain name for the SSL certificate"
  type        = string
  default     = ""
  
  validation {
    condition = var.domain_name == "" || can(regex("^[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]*\\.[a-zA-Z]{2,}$", var.domain_name))
    error_message = "Domain name must be a valid domain format (e.g., example.com)."
  }
}

variable "subject_alternative_names" {
  description = "List of additional domain names to include in the certificate"
  type        = list(string)
  default     = []
  
  validation {
    condition = alltrue([
      for name in var.subject_alternative_names : 
      can(regex("^(\\*\\.)?[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]*\\.[a-zA-Z]{2,}$", name))
    ])
    error_message = "All subject alternative names must be valid domain formats."
  }
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "enable_monitoring" {
  description = "Enable certificate expiry monitoring"
  type        = bool
  default     = true
}

variable "notification_topic_arn" {
  description = "SNS topic ARN for certificate expiry notifications"
  type        = string
  default     = ""
}

variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 30
  
  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "Log retention days must be a valid CloudWatch log retention value."
  }
}

variable "certificate_transparency_logging" {
  description = "Enable certificate transparency logging"
  type        = bool
  default     = true
}

variable "early_renewal_days" {
  description = "Number of days before expiry to trigger renewal warnings"
  type        = number
  default     = 30
  
  validation {
    condition     = var.early_renewal_days >= 1 && var.early_renewal_days <= 365
    error_message = "Early renewal days must be between 1 and 365."
  }
}