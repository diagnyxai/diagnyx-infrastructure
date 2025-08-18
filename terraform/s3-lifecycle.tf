# S3 Buckets with Lifecycle Policies for Cost Optimization

# Application Logs Bucket
resource "aws_s3_bucket" "logs" {
  bucket = "${local.name_prefix}-logs"
  
  tags = merge(
    local.common_tags,
    {
      Purpose = "application-logs"
      CostCenter = "storage"
    }
  )
}

# Lifecycle policy for logs
resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
  
  rule {
    id     = "transition-old-logs"
    status = "Enabled"
    
    transition {
      days          = var.environment == "production" ? 30 : 7
      storage_class = "STANDARD_IA"  # Infrequent Access after 7-30 days
    }
    
    transition {
      days          = var.environment == "production" ? 90 : 30
      storage_class = "GLACIER_IR"  # Glacier Instant Retrieval
    }
    
    transition {
      days          = var.environment == "production" ? 180 : 60
      storage_class = "DEEP_ARCHIVE"  # Deep Archive for long-term
    }
    
    expiration {
      days = var.environment == "production" ? 365 : 90  # Delete after 1 year (prod) or 90 days
    }
    
    noncurrent_version_expiration {
      noncurrent_days = 30  # Delete old versions after 30 days
    }
  }
  
  rule {
    id     = "delete-incomplete-uploads"
    status = "Enabled"
    
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# Backups Bucket
resource "aws_s3_bucket" "backups" {
  bucket = "${local.name_prefix}-backups"
  
  tags = merge(
    local.common_tags,
    {
      Purpose = "database-backups"
      CostCenter = "storage"
    }
  )
}

# Lifecycle policy for backups
resource "aws_s3_bucket_lifecycle_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id
  
  rule {
    id     = "optimize-backup-storage"
    status = "Enabled"
    
    transition {
      days          = 7
      storage_class = "STANDARD_IA"  # Move to IA after 1 week
    }
    
    transition {
      days          = 30
      storage_class = "GLACIER_IR"  # Glacier for older backups
    }
    
    expiration {
      days = var.environment == "production" ? 90 : 30  # Keep backups for 90 days (prod) or 30 days
    }
  }
}

# Metrics and Analytics Bucket
resource "aws_s3_bucket" "metrics" {
  bucket = "${local.name_prefix}-metrics"
  
  tags = merge(
    local.common_tags,
    {
      Purpose = "metrics-storage"
      CostCenter = "analytics"
    }
  )
}

# Intelligent Tiering for metrics (unpredictable access patterns)
resource "aws_s3_bucket_intelligent_tiering_configuration" "metrics" {
  bucket = aws_s3_bucket.metrics.id
  name   = "optimize-metrics-storage"
  
  tiering {
    access_tier = "ARCHIVE_ACCESS"
    days        = 90
  }
  
  tiering {
    access_tier = "DEEP_ARCHIVE_ACCESS"
    days        = 180
  }
  
  filter {
    prefix = "historical/"
  }
}

# ML Models and Artifacts Bucket
resource "aws_s3_bucket" "ml_artifacts" {
  bucket = "${local.name_prefix}-ml-artifacts"
  
  tags = merge(
    local.common_tags,
    {
      Purpose = "ml-model-storage"
      CostCenter = "ai-quality"
    }
  )
}

# Lifecycle for ML artifacts
resource "aws_s3_bucket_lifecycle_configuration" "ml_artifacts" {
  bucket = aws_s3_bucket.ml_artifacts.id
  
  rule {
    id     = "archive-old-models"
    status = "Enabled"
    
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
    
    # Keep production models longer
    filter {
      tag {
        key   = "ModelType"
        value = "production"
      }
    }
    
    expiration {
      days = 365  # Keep production models for 1 year
    }
  }
  
  rule {
    id     = "cleanup-experimental-models"
    status = "Enabled"
    
    filter {
      tag {
        key   = "ModelType"
        value = "experimental"
      }
    }
    
    expiration {
      days = 30  # Delete experimental models after 30 days
    }
  }
}

# Static Assets Bucket (for CDN)
resource "aws_s3_bucket" "static_assets" {
  bucket = "${local.name_prefix}-static-assets"
  
  tags = merge(
    local.common_tags,
    {
      Purpose = "static-content"
      CostCenter = "cdn"
    }
  )
}

# No lifecycle for static assets - served via CloudFront

# Temporary Data Bucket
resource "aws_s3_bucket" "temp" {
  bucket = "${local.name_prefix}-temp"
  
  tags = merge(
    local.common_tags,
    {
      Purpose = "temporary-storage"
      CostCenter = "processing"
    }
  )
}

# Aggressive cleanup for temporary data
resource "aws_s3_bucket_lifecycle_configuration" "temp" {
  bucket = aws_s3_bucket.temp.id
  
  rule {
    id     = "cleanup-temp-data"
    status = "Enabled"
    
    expiration {
      days = 1  # Delete temporary data after 1 day
    }
    
    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

# S3 Bucket Public Access Block (security)
resource "aws_s3_bucket_public_access_block" "all_buckets" {
  for_each = {
    logs        = aws_s3_bucket.logs.id
    backups     = aws_s3_bucket.backups.id
    metrics     = aws_s3_bucket.metrics.id
    ml_artifacts = aws_s3_bucket.ml_artifacts.id
    static_assets = aws_s3_bucket.static_assets.id
    temp        = aws_s3_bucket.temp.id
  }
  
  bucket = each.value
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucket Versioning (only for critical data)
resource "aws_s3_bucket_versioning" "critical_buckets" {
  for_each = var.enable_s3_versioning ? {
    backups     = aws_s3_bucket.backups.id
    ml_artifacts = aws_s3_bucket.ml_artifacts.id
  } : {}
  
  bucket = each.value
  
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Storage Lens for cost visibility
resource "aws_s3control_storage_lens_configuration" "cost_analysis" {
  config_id = "${local.name_prefix}-cost-lens"
  
  storage_lens_configuration {
    enabled = true
    
    account_level {
      activity_metrics {
        enabled = true
      }
      
      bucket_level {
        activity_metrics {
          enabled = true
        }
        
        prefix_level {
          storage_metrics {
            enabled = true
            
            selection_criteria {
              delimiter = "/"
              max_depth = 3
            }
          }
        }
      }
    }
    
    data_export {
      s3_bucket_destination {
        account_id            = data.aws_caller_identity.current.account_id
        arn                   = aws_s3_bucket.metrics.arn
        format                = "CSV"
        output_schema_version = "V_1"
        prefix                = "storage-lens/"
        
        encryption {
          sse_s3 {}
        }
      }
    }
  }
}

# CloudWatch Alarms for S3 costs
resource "aws_cloudwatch_metric_alarm" "s3_storage_cost" {
  alarm_name          = "${local.name_prefix}-s3-storage-cost"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "BucketSizeBytes"
  namespace           = "AWS/S3"
  period              = "86400"  # Daily
  statistic           = "Average"
  threshold           = var.environment == "production" ? 1000000000000 : 100000000000  # 1TB for prod, 100GB for non-prod
  alarm_description   = "Alert when S3 storage exceeds threshold"
  alarm_actions       = var.enable_monitoring ? [aws_sns_topic.cost_alerts[0].arn] : []
  
  dimensions = {
    StorageType = "StandardStorage"
  }
}