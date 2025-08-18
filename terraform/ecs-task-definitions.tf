# ECS Task Definitions for all Diagnyx services

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
          containerPort = 8001
          protocol      = "tcp"
        }
      ]
      
      environment = concat(local.common_env_vars, [
        {
          name  = "SERVER_PORT"
          value = "8001"
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
          name  = "REDIS_HOST"
          value = aws_elasticache_cluster.main.cache_nodes[0].address
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
        command     = ["CMD-SHELL", "curl -f http://localhost:8001/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = local.common_tags
}

# 2. Observability Service (Go)
resource "aws_ecs_task_definition" "observability_service" {
  family                   = "${local.ecs_name}-observability-service"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  cpu                      = var.environment == "production" ? "1024" : "512"
  memory                   = var.environment == "production" ? "2048" : "1024"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name  = "observability-service"
      image = "${aws_ecr_repository.services["observability-service"].repository_url}:latest"
      
      essential = true
      
      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        },
        {
          containerPort = 4317  # OTLP gRPC
          protocol      = "tcp"
        }
      ]
      
      environment = concat(local.common_env_vars, [
        {
          name  = "PORT"
          value = "8080"
        },
        {
          name  = "OTLP_PORT"
          value = "4317"
        },
        {
          name  = "DATABASE_HOST"
          value = aws_db_instance.main.address
        },
        {
          name  = "REDIS_HOST"
          value = aws_elasticache_cluster.main.cache_nodes[0].address
        },
        {
          name  = "KAFKA_BROKERS"
          value = aws_msk_cluster.main.bootstrap_brokers
        }
      ])
      
      secrets = [
        {
          name      = "DATABASE_PASSWORD"
          valueFrom = aws_secretsmanager_secret.db_password.arn
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_services.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "observability-service"
        }
      }
      
      healthCheck = {
        command     = ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 30
      }
    }
  ])

  tags = local.common_tags
}

# 3. AI Quality Service (Python/FastAPI)
resource "aws_ecs_task_definition" "ai_quality_service" {
  family                   = "${local.ecs_name}-ai-quality-service"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  cpu                      = var.environment == "production" ? "1024" : "512"
  memory                   = var.environment == "production" ? "2048" : "1024"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name  = "ai-quality-service"
      image = "${aws_ecr_repository.services["ai-quality-service"].repository_url}:latest"
      
      essential = true
      
      portMappings = [
        {
          containerPort = 8002
          protocol      = "tcp"
        }
      ]
      
      environment = concat(local.common_env_vars, [
        {
          name  = "PORT"
          value = "8002"
        },
        {
          name  = "DATABASE_HOST"
          value = aws_db_instance.main.address
        },
        {
          name  = "REDIS_HOST"
          value = aws_elasticache_cluster.main.cache_nodes[0].address
        },
        {
          name  = "MODEL_CACHE_DIR"
          value = "/tmp/models"
        }
      ])
      
      secrets = [
        {
          name      = "DATABASE_PASSWORD"
          valueFrom = aws_secretsmanager_secret.db_password.arn
        },
        {
          name      = "OPENAI_API_KEY"
          valueFrom = aws_secretsmanager_secret.openai_api_key.arn
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_services.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ai-quality-service"
        }
      }
      
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8002/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = local.common_tags
}

# 4. Optimization Service (Go)
resource "aws_ecs_task_definition" "optimization_service" {
  family                   = "${local.ecs_name}-optimization-service"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  cpu                      = var.environment == "production" ? "512" : "256"
  memory                   = var.environment == "production" ? "1024" : "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name  = "optimization-service"
      image = "${aws_ecr_repository.services["optimization-service"].repository_url}:latest"
      
      essential = true
      
      portMappings = [
        {
          containerPort = 8003
          protocol      = "tcp"
        }
      ]
      
      environment = concat(local.common_env_vars, [
        {
          name  = "PORT"
          value = "8003"
        },
        {
          name  = "DATABASE_HOST"
          value = aws_db_instance.main.address
        },
        {
          name  = "REDIS_HOST"
          value = aws_elasticache_cluster.main.cache_nodes[0].address
        },
        {
          name  = "CACHE_TTL"
          value = "3600"
        }
      ])
      
      secrets = [
        {
          name      = "DATABASE_PASSWORD"
          valueFrom = aws_secretsmanager_secret.db_password.arn
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_services.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "optimization-service"
        }
      }
      
      healthCheck = {
        command     = ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:8003/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 30
      }
    }
  ])

  tags = local.common_tags
}

# 5. API Gateway (Node.js/Express)
resource "aws_ecs_task_definition" "api_gateway" {
  family                   = "${local.ecs_name}-api-gateway"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  cpu                      = var.environment == "production" ? "512" : "256"
  memory                   = var.environment == "production" ? "1024" : "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name  = "api-gateway"
      image = "${aws_ecr_repository.services["api-gateway"].repository_url}:latest"
      
      essential = true
      
      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        }
      ]
      
      environment = concat(local.common_env_vars, [
        {
          name  = "PORT"
          value = "8080"
        },
        {
          name  = "NODE_ENV"
          value = var.environment
        },
        {
          name  = "USER_SERVICE_URL"
          value = "http://user-service.${var.environment}.diagnyx.local:8001"
        },
        {
          name  = "OBSERVABILITY_SERVICE_URL"
          value = "http://observability-service.${var.environment}.diagnyx.local:8080"
        },
        {
          name  = "AI_QUALITY_SERVICE_URL"
          value = "http://ai-quality-service.${var.environment}.diagnyx.local:8002"
        },
        {
          name  = "OPTIMIZATION_SERVICE_URL"
          value = "http://optimization-service.${var.environment}.diagnyx.local:8003"
        },
        {
          name  = "REDIS_HOST"
          value = aws_elasticache_cluster.main.cache_nodes[0].address
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
          "awslogs-stream-prefix" = "api-gateway"
        }
      }
      
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 30
      }
    }
  ])

  tags = local.common_tags
}

# 6. Dashboard Service (Next.js)
resource "aws_ecs_task_definition" "dashboard_service" {
  family                   = "${local.ecs_name}-dashboard-service"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  cpu                      = var.environment == "production" ? "512" : "256"
  memory                   = var.environment == "production" ? "1024" : "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name  = "dashboard-service"
      image = "${aws_ecr_repository.services["dashboard-service"].repository_url}:latest"
      
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
          value = "https://api.${var.domain_name}"
        },
        {
          name  = "NEXT_PUBLIC_ENVIRONMENT"
          value = var.environment
        }
      ])
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_services.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "dashboard-service"
        }
      }
      
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:3000/api/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = local.common_tags
}

# 7. Marketing UI (Next.js)
resource "aws_ecs_task_definition" "diagnyx_ui" {
  family                   = "${local.ecs_name}-diagnyx-ui"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  cpu                      = var.environment == "production" ? "256" : "256"
  memory                   = var.environment == "production" ? "512" : "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name  = "diagnyx-ui"
      image = "${aws_ecr_repository.services["diagnyx-ui"].repository_url}:latest"
      
      essential = true
      
      portMappings = [
        {
          containerPort = 3002
          protocol      = "tcp"
        }
      ]
      
      environment = concat(local.common_env_vars, [
        {
          name  = "PORT"
          value = "3002"
        },
        {
          name  = "NODE_ENV"
          value = var.environment
        },
        {
          name  = "NEXT_PUBLIC_APP_URL"
          value = "https://app.${var.domain_name}"
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
        command     = ["CMD-SHELL", "curl -f http://localhost:3002/ || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = local.common_tags
}