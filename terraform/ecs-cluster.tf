# ECS Cluster Configuration - Cost-optimized alternative to EKS
# Estimated cost: ~$150/month vs $500+ for EKS

locals {
  ecs_name = "diagnyx-${var.environment}"
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = local.ecs_name

  setting {
    name  = "containerInsights"
    value = var.environment == "production" ? "enabled" : "disabled"
  }

  configuration {
    execute_command_configuration {
      logging = "OVERRIDE"

      log_configuration {
        cloud_watch_encryption_enabled = true
        cloud_watch_log_group_name     = aws_cloudwatch_log_group.ecs_exec.name
      }
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name = local.ecs_name
    }
  )
}

# Capacity Providers for mixed Spot/On-Demand instances
resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = [
    aws_ecs_capacity_provider.spot.name,
    aws_ecs_capacity_provider.on_demand.name
  ]

  # 70% Spot, 30% On-Demand for cost optimization with reliability
  default_capacity_provider_strategy {
    base              = 1
    weight            = 30
    capacity_provider = aws_ecs_capacity_provider.on_demand.name
  }

  default_capacity_provider_strategy {
    weight            = 70
    capacity_provider = aws_ecs_capacity_provider.spot.name
  }
}

# CloudWatch Log Groups with optimized retention
resource "aws_cloudwatch_log_group" "ecs_exec" {
  name = "/ecs/${local.ecs_name}/exec"
  # Environment-specific log retention for MVP
  retention_in_days = var.environment == "production" ? 7 : (
    var.environment == "uat" ? 3 : 1
  )

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "ecs_services" {
  name = "/ecs/${local.ecs_name}/services"
  # Environment-specific log retention for MVP
  retention_in_days = var.environment == "production" ? 7 : (
    var.environment == "uat" ? 3 : 1
  )

  tags = local.common_tags
}

# S3 bucket for long-term log archival with lifecycle policies
resource "aws_s3_bucket" "log_archive" {
  bucket = "diagnyx-${var.environment}-log-archive-${random_id.bucket_suffix.hex}"

  tags = merge(local.common_tags, {
    Name    = "diagnyx-${var.environment}-log-archive"
    Purpose = "Long-term log storage with lifecycle management"
  })
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket_versioning" "log_archive" {
  bucket = aws_s3_bucket.log_archive.id
  versioning_configuration {
    status = "Disabled"  # No versioning needed for logs
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "log_archive" {
  bucket = aws_s3_bucket.log_archive.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "log_archive" {
  bucket = aws_s3_bucket.log_archive.id

  rule {
    id     = "log_lifecycle"
    status = "Enabled"

    transition {
      days          = 7
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 30
      storage_class = "GLACIER"
    }

    expiration {
      days = 90  # 3 months maximum retention for all environments
    }
  }
}

# Service Discovery Namespace
resource "aws_service_discovery_private_dns_namespace" "main" {
  name        = "${var.environment}.diagnyx.local"
  description = "Private DNS namespace for Diagnyx services"
  vpc         = module.vpc.vpc_id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}.diagnyx.local"
    }
  )
}

# ECS Task Execution Role
resource "aws_iam_role" "ecs_task_execution" {
  name = "${local.ecs_name}-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Additional permissions for pulling from ECR and writing logs
resource "aws_iam_role_policy" "ecs_task_execution_additional" {
  name = "ecs-task-execution-additional"
  role = aws_iam_role.ecs_task_execution.id

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
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.ecs_services.arn}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:diagnyx-*"
      }
    ]
  })
}

# ECS Task Role (for containers)
resource "aws_iam_role" "ecs_task" {
  name = "${local.ecs_name}-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

# Task role permissions for S3, SQS, etc.
resource "aws_iam_role_policy" "ecs_task" {
  name = "ecs-task-policy"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "arn:aws:s3:::diagnyx-${var.environment}-*/*"
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage"
        ]
        Resource = "arn:aws:sqs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:diagnyx-*"
      },
      {
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords"
        ]
        Resource = "*"
      }
    ]
  })
}

# Output values
output "ecs_cluster_id" {
  value       = aws_ecs_cluster.main.id
  description = "ECS Cluster ID"
}

output "ecs_cluster_name" {
  value       = aws_ecs_cluster.main.name
  description = "ECS Cluster Name"
}

output "service_discovery_namespace_id" {
  value       = aws_service_discovery_private_dns_namespace.main.id
  description = "Service Discovery Namespace ID"
}

output "ecs_task_execution_role_arn" {
  value       = aws_iam_role.ecs_task_execution.arn
  description = "ECS Task Execution Role ARN"
}

output "ecs_task_role_arn" {
  value       = aws_iam_role.ecs_task.arn
  description = "ECS Task Role ARN"
}