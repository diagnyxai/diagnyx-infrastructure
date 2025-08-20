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
    api_gateway         = aws_iam_role.api_gateway_task.arn
  }
  description = "ARNs of ECS task roles"
}