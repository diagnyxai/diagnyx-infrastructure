# ECS Services with Auto-Scaling

locals {
  # Service scaling configurations - Starting with 1 instance for ALL environments
  service_scaling = {
    user_service = {
      min_capacity = 1  # Always start with 1 instance
      max_capacity = var.environment == "production" ? 3 : 2
      target_cpu   = 70
      target_memory = 80
    }
    observability_service = {
      min_capacity = 1
      max_capacity = var.environment == "production" ? 3 : 2
      target_cpu   = 60
      target_memory = 70
    }
    ai_quality_service = {
      min_capacity = 1
      max_capacity = var.environment == "production" ? 3 : 2
      target_cpu   = 70
      target_memory = 75
    }
    optimization_service = {
      min_capacity = 1
      max_capacity = var.environment == "production" ? 3 : 2
      target_cpu   = 70
      target_memory = 80
    }
    api_gateway = {
      min_capacity = 1
      max_capacity = var.environment == "production" ? 3 : 2
      target_cpu   = 60
      target_memory = 70
    }
    dashboard_service = {
      min_capacity = 1
      max_capacity = var.environment == "production" ? 3 : 2
      target_cpu   = 70
      target_memory = 80
    }
    diagnyx_ui = {
      min_capacity = 1
      max_capacity = var.environment == "production" ? 2 : 1
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
    container_port   = 8001
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

# 2. Observability Service
resource "aws_ecs_service" "observability_service" {
  name            = "observability-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.observability_service.arn
  desired_count   = local.service_scaling.observability_service.min_capacity
  launch_type     = "EC2"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_services.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.observability_service.arn
    container_name   = "observability-service"
    container_port   = 8080
  }

  service_registries {
    registry_arn = aws_service_discovery_service.observability_service.arn
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

# 3. AI Quality Service
resource "aws_ecs_service" "ai_quality_service" {
  name            = "ai-quality-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.ai_quality_service.arn
  desired_count   = local.service_scaling.ai_quality_service.min_capacity
  launch_type     = "EC2"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_services.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ai_quality_service.arn
    container_name   = "ai-quality-service"
    container_port   = 8002
  }

  service_registries {
    registry_arn = aws_service_discovery_service.ai_quality_service.arn
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

# 4. Optimization Service
resource "aws_ecs_service" "optimization_service" {
  name            = "optimization-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.optimization_service.arn
  desired_count   = local.service_scaling.optimization_service.min_capacity
  launch_type     = "EC2"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_services.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.optimization_service.arn
    container_name   = "optimization-service"
    container_port   = 8003
  }

  service_registries {
    registry_arn = aws_service_discovery_service.optimization_service.arn
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

# 5. API Gateway Service
resource "aws_ecs_service" "api_gateway" {
  name            = "api-gateway"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api_gateway.arn
  desired_count   = local.service_scaling.api_gateway.min_capacity
  launch_type     = "EC2"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_services.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api_gateway.arn
    container_name   = "api-gateway"
    container_port   = 8080
  }

  service_registries {
    registry_arn = aws_service_discovery_service.api_gateway.arn
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

# 6. Dashboard Service
resource "aws_ecs_service" "dashboard_service" {
  name            = "dashboard-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.dashboard_service.arn
  desired_count   = local.service_scaling.dashboard_service.min_capacity
  launch_type     = "EC2"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_services.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.dashboard_service.arn
    container_name   = "dashboard-service"
    container_port   = 3000
  }

  service_registries {
    registry_arn = aws_service_discovery_service.dashboard_service.arn
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

# 7. Marketing UI Service
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
    container_port   = 3002
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

# Service Discovery for internal communication
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

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_service_discovery_service" "observability_service" {
  name = "observability-service"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id
    
    dns_records {
      ttl  = 10
      type = "A"
    }
    
    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_service_discovery_service" "ai_quality_service" {
  name = "ai-quality-service"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id
    
    dns_records {
      ttl  = 10
      type = "A"
    }
    
    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_service_discovery_service" "optimization_service" {
  name = "optimization-service"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id
    
    dns_records {
      ttl  = 10
      type = "A"
    }
    
    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_service_discovery_service" "api_gateway" {
  name = "api-gateway"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id
    
    dns_records {
      ttl  = 10
      type = "A"
    }
    
    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_service_discovery_service" "dashboard_service" {
  name = "dashboard-service"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id
    
    dns_records {
      ttl  = 10
      type = "A"
    }
    
    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
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

  health_check_custom_config {
    failure_threshold = 1
  }
}

# Security Group for ECS Services
resource "aws_security_group" "ecs_services" {
  name        = "${local.ecs_name}-services"
  description = "Security group for ECS services"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Allow from ALB"
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description = "Allow internal communication"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.ecs_name}-services"
    }
  )
}