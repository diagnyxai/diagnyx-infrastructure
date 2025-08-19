# Development Environment Configuration
# Optimized for minimal cost while maintaining functionality

environment = "development"
aws_region  = "us-east-1"

# Account IDs (replace with actual IDs after account creation)
master_account_id          = "111111111111"  # Replace with master account ID
shared_services_account_id = "222222222222"  # Replace with shared services account ID
security_account_id        = "333333333333"  # Replace with security account ID
dev_account_id            = "444444444444"  # Replace with dev account ID
staging_account_id        = "555555555555"  # Replace with staging account ID
uat_account_id            = "666666666666"  # Replace with UAT account ID
prod_account_id           = "777777777777"  # Replace with prod account ID

# Cross-account role assumption (if deploying from CI/CD)
assume_role_arn = ""  # Set to "arn:aws:iam::444444444444:role/DiagnyxCrossAccountCICD" if needed
external_id     = "diagnyx-secure-external-id-2024"

# VPC Configuration - Single NAT for dev
vpc_cidr            = "10.0.0.0/16"
enable_nat_gateway  = true
single_nat_gateway  = true  # Save $45/month per additional NAT

# EKS Configuration - Minimal sizing
eks_cluster_version         = "1.28"
eks_node_group_desired_size = 1
eks_node_group_min_size     = 1
eks_node_group_max_size     = 3
eks_node_instance_types     = ["t4g.small", "t4g.medium"]  # ARM-based, 20% cheaper
eks_spot_instance_types     = ["t4g.small", "t4g.medium", "t3a.small", "t3a.medium"]

# RDS Configuration - Smallest viable instance
rds_instance_class           = "db.t4g.micro"  # $15/month
rds_allocated_storage        = 20
rds_max_allocated_storage    = 100
rds_backup_retention_period  = 1  # Minimal backups for dev
rds_multi_az                 = false  # Single AZ for dev

# ElastiCache removed - using in-memory caching

# S3 Configuration
enable_s3_versioning = false  # No versioning in dev
s3_lifecycle_days    = 30  # Quick transition to cheaper storage

# Monitoring - Reduced retention
enable_monitoring   = true
log_retention_days  = 3  # Minimal log retention

# Cost Optimization - Maximum savings
enable_spot_instances       = true
spot_allocation_percentage  = 90  # 90% spot for dev
enable_scheduled_scaling    = true
scale_down_schedule        = "0 19 * * MON-FRI"  # 7 PM UTC (2 PM EST)
scale_up_schedule          = "0 11 * * MON-FRI"  # 11 AM UTC (6 AM EST)

# Security
enable_deletion_protection = false  # Allow easy cleanup in dev