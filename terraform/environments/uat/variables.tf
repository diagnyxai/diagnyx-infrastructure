# UAT Environment Variables

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "uat"
}

variable "owner_email" {
  description = "Email of the infrastructure owner"
  type        = string
  default     = "infrastructure@diagnyx.ai"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.1.0.0/16"  # Different from other environments
}

variable "domain_name" {
  description = "Domain name for UAT environment"
  type        = string
  default     = "uat.diagnyx.ai"
}

# Database configuration
variable "database_name" {
  description = "Name of the database"
  type        = string
  default     = "diagnyx_uat"
}

variable "database_master_username" {
  description = "Master username for the database"
  type        = string
  default     = "diagnyx"
}

# Cost optimization settings for UAT
variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for UAT (false to use NAT instance for cost savings)"
  type        = bool
  default     = false
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days for UAT"
  type        = number
  default     = 7
}

# RDS configuration for UAT
variable "rds_instance_class" {
  description = "RDS instance class for UAT"
  type        = string
  default     = "db.t4g.small"
}

variable "rds_allocated_storage" {
  description = "Allocated storage for RDS in GB"
  type        = number
  default     = 30
}

variable "rds_max_allocated_storage" {
  description = "Maximum allocated storage for RDS in GB"
  type        = number
  default     = 200
}

variable "rds_backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

variable "rds_multi_az" {
  description = "Enable Multi-AZ for RDS"
  type        = bool
  default     = false
}