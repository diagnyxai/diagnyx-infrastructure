# ECS Service IAM Roles
# These roles are assumed by ECS tasks to access AWS resources

# ==================== ECS TASK EXECUTION ROLE ====================
# Used by ECS to pull images and write logs
resource "aws_iam_role" "ecs_task_execution" {
  name = "DiagnyxECSTaskExecutionRole"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "DiagnyxECSTaskExecutionRole"
    Purpose     = "ecs-task-execution"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Attach AWS managed policy for ECS task execution
resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Additional policy for Secrets Manager and Parameter Store
resource "aws_iam_role_policy" "ecs_task_execution_secrets" {
  name = "ecs-task-execution-secrets"
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "kms:Decrypt"
        ]
        Resource = [
          "arn:aws:secretsmanager:us-east-1:*:secret:diagnyx-*",
          "arn:aws:kms:us-east-1:*:key/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameters",
          "ssm:GetParameter"
        ]
        Resource = "arn:aws:ssm:us-east-1:*:parameter/diagnyx/*"
      }
    ]
  })
}

# ==================== USER SERVICE TASK ROLE ====================
resource "aws_iam_role" "user_service_task" {
  name = "DiagnyxECSTaskRole-UserService"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "DiagnyxECSTaskRole-UserService"
    Service     = "user-service"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# User Service specific permissions
resource "aws_iam_role_policy" "user_service_policy" {
  name = "user-service-policy"
  role = aws_iam_role.user_service_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          "arn:aws:secretsmanager:us-east-1:*:secret:diagnyx/user-service/*",
          "arn:aws:secretsmanager:us-east-1:*:secret:diagnyx/jwt-*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = [
          "arn:aws:s3:::diagnyx-user-avatars-${var.environment}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach common policies
resource "aws_iam_role_policy_attachment" "user_service_cloudwatch" {
  role       = aws_iam_role.user_service_task.name
  policy_arn = aws_iam_policy.cloudwatch_access.arn
}

# ==================== OBSERVABILITY SERVICE TASK ROLE ====================
resource "aws_iam_role" "observability_service_task" {
  name = "DiagnyxECSTaskRole-ObservabilityService"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "DiagnyxECSTaskRole-ObservabilityService"
    Service     = "observability-service"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Observability Service specific permissions
resource "aws_iam_role_policy" "observability_service_policy" {
  name = "observability-service-policy"
  role = aws_iam_role.observability_service_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kinesis:PutRecords",
          "kinesis:PutRecord",
          "kinesis:DescribeStream",
          "kinesis:ListStreams"
        ]
        Resource = "arn:aws:kinesis:us-east-1:*:stream/diagnyx-*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::diagnyx-traces-${var.environment}/*",
          "arn:aws:s3:::diagnyx-metrics-${var.environment}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "timestream:WriteRecords",
          "timestream:DescribeEndpoints"
        ]
        Resource = "*"
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

# ==================== AI QUALITY SERVICE TASK ROLE ====================
resource "aws_iam_role" "ai_quality_service_task" {
  name = "DiagnyxECSTaskRole-AIQualityService"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "DiagnyxECSTaskRole-AIQualityService"
    Service     = "ai-quality-service"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# AI Quality Service specific permissions
resource "aws_iam_role_policy" "ai_quality_service_policy" {
  name = "ai-quality-service-policy"
  role = aws_iam_role.ai_quality_service_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = "arn:aws:bedrock:us-east-1::foundation-model/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = [
          "arn:aws:s3:::diagnyx-ml-models-${var.environment}/*",
          "arn:aws:s3:::diagnyx-evaluations-${var.environment}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sagemaker:InvokeEndpoint"
        ]
        Resource = "arn:aws:sagemaker:us-east-1:*:endpoint/diagnyx-*"
      }
    ]
  })
}

# ==================== OPTIMIZATION SERVICE TASK ROLE ====================
resource "aws_iam_role" "optimization_service_task" {
  name = "DiagnyxECSTaskRole-OptimizationService"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "DiagnyxECSTaskRole-OptimizationService"
    Service     = "optimization-service"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Optimization Service specific permissions
resource "aws_iam_role_policy" "optimization_service_policy" {
  name = "optimization-service-policy"
  role = aws_iam_role.optimization_service_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ce:GetCostAndUsage",
          "ce:GetCostForecast",
          "ce:GetReservationUtilization",
          "ce:GetSavingsPlansPurchaseRecommendation"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = [
          "arn:aws:s3:::diagnyx-prompts-${var.environment}/*",
          "arn:aws:s3:::diagnyx-cost-reports-${var.environment}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:Query",
          "dynamodb:UpdateItem"
        ]
        Resource = "arn:aws:dynamodb:us-east-1:*:table/diagnyx-prompt-versions-${var.environment}"
      }
    ]
  })
}

# ==================== API GATEWAY TASK ROLE ====================
resource "aws_iam_role" "api_gateway_task" {
  name = "DiagnyxECSTaskRole-APIGateway"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "DiagnyxECSTaskRole-APIGateway"
    Service     = "api-gateway"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# API Gateway specific permissions
resource "aws_iam_role_policy" "api_gateway_policy" {
  name = "api-gateway-policy"
  role = aws_iam_role.api_gateway_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "elasticache:DescribeCacheClusters",
          "elasticache:DescribeCacheNodes"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "wafv2:GetWebACL",
          "wafv2:GetRateBasedStatementManagedKeys"
        ]
        Resource = "arn:aws:wafv2:us-east-1:*:*/webacl/diagnyx-*"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
      }
    ]
  })
}

# Outputs
output "ecs_role_arns" {
  value = {
    task_execution      = aws_iam_role.ecs_task_execution.arn
    user_service        = aws_iam_role.user_service_task.arn
    observability       = aws_iam_role.observability_service_task.arn
    ai_quality          = aws_iam_role.ai_quality_service_task.arn
    optimization        = aws_iam_role.optimization_service_task.arn
    api_gateway         = aws_iam_role.api_gateway_task.arn
  }
  description = "ARNs of ECS task roles"
}