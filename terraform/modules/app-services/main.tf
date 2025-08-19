# Application Services Module - Basic placeholder
# This module will contain ECS services for the applications

# Security Group for ECS Services
resource "aws_security_group" "ecs_services" {
  name_prefix = "diagnyx-${var.environment}-ecs-services"
  vpc_id      = var.vpc_id
  description = "Security group for ECS services"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP traffic"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS traffic"
  }

  ingress {
    from_port   = 8080
    to_port     = 8090
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.main.cidr_block]
    description = "Application ports"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(var.common_tags, {
    Name = "diagnyx-${var.environment}-ecs-services-sg"
    Type = "SecurityGroup"
  })
}

# Data source for VPC
data "aws_vpc" "main" {
  id = var.vpc_id
}

# Application Load Balancer (placeholder)
resource "aws_lb" "main" {
  name               = "diagnyx-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ecs_services.id]
  subnets            = var.private_subnets

  enable_deletion_protection = var.environment == "production"

  tags = merge(var.common_tags, {
    Name = "diagnyx-${var.environment}-alb"
    Type = "LoadBalancer"
  })
}

# Target Group (placeholder)
resource "aws_lb_target_group" "main" {
  name     = "diagnyx-${var.environment}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = merge(var.common_tags, {
    Name = "diagnyx-${var.environment}-tg"
    Type = "TargetGroup"
  })
}