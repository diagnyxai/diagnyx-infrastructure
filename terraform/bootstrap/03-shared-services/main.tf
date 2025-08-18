# Shared Services Account Setup
# This account hosts shared resources like ECR, Route53, etc.
# Minimal costs - only pay for actual usage

terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  backend "s3" {
    bucket         = "diagnyx-terraform-state-shared"
    key            = "shared-services/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "diagnyx-terraform-locks-shared"
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Environment = "shared"
      Project     = "diagnyx"
      ManagedBy   = "terraform"
      Purpose     = "shared-services"
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_organizations_organization" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  org_id     = data.aws_organizations_organization.current.id
  
  # All environment account IDs
  env_account_ids = [
    var.dev_account_id,
    var.staging_account_id,
    var.uat_account_id,
    var.prod_account_id
  ]
}

# ===========================================
# ECR - Shared Container Registry
# ===========================================

# ECR Repositories for shared images
resource "aws_ecr_repository" "shared_images" {
  for_each = toset([
    "base-images/node",
    "base-images/python",
    "base-images/java",
    "base-images/go",
    "monitoring/prometheus",
    "monitoring/grafana",
    "tools/kubectl",
    "tools/terraform"
  ])
  
  name                 = "diagnyx/${each.value}"
  image_tag_mutability = "MUTABLE"
  
  image_scanning_configuration {
    scan_on_push = true
  }
  
  lifecycle_policy {
    policy = jsonencode({
      rules = [
        {
          rulePriority = 1
          description  = "Keep last 20 images"
          selection = {
            tagStatus     = "any"
            countType     = "imageCountMoreThan"
            countNumber   = 20
          }
          action = {
            type = "expire"
          }
        }
      ]
    })
  }
  
  tags = {
    Name    = each.value
    Purpose = "shared-base-image"
  }
}

# ECR Repository Policy - Allow cross-account access
resource "aws_ecr_repository_policy" "cross_account_access" {
  for_each = aws_ecr_repository.shared_images
  
  repository = each.value.name
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCrossAccountPull"
        Effect = "Allow"
        Principal = {
          AWS = [for id in local.env_account_ids : "arn:aws:iam::${id}:root"]
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
      }
    ]
  })
}

# ===========================================
# Route53 - Shared DNS
# ===========================================

# Hosted Zone for main domain
resource "aws_route53_zone" "main" {
  name    = var.domain_name
  comment = "Main domain for Diagnyx platform"
  
  tags = {
    Name = var.domain_name
  }
}

# Sub-domains for each environment
resource "aws_route53_zone" "environments" {
  for_each = {
    dev     = "dev.${var.domain_name}"
    staging = "staging.${var.domain_name}"
    uat     = "uat.${var.domain_name}"
    prod    = var.domain_name  # Production uses apex domain
  }
  
  name    = each.value
  comment = "Domain for ${each.key} environment"
  
  tags = {
    Name        = each.value
    Environment = each.key
  }
}

# NS records in main zone for sub-domains
resource "aws_route53_record" "subdomain_ns" {
  for_each = {
    dev     = aws_route53_zone.environments["dev"]
    staging = aws_route53_zone.environments["staging"]
    uat     = aws_route53_zone.environments["uat"]
  }
  
  zone_id = aws_route53_zone.main.zone_id
  name    = each.value.name
  type    = "NS"
  ttl     = 172800
  records = each.value.name_servers
}

# ===========================================
# ACM - Shared SSL Certificates
# ===========================================

# Wildcard certificate for main domain
resource "aws_acm_certificate" "main" {
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"
  
  tags = {
    Name = var.domain_name
  }
  
  lifecycle {
    create_before_destroy = true
  }
}

# DNS validation for ACM certificate
resource "aws_route53_record" "acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
  
  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.main.zone_id
}

resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for record in aws_route53_record.acm_validation : record.fqdn]
}

# ===========================================
# Secrets Manager - Shared Secrets
# ===========================================

# Shared database master password
resource "aws_secretsmanager_secret" "db_master_password" {
  name                    = "diagnyx/shared/db-master-password"
  description            = "Master password for RDS instances"
  recovery_window_in_days = 7
  
  replica {
    region = "us-west-2"  # Replicate for DR
  }
}

resource "aws_secretsmanager_secret_version" "db_master_password" {
  secret_id     = aws_secretsmanager_secret.db_master_password.id
  secret_string = random_password.db_master.result
}

resource "random_password" "db_master" {
  length  = 32
  special = true
}

# API Keys vault
resource "aws_secretsmanager_secret" "api_keys" {
  name        = "diagnyx/shared/api-keys"
  description = "Shared API keys for external services"
}

# Cross-account access policy for secrets
resource "aws_secretsmanager_secret_policy" "cross_account" {
  secret_arn = aws_secretsmanager_secret.db_master_password.arn
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = [for id in local.env_account_ids : "arn:aws:iam::${id}:root"]
        }
        Action   = "secretsmanager:GetSecretValue"
        Resource = "*"
        Condition = {
          StringEquals = {
            "secretsmanager:VersionStage" = "AWSCURRENT"
          }
        }
      }
    ]
  })
}

# ===========================================
# S3 - Shared Buckets
# ===========================================

# Shared artifacts bucket
resource "aws_s3_bucket" "artifacts" {
  bucket = "diagnyx-shared-artifacts-${local.account_id}"
  
  tags = {
    Purpose = "shared-artifacts"
  }
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# Bucket policy for cross-account access
resource "aws_s3_bucket_policy" "artifacts_cross_account" {
  bucket = aws_s3_bucket.artifacts.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = [for id in local.env_account_ids : "arn:aws:iam::${id}:root"]
        }
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.artifacts.arn,
          "${aws_s3_bucket.artifacts.arn}/*"
        ]
      }
    ]
  })
}

# ===========================================
# Parameter Store - Shared Configuration
# ===========================================

# Shared parameters
resource "aws_ssm_parameter" "shared_config" {
  for_each = {
    "/diagnyx/shared/vpc/cidr"           = "10.0.0.0/16"
    "/diagnyx/shared/domain"              = var.domain_name
    "/diagnyx/shared/ecr/registry"        = "${local.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
    "/diagnyx/shared/monitoring/enabled"  = "true"
  }
  
  name  = each.key
  type  = "String"
  value = each.value
  
  tags = {
    Purpose = "shared-configuration"
  }
}

# ===========================================
# IAM Roles for Cross-Account Access
# ===========================================

# Role for pulling ECR images from other accounts
resource "aws_iam_role" "ecr_pull_role" {
  name = "DiagnyxECRPullRole"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = [for id in local.env_account_ids : "arn:aws:iam::${id}:root"]
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "ecr_pull_policy" {
  name = "ECRPullPolicy"
  role = aws_iam_role.ecr_pull_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      }
    ]
  })
}

# ===========================================
# CloudWatch Logs - Centralized Logging
# ===========================================

# Log group for centralized application logs
resource "aws_cloudwatch_log_group" "centralized" {
  name              = "/aws/diagnyx/centralized"
  retention_in_days = 30
  
  tags = {
    Purpose = "centralized-logging"
  }
}

# Cross-account log destination
resource "aws_logs_destination" "central" {
  name       = "DiagnyxCentralLogs"
  role_arn   = aws_iam_role.logs_destination.arn
  target_arn = aws_kinesis_stream.logs.arn
}

resource "aws_logs_destination_policy" "central" {
  destination_name = aws_logs_destination.central.name
  access_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = local.env_account_ids
        }
        Action   = "logs:PutSubscriptionFilter"
        Resource = "arn:aws:logs:${var.aws_region}:${local.account_id}:destination:DiagnyxCentralLogs"
      }
    ]
  })
}

# Kinesis stream for log aggregation (pay per use)
resource "aws_kinesis_stream" "logs" {
  name             = "diagnyx-central-logs"
  shard_count      = 1  # Start with 1 shard, scale as needed
  retention_period = 24
  
  shard_level_metrics = [
    "IncomingRecords",
    "OutgoingRecords"
  ]
  
  stream_mode_details {
    stream_mode = "ON_DEMAND"  # Pay per GB of data
  }
  
  tags = {
    Purpose = "log-aggregation"
  }
}

resource "aws_iam_role" "logs_destination" {
  name = "DiagnyxLogsDestinationRole"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "logs.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "logs_destination" {
  name = "LogsDestinationPolicy"
  role = aws_iam_role.logs_destination.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kinesis:PutRecords",
          "kinesis:PutRecord"
        ]
        Resource = aws_kinesis_stream.logs.arn
      }
    ]
  })
}

# Outputs
output "ecr_registry" {
  value       = "${local.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
  description = "ECR registry URL"
}

output "route53_zone_ids" {
  value = {
    main = aws_route53_zone.main.zone_id
    environments = {
      for k, v in aws_route53_zone.environments : k => v.zone_id
    }
  }
  description = "Route53 hosted zone IDs"
}

output "acm_certificate_arn" {
  value       = aws_acm_certificate.main.arn
  description = "ACM certificate ARN for the main domain"
}

output "artifacts_bucket" {
  value       = aws_s3_bucket.artifacts.id
  description = "Shared artifacts S3 bucket"
}

output "logs_destination_arn" {
  value       = aws_logs_destination.central.arn
  description = "CloudWatch Logs destination for centralized logging"
}