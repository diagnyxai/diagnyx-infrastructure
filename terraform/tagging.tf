# Comprehensive Tagging Strategy for Cost Tracking

# Default tags applied to all resources
locals {
  mandatory_tags = {
    Environment     = var.environment
    Project         = "diagnyx"
    ManagedBy       = "terraform"
    Owner           = var.owner_email
    CreatedDate     = timestamp()
    CostCenter      = var.environment == "production" ? "production" : "development"
    BusinessUnit    = "engineering"
    Compliance      = "standard"
    DataClass       = var.environment == "production" ? "confidential" : "internal"
  }
  
  cost_allocation_tags = {
    Service         = "platform"
    Team            = "devops"
    Application     = "diagnyx-llm-observability"
    Version         = "1.0.0"
    AutoShutdown    = var.environment != "production" ? "true" : "false"
    ScheduledScaling = var.enable_scheduled_scaling ? "enabled" : "disabled"
  }
  
  # Service-specific tags
  service_tags = {
    user_service = {
      Component     = "user-service"
      ServiceType   = "authentication"
      Runtime       = "java"
      Framework     = "spring-boot"
    }
    observability_service = {
      Component     = "observability-service"
      ServiceType   = "ingestion"
      Runtime       = "go"
      Framework     = "gin"
    }
    ai_quality_service = {
      Component     = "ai-quality-service"
      ServiceType   = "ml-evaluation"
      Runtime       = "python"
      Framework     = "fastapi"
    }
    optimization_service = {
      Component     = "optimization-service"
      ServiceType   = "cost-optimization"
      Runtime       = "go"
      Framework     = "gin"
    }
    api_gateway = {
      Component     = "api-gateway"
      ServiceType   = "gateway"
      Runtime       = "nodejs"
      Framework     = "express"
    }
  }
}

# Tag Policy for Organization
resource "aws_organizations_policy" "tagging_policy" {
  count = var.enable_tag_policy ? 1 : 0
  
  name        = "diagnyx-tagging-policy"
  description = "Enforces tagging standards for cost allocation"
  type        = "TAG_POLICY"
  
  content = jsonencode({
    tags = {
      Environment = {
        tag_key = {
          "@@assign" = "Environment"
        }
        tag_value = {
          "@@assign" = ["development", "staging", "production"]
        }
        enforced_for = {
          "@@assign" = ["ec2:instance", "ec2:volume", "rds:db", "s3:bucket"]
        }
      }
      CostCenter = {
        tag_key = {
          "@@assign" = "CostCenter"
        }
        tag_value = {
          "@@assign" = ["development", "production", "shared"]
        }
        enforced_for = {
          "@@assign" = ["ec2:*", "rds:*", "s3:*"]
        }
      }
      Owner = {
        tag_key = {
          "@@assign" = "Owner"
        }
        enforced_for = {
          "@@assign" = ["ec2:*", "rds:*"]
        }
      }
    }
  })
}

# Cost Allocation Tags Configuration
resource "aws_ce_cost_allocation_tag" "mandatory" {
  for_each = toset([
    "Environment",
    "CostCenter",
    "Service",
    "Team",
    "Component"
  ])
  
  tag_key = each.value
  status  = "Active"
}

# Resource Groups for Cost Tracking
resource "aws_resourcegroups_group" "environment" {
  name = "${local.name_prefix}-${var.environment}-resources"
  
  resource_query {
    query = jsonencode({
      ResourceTypeFilters = ["AWS::AllSupported"]
      TagFilters = [
        {
          Key    = "Environment"
          Values = [var.environment]
        }
      ]
    })
  }
  
  tags = merge(
    local.mandatory_tags,
    local.cost_allocation_tags,
    {
      Purpose = "cost-tracking"
    }
  )
}

# Resource Groups by Service
resource "aws_resourcegroups_group" "by_service" {
  for_each = local.service_tags
  
  name = "${local.name_prefix}-${each.key}-resources"
  
  resource_query {
    query = jsonencode({
      ResourceTypeFilters = ["AWS::AllSupported"]
      TagFilters = [
        {
          Key    = "Component"
          Values = [each.value.Component]
        }
      ]
    })
  }
  
  tags = merge(
    local.mandatory_tags,
    local.cost_allocation_tags,
    each.value
  )
}

# Tag-based IAM Policy for Cost Management
resource "aws_iam_policy" "tag_based_permissions" {
  name        = "${local.name_prefix}-tag-based-permissions"
  description = "Enforce tag-based permissions for cost control"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RequireTagsOnResourceCreation"
        Effect = "Deny"
        Action = [
          "ec2:RunInstances",
          "ec2:CreateVolume",
          "rds:CreateDBInstance",
          "s3:CreateBucket"
        ]
        Resource = "*"
        Condition = {
          "Null" = {
            "aws:RequestTag/Environment" = "true"
            "aws:RequestTag/CostCenter"  = "true"
            "aws:RequestTag/Owner"        = "true"
          }
        }
      },
      {
        Sid    = "AllowResourceManagementBasedOnTags"
        Effect = "Allow"
        Action = [
          "ec2:TerminateInstances",
          "ec2:StopInstances",
          "ec2:StartInstances"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "ec2:ResourceTag/Environment" = var.environment
            "ec2:ResourceTag/Owner"       = var.owner_email
          }
        }
      }
    ]
  })
  
  tags = local.mandatory_tags
}

# Automated Tagging Lambda Function
resource "aws_lambda_function" "auto_tagger" {
  filename         = data.archive_file.auto_tagger.output_path
  function_name    = "${local.name_prefix}-auto-tagger"
  role            = aws_iam_role.auto_tagger.arn
  handler         = "index.handler"
  source_code_hash = data.archive_file.auto_tagger.output_base64sha256
  runtime         = "python3.11"
  timeout         = 30
  
  environment {
    variables = {
      DEFAULT_TAGS = jsonencode(merge(
        local.mandatory_tags,
        local.cost_allocation_tags
      ))
    }
  }
  
  tags = merge(
    local.mandatory_tags,
    {
      Purpose = "automated-tagging"
    }
  )
}

# Auto-tagger Lambda code
data "archive_file" "auto_tagger" {
  type        = "zip"
  output_path = "${path.module}/lambda/auto-tagger.zip"
  
  source {
    content  = file("${path.module}/lambda/auto_tagger.py")
    filename = "index.py"
  }
}

# IAM Role for Auto Tagger
resource "aws_iam_role" "auto_tagger" {
  name = "${local.name_prefix}-auto-tagger"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
  
  tags = local.mandatory_tags
}

# Auto Tagger IAM Policy
resource "aws_iam_role_policy" "auto_tagger" {
  name = "${local.name_prefix}-auto-tagger-policy"
  role = aws_iam_role.auto_tagger.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateTags",
          "ec2:DescribeInstances",
          "ec2:DescribeVolumes",
          "ec2:DescribeSnapshots",
          "rds:AddTagsToResource",
          "rds:DescribeDBInstances",
          "s3:PutBucketTagging",
          "s3:GetBucketTagging"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# CloudWatch Event Rule for Auto Tagging
resource "aws_cloudwatch_event_rule" "auto_tag_resources" {
  name        = "${local.name_prefix}-auto-tag-resources"
  description = "Trigger auto-tagging for new resources"
  
  event_pattern = jsonencode({
    source      = ["aws.ec2", "aws.rds", "aws.s3"]
    detail-type = [
      "EC2 Instance State-change Notification",
      "RDS DB Instance Event",
      "S3 Bucket Event"
    ]
  })
  
  tags = local.mandatory_tags
}

resource "aws_cloudwatch_event_target" "auto_tag" {
  rule      = aws_cloudwatch_event_rule.auto_tag_resources.name
  target_id = "AutoTaggerLambda"
  arn       = aws_lambda_function.auto_tagger.arn
}

resource "aws_lambda_permission" "auto_tag" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auto_tagger.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.auto_tag_resources.arn
}

# Variables for Tagging
variable "enable_tag_policy" {
  description = "Enable organization-wide tag policy"
  type        = bool
  default     = true
}