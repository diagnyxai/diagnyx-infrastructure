# ECS Cluster Module - Basic placeholder

resource "aws_ecs_cluster" "main" {
  name = "diagnyx-${var.environment}"

  setting {
    name  = "containerInsights"
    value = var.environment == "production" ? "enabled" : "disabled"
  }

  tags = merge(var.common_tags, {
    Name = "diagnyx-${var.environment}-cluster"
    Type = "ECS"
  })
}

# ECS Cluster Capacity Providers (placeholder)
resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = var.environment == "production" ? "FARGATE" : "FARGATE_SPOT"
  }
}