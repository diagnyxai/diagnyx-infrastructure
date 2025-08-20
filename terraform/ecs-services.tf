# ECS Services with Auto-Scaling - Simplified Platform

locals {
  # Service scaling configurations - Simplified platform
  service_scaling = {
    user_service = {
      min_capacity = (var.environment == "production" || var.environment == "uat") ? 1 : 0
      max_capacity = var.environment == "production" ? 3 : (var.environment == "uat" ? 2 : 1)
      target_cpu   = 70
      target_memory = 80
    }
    diagnyx_api_gateway = {
      min_capacity = (var.environment == "production" || var.environment == "uat") ? 1 : 0
      max_capacity = var.environment == "production" ? 3 : (var.environment == "uat" ? 2 : 1)
      target_cpu   = 60
      target_memory = 70
    }
    diagnyx_ui = {
      min_capacity = (var.environment == "production" || var.environment == "uat") ? 1 : 0
      max_capacity = var.environment == "production" ? 2 : (var.environment == "uat" ? 1 : 1)
      target_cpu   = 70
      target_memory = 80
    }
  }
}

# 1. User Service
resource "aws_ecs_service" "user_service" {
  name            = "user-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.user_service.arn
  desired_count   = local.service_scaling.user_service.min_capacity
  launch_type     = "EC2"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_services.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.user_service.arn
    container_name   = "user-service"
    container_port   = 8080
  }

  service_registries {
    registry_arn = aws_service_discovery_service.user_service.arn
  }

  deployment_configuration {
    maximum_percent         = 200
    minimum_healthy_percent = 100
    deployment_circuit_breaker {
      enable   = true
      rollback = true
    }
  }

  depends_on = [
    aws_lb_listener.api,
    aws_iam_role_policy.ecs_task_execution_additional
  ]

  tags = local.common_tags
}

# 2. API Gateway Service  
resource "aws_ecs_service" "diagnyx_api_gateway" {
  name            = "diagnyx-api-gateway"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.diagnyx_api_gateway.arn
  desired_count   = local.service_scaling.diagnyx_api_gateway.min_capacity
  launch_type     = "EC2"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_services.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.diagnyx_api_gateway.arn
    container_name   = "diagnyx-api-gateway"
    container_port   = 8443
  }

  service_registries {
    registry_arn = aws_service_discovery_service.diagnyx_api_gateway.arn
  }

  deployment_configuration {
    maximum_percent         = 200
    minimum_healthy_percent = 100
    deployment_circuit_breaker {
      enable   = true
      rollback = true
    }
  }

  depends_on = [
    aws_lb_listener.api,
    aws_iam_role_policy.ecs_task_execution_additional
  ]

  tags = local.common_tags
}

# 3. UI Service
resource "aws_ecs_service" "diagnyx_ui" {
  name            = "diagnyx-ui"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.diagnyx_ui.arn
  desired_count   = local.service_scaling.diagnyx_ui.min_capacity
  launch_type     = "EC2"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_services.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.diagnyx_ui.arn
    container_name   = "diagnyx-ui"
    container_port   = 3000
  }

  service_registries {
    registry_arn = aws_service_discovery_service.diagnyx_ui.arn
  }

  deployment_configuration {
    maximum_percent         = 200
    minimum_healthy_percent = 100
    deployment_circuit_breaker {
      enable   = true
      rollback = true
    }
  }

  depends_on = [
    aws_lb_listener.web,
    aws_iam_role_policy.ecs_task_execution_additional
  ]

  tags = local.common_tags
}

# ===================================
# Service Discovery Services
# ===================================

resource "aws_service_discovery_service" "user_service" {
  name = "user-service"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_grace_period_seconds = 30
}

resource "aws_service_discovery_service" "diagnyx_api_gateway" {
  name = "diagnyx-api-gateway"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_grace_period_seconds = 30
}

resource "aws_service_discovery_service" "diagnyx_ui" {
  name = "diagnyx-ui"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_grace_period_seconds = 30
}

# Note: Load balancer target groups are defined in ecs-alb.tf
# This avoids duplicate resource definitions