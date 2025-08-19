# ECR Repositories - Shared Container Registry
# Cost: ~$0.10/month for minimal storage (<500MB)
# Purpose: Centralized container image storage shared across all environments

locals {
  # List of services that need ECR repositories (simplified)
  ecr_repositories = [
    "user-service",
    "diagnyx-api-gateway",
    "diagnyx-ui"
  ]
  
  # Lifecycle policy for cost optimization
  lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images for production tags"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["prod", "production"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep last 5 images for staging/uat tags"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["staging", "uat"]
          countType     = "imageCountMoreThan"
          countNumber   = 5
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 3
        description  = "Keep last 3 images for dev tags"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["dev", "development"]
          countType     = "imageCountMoreThan"
          countNumber   = 3
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 4
        description  = "Remove untagged images after 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# Create ECR repositories
resource "aws_ecr_repository" "services" {
  for_each = toset(local.ecr_repositories)
  
  name                 = "diagnyx/${each.key}"
  image_tag_mutability = "MUTABLE"
  
  image_scanning_configuration {
    scan_on_push = true
  }
  
  encryption_configuration {
    encryption_type = "AES256"
  }
  
  tags = merge(
    local.common_tags,
    {
      Service = each.key
      Type    = "container-registry"
    }
  )
}

# Apply lifecycle policies to repositories
resource "aws_ecr_lifecycle_policy" "services" {
  for_each = aws_ecr_repository.services
  
  repository = each.value.name
  policy     = local.lifecycle_policy
}

# Repository policies for cross-account access
resource "aws_ecr_repository_policy" "cross_account" {
  for_each = aws_ecr_repository.services
  
  repository = each.value.name
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCrossAccountPull"
        Effect = "Allow"
        Principal = {
          AWS = [
            "arn:aws:iam::${var.dev_account_id}:root",
            "arn:aws:iam::${var.staging_account_id}:root",
            "arn:aws:iam::${var.uat_account_id}:root",
            "arn:aws:iam::${var.prod_account_id}:root"
          ]
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
      },
      {
        Sid    = "AllowCrossAccountPush"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.master_account_id}:role/DiagnyxCrossAccountCICD"
        }
        Action = [
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
      }
    ]
  })
}

# Create pull through cache for Docker Hub (cost optimization)
resource "aws_ecr_pull_through_cache_rule" "docker_hub" {
  ecr_repository_prefix = "docker-hub"
  upstream_registry_url = "registry-1.docker.io"
}

# Create pull through cache for ECR Public
resource "aws_ecr_pull_through_cache_rule" "ecr_public" {
  ecr_repository_prefix = "ecr-public"
  upstream_registry_url = "public.ecr.aws"
}

# Outputs
output "ecr_repository_urls" {
  value = {
    for k, v in aws_ecr_repository.services : k => v.repository_url
  }
  description = "URLs of ECR repositories"
}

output "ecr_repository_arns" {
  value = {
    for k, v in aws_ecr_repository.services : k => v.arn
  }
  description = "ARNs of ECR repositories"
}