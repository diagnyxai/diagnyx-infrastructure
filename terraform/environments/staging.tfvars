# Staging Environment Configuration
# Balanced between cost optimization and production-like setup

environment = "staging"
aws_region  = "us-east-1"

# VPC Configuration - Single NAT for staging
vpc_cidr            = "10.1.0.0/16"
enable_nat_gateway  = true
single_nat_gateway  = true  # Save $90/month with single NAT

# EKS Configuration - Moderate sizing
eks_cluster_version         = "1.28"
eks_node_group_desired_size = 2
eks_node_group_min_size     = 1
eks_node_group_max_size     = 5
eks_node_instance_types     = ["t4g.medium", "t4g.large"]  # ARM-based for savings
eks_spot_instance_types     = ["t4g.medium", "t4g.large", "t3a.medium", "t3a.large"]

# RDS Configuration - Medium instance
rds_instance_class           = "db.t4g.small"  # $30/month
rds_allocated_storage        = 50
rds_max_allocated_storage    = 200
rds_backup_retention_period  = 7  # 1 week of backups
rds_multi_az                 = false  # Single AZ for staging

# ElastiCache Configuration - Small cluster
elasticache_node_type        = "cache.t4g.small"  # $26/month
elasticache_num_cache_nodes  = 2  # Small cluster

# S3 Configuration
enable_s3_versioning = true  # Enable versioning for testing
s3_lifecycle_days    = 60  # Moderate lifecycle

# Monitoring - Standard retention
enable_monitoring   = true
log_retention_days  = 7  # 1 week retention

# Cost Optimization - Balanced approach
enable_spot_instances       = true
spot_allocation_percentage  = 70  # 70% spot, 30% on-demand
enable_scheduled_scaling    = true
scale_down_schedule        = "0 22 * * MON-FRI"  # 10 PM UTC (5 PM EST)
scale_up_schedule          = "0 10 * * MON-FRI"  # 10 AM UTC (5 AM EST)

# Security
enable_deletion_protection = false  # Allow cleanup after testing