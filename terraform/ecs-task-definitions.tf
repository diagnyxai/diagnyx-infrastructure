# ECS Task Definitions for Simplified Diagnyx Platform

locals {
  container_insights_enabled = var.environment == "production"
  
  # Common environment variables
  common_env_vars = [
    {
      name  = "ENVIRONMENT"
      value = var.environment
    },
    {
      name  = "AWS_REGION"
      value = var.aws_region
    },
    {
      name  = "LOG_LEVEL"
      value = var.environment == "production" ? "info" : "debug"
    }
  ]
}

# 1. User Service (Java/Spring Boot)
resource "aws_ecs_task_definition" "user_service" {
  family                   = "${local.ecs_name}-user-service"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  cpu                      = var.environment == "production" ? "512" : "256"
  memory                   = var.environment == "production" ? "1024" : "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name  = "user-service"
      image = "${aws_ecr_repository.services["user-service"].repository_url}:latest"
      
      essential = true
      
      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        }
      ]
      
      environment = concat(local.common_env_vars, [
        {
          name  = "SERVER_PORT"
          value = "8080"
        },
        {
          name  = "SPRING_PROFILES_ACTIVE"
          value = var.environment
        },
        {
          name  = "DATABASE_HOST"
          value = aws_db_instance.main.address
        },
        {
          name  = "CACHE_TYPE"
          value = "simple"
        }
      ])
      
      secrets = [
        {
          name      = "DATABASE_PASSWORD"
          valueFrom = aws_secretsmanager_secret.db_password.arn
        },
        {
          name      = "JWT_SECRET"
          valueFrom = aws_secretsmanager_secret.jwt_secret.arn
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_services.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "user-service"
        }
      }
      
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = local.common_tags
}

# 2. API Gateway Service (TypeScript/Node.js)
resource "aws_ecs_task_definition" "diagnyx_api_gateway" {
  family                   = "${local.ecs_name}-api-gateway"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  cpu                      = var.environment == "production" ? "512" : "256"
  memory                   = var.environment == "production" ? "512" : "256"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name  = "diagnyx-api-gateway"
      image = "${aws_ecr_repository.services["diagnyx-api-gateway"].repository_url}:latest"
      
      essential = true
      
      portMappings = [
        {
          containerPort = 8443
          protocol      = "tcp"
        }
      ]
      
      environment = concat(local.common_env_vars, [
        {
          name  = "PORT"
          value = "8443"
        },
        {
          name  = "NODE_ENV"
          value = var.environment
        },
        {
          name  = "USER_SERVICE_URL"
          value = "http://user-service.diagnyx.local:8080"
        },
        {
          name  = "HTTPS_ENABLED"
          value = "true"
        }
      ])
      
      secrets = [
        {
          name      = "JWT_SECRET"
          valueFrom = aws_secretsmanager_secret.jwt_secret.arn
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_services.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "diagnyx-api-gateway"
        }
      }
      
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f https://localhost:8443/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = local.common_tags
}

# 3. UI Service (Next.js/React)
resource "aws_ecs_task_definition" "diagnyx_ui" {
  family                   = "${local.ecs_name}-ui"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  cpu                      = var.environment == "production" ? "512" : "256"
  memory                   = var.environment == "production" ? "512" : "256"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name  = "diagnyx-ui"
      image = "${aws_ecr_repository.services["diagnyx-ui"].repository_url}:latest"
      
      essential = true
      
      portMappings = [
        {
          containerPort = 3000
          protocol      = "tcp"
        }
      ]
      
      environment = concat(local.common_env_vars, [
        {
          name  = "PORT"
          value = "3000"
        },
        {
          name  = "NODE_ENV"
          value = var.environment
        },
        {
          name  = "NEXT_PUBLIC_API_URL"
          value = var.environment == "production" ? "https://api.diagnyx.ai" : "https://api-staging.diagnyx.ai"
        },
        {
          name  = "NEXT_PUBLIC_SITE_URL"
          value = var.environment == "production" ? "https://diagnyx.ai" : "https://staging.diagnyx.ai"
        }
      ])
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_services.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "diagnyx-ui"
        }
      }
      
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:3000/ || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = local.common_tags
}