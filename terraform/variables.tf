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
  description = "Environment name (dev, staging, production)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production."
  }
}

variable "owner_email" {
  description = "Email of the infrastructure owner"
  type        = string
  default     = "infrastructure@diagnyx.ai"
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

# ElastiCache Configuration
variable "elasticache_node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.t4g.small"  # Changed from cache.r6g.large for 75% savings
}

variable "elasticache_node_type_production" {
  description = "ElastiCache node type for production"
  type        = string
  default     = "cache.t4g.medium"  # Graviton-based for production
}

variable "elasticache_num_cache_nodes" {
  description = "Number of cache nodes"
  type        = number
  default     = 2  # Reduced from 3 for non-production
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