# S3 Buckets for ML Assets and Prompt Library
# Cost: ~$0.10/month when empty, ~$2.30/month with 100GB models
# Purpose: Centralized storage for ML models, prompts, and evaluation datasets

# ML Models and Assets Bucket
resource "aws_s3_bucket" "ml_assets" {
  bucket = "diagnyx-ml-assets-${data.aws_caller_identity.current.account_id}"
  
  tags = merge(
    local.common_tags,
    {
      Name        = "ML Assets Storage"
      Type        = "ml-storage"
      Description = "Hallucination detection models, evaluation models, training datasets"
    }
  )
}

resource "aws_s3_bucket_versioning" "ml_assets" {
  bucket = aws_s3_bucket.ml_assets.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "ml_assets" {
  bucket = aws_s3_bucket.ml_assets.id
  
  rule {
    id     = "transition-old-models"
    status = "Enabled"
    
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
    
    transition {
      days          = 90
      storage_class = "GLACIER"
    }
    
    noncurrent_version_transition {
      noncurrent_days = 7
      storage_class   = "STANDARD_IA"
    }
    
    noncurrent_version_expiration {
      noncurrent_days = 180
    }
  }
}

# Prompt Library Bucket with Git-style versioning
resource "aws_s3_bucket" "prompt_library" {
  bucket = "diagnyx-prompt-library-${data.aws_caller_identity.current.account_id}"
  
  tags = merge(
    local.common_tags,
    {
      Name        = "Prompt Library"
      Type        = "prompt-storage"
      Description = "Versioned prompt templates and configurations"
    }
  )
}

resource "aws_s3_bucket_versioning" "prompt_library" {
  bucket = aws_s3_bucket.prompt_library.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# Evaluation Datasets Bucket
resource "aws_s3_bucket" "evaluation_datasets" {
  bucket = "diagnyx-evaluation-datasets-${data.aws_caller_identity.current.account_id}"
  
  tags = merge(
    local.common_tags,
    {
      Name        = "Evaluation Datasets"
      Type        = "dataset-storage"
      Description = "Test datasets for model evaluation"
    }
  )
}

# Training Data Bucket
resource "aws_s3_bucket" "training_data" {
  bucket = "diagnyx-training-data-${data.aws_caller_identity.current.account_id}"
  
  tags = merge(
    local.common_tags,
    {
      Name        = "Training Data"
      Type        = "training-storage"
      Description = "Training data for model fine-tuning"
    }
  )
}

# Bucket policies for cross-account access
locals {
  allowed_accounts = [
    var.dev_account_id,
    var.staging_account_id,
    var.uat_account_id,
    var.prod_account_id
  ]
}

resource "aws_s3_bucket_policy" "ml_assets" {
  bucket = aws_s3_bucket.ml_assets.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCrossAccountRead"
        Effect = "Allow"
        Principal = {
          AWS = [for account in local.allowed_accounts : "arn:aws:iam::${account}:root"]
        }
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.ml_assets.arn,
          "${aws_s3_bucket.ml_assets.arn}/*"
        ]
      },
      {
        Sid    = "AllowCICDWrite"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.master_account_id}:role/DiagnyxCrossAccountCICD"
        }
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.ml_assets.arn}/*"
      }
    ]
  })
}

resource "aws_s3_bucket_policy" "prompt_library" {
  bucket = aws_s3_bucket.prompt_library.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCrossAccountRead"
        Effect = "Allow"
        Principal = {
          AWS = [for account in local.allowed_accounts : "arn:aws:iam::${account}:root"]
        }
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:ListBucket",
          "s3:GetBucketVersioning",
          "s3:ListBucketVersions"
        ]
        Resource = [
          aws_s3_bucket.prompt_library.arn,
          "${aws_s3_bucket.prompt_library.arn}/*"
        ]
      },
      {
        Sid    = "AllowDeveloperWrite"
        Effect = "Allow"
        Principal = {
          AWS = [
            "arn:aws:iam::${var.dev_account_id}:role/DiagnyxCrossAccountDeveloper",
            "arn:aws:iam::${var.staging_account_id}:role/DiagnyxCrossAccountDeveloper"
          ]
        }
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = "${aws_s3_bucket.prompt_library.arn}/*"
        Condition = {
          StringLike = {
            "s3:x-amz-metadata-author" = "*"
          }
        }
      }
    ]
  })
}

# S3 bucket notifications for model updates
resource "aws_s3_bucket_notification" "ml_assets" {
  bucket = aws_s3_bucket.ml_assets.id
  
  topic {
    topic_arn = aws_sns_topic.ml_updates.arn
    events    = ["s3:ObjectCreated:*"]
    filter_prefix = "models/"
  }
}

# SNS topic for ML asset updates
resource "aws_sns_topic" "ml_updates" {
  name = "diagnyx-ml-asset-updates"
  
  tags = merge(
    local.common_tags,
    {
      Name = "ML Asset Updates"
    }
  )
}

# Pre-create folder structure
resource "aws_s3_object" "ml_folders" {
  for_each = toset([
    "models/hallucination-detection/",
    "models/evaluation/",
    "models/routing/",
    "datasets/training/",
    "datasets/evaluation/",
    "datasets/benchmarks/"
  ])
  
  bucket  = aws_s3_bucket.ml_assets.id
  key     = each.key
  content = ""
}

resource "aws_s3_object" "prompt_folders" {
  for_each = toset([
    "templates/system/",
    "templates/user/",
    "templates/evaluation/",
    "versions/",
    "experiments/"
  ])
  
  bucket  = aws_s3_bucket.prompt_library.id
  key     = each.key
  content = ""
}

# Outputs
output "ml_assets_bucket" {
  value       = aws_s3_bucket.ml_assets.id
  description = "ML assets bucket name"
}

output "prompt_library_bucket" {
  value       = aws_s3_bucket.prompt_library.id
  description = "Prompt library bucket name"
}

output "evaluation_datasets_bucket" {
  value       = aws_s3_bucket.evaluation_datasets.id
  description = "Evaluation datasets bucket name"
}

output "training_data_bucket" {
  value       = aws_s3_bucket.training_data.id
  description = "Training data bucket name"
}