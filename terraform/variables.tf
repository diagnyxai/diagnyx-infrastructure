variable "aws_region" {
  description = "AWS region for resources (must be us-east-1)"
  type        = string
  default     = "us-east-1"
  
  validation {
    condition     = var.aws_region == "us-east-1"
    error_message = "AWS region must be us-east-1 for all Diagnyx infrastructure."
  }
}

variable "environment" {
  description = "Environment name (dev, uat, staging, production)"
  type        = string
  validation {
    condition     = contains(["dev", "uat", "staging", "production"], var.environment)
    error_message = "Environment must be dev, uat, staging, or production."
  }
}

variable "owner_email" {
  description = "Email of the infrastructure owner"
  type        = string
  default     = "infrastructure@diagnyx.ai"
}

# SSL Certificate Configuration
variable "domain_name" {
  description = "Primary domain name for SSL certificates"
  type        = string
  default     = ""
  
  validation {
    condition = var.domain_name == "" || can(regex("^[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]*\\.[a-zA-Z]{2,}$", var.domain_name))
    error_message = "Domain name must be a valid domain format (e.g., diagnyx.ai) or empty string for local development."
  }
}

variable "notification_topic_arn" {
  description = "SNS topic ARN for certificate expiry notifications"
  type        = string
  default     = ""
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway for all private subnets"
  type        = bool
  default     = false
}

variable "key_name" {
  description = "AWS Key Pair name for EC2 instances (optional)"
  type        = string
  default     = ""
}

# EKS Configuration
variable "eks_cluster_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.28"
}

variable "eks_node_group_desired_size" {
  description = "Desired number of nodes in EKS node group"
  type        = number
  default     = 2  # Reduced from 3 for cost optimization
}

variable "eks_node_group_min_size" {
  description = "Minimum number of nodes in EKS node group"
  type        = number
  default     = 1  # Reduced from 2 for cost optimization
}

variable "eks_node_group_max_size" {
  description = "Maximum number of nodes in EKS node group"
  type        = number
  default     = 10
}

variable "eks_node_instance_types" {
  description = "Instance types for EKS nodes"
  type        = list(string)
  default     = ["t4g.medium", "t4g.large"]  # Switched to ARM-based Graviton for 20% savings
}

variable "eks_spot_instance_types" {
  description = "Instance types for spot instances"
  type        = list(string)
  default     = ["t4g.medium", "t4g.large", "t3a.medium", "t3a.large"]
}

# RDS Configuration
variable "rds_engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "15.4"
}

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.medium"  # Changed from db.r5.large for 60% cost savings
}

variable "rds_instance_class_production" {
  description = "RDS instance class for production"
  type        = string
  default     = "db.t4g.large"  # Graviton-based for better price/performance
}

variable "rds_allocated_storage" {
  description = "Allocated storage for RDS in GB"
  type        = number
  default     = 50  # Reduced from 100, autoscaling will handle growth
}

variable "rds_max_allocated_storage" {
  description = "Maximum allocated storage for RDS in GB"
  type        = number
  default     = 500  # Reduced from 1000
}

variable "rds_backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 7  # Reduced from 30 for non-production
}

variable "rds_backup_retention_period_production" {
  description = "Backup retention period in days for production"
  type        = number
  default     = 30
}

variable "rds_multi_az" {
  description = "Enable Multi-AZ for RDS"
  type        = bool
  default     = false  # Disabled for non-production
}

# Note: ElastiCache/Redis removed from simplified platform
# All caching now handled in-memory by applications

# Database Configuration
variable "database_name" {
  description = "Name of the database"
  type        = string
  default     = "diagnyx"
}

variable "database_master_username" {
  description = "Master username for the database"
  type        = string
  default     = "diagnyx"
}

# S3 Configuration
variable "enable_s3_versioning" {
  description = "Enable versioning for S3 buckets"
  type        = bool
  default     = true
}

variable "s3_lifecycle_days" {
  description = "Number of days before transitioning objects to cheaper storage"
  type        = number
  default     = 90
}

# Monitoring
variable "enable_monitoring" {
  description = "Enable CloudWatch monitoring and alarms"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

# Security
variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access resources"
  type        = list(string)
  default     = []
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for critical resources"
  type        = bool
  default     = true
}

# Cost Optimization
variable "enable_spot_instances" {
  description = "Enable spot instances for non-critical workloads"
  type        = bool
  default     = true  # Enabled by default for cost savings
}

variable "spot_max_price" {
  description = "Maximum price for spot instances (empty = on-demand price)"
  type        = string
  default     = ""  # Uses on-demand price as max
}

variable "spot_allocation_percentage" {
  description = "Percentage of capacity to run on spot instances"
  type        = number
  default     = 70  # 70% spot, 30% on-demand for balance
}

variable "enable_scheduled_scaling" {
  description = "Enable scheduled scaling for dev/staging environments"
  type        = bool
  default     = true
}

variable "scale_down_schedule" {
  description = "Cron expression for scaling down (UTC)"
  type        = string
  default     = "0 20 * * MON-FRI"  # 8 PM UTC (3 PM EST) weekdays
}

variable "scale_up_schedule" {
  description = "Cron expression for scaling up (UTC)"
  type        = string
  default     = "0 12 * * MON-FRI"  # 12 PM UTC (7 AM EST) weekdays
}

# Multi-account variables
variable "master_account_id" {
  description = "AWS account ID for the master/billing account"
  type        = string
  default     = ""
}

variable "external_id" {
  description = "External ID for cross-account role assumption"
  type        = string
  default     = "diagnyx-secure-external-id-2024"
}

variable "assume_role_arn" {
  description = "ARN of the role to assume for cross-account access"
  type        = string
  default     = ""
}

# Authentication Module Variables
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

variable "api_gateway_endpoint" {
  description = "API Gateway endpoint for Lambda callbacks"
  type        = string
  default     = "https://api.diagnyx.ai"
}