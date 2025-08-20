# Application Load Balancer configuration for ECS services

# ALB for all services
resource "aws_lb" "main" {
  name               = "${local.ecs_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets           = aws_subnet.public[*].id

  enable_deletion_protection = var.environment == "production"
  enable_http2              = true
  enable_cross_zone_load_balancing = true

  access_logs {
    bucket  = aws_s3_bucket.alb_logs.bucket
    prefix  = "alb"
    enabled = true
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.ecs_name}-alb"
    }
  )
}

# S3 bucket for ALB logs
resource "aws_s3_bucket" "alb_logs" {
  bucket = "${local.ecs_name}-alb-logs-${data.aws_caller_identity.current.account_id}"

  tags = merge(
    local.common_tags,
    {
      Name = "${local.ecs_name}-alb-logs"
    }
  )
}

resource "aws_s3_bucket_public_access_block" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::127311923021:root"  # AWS ALB service account for us-east-1
        }
        Action = "s3:PutObject"
        Resource = "${aws_s3_bucket.alb_logs.arn}/*"
      }
    ]
  })
}

# ALB Security Group
resource "aws_security_group" "alb" {
  name        = "${local.ecs_name}-alb"
  description = "Security group for Application Load Balancer"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from Internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.ecs_name}-alb"
    }
  )
}

# HTTP Listener (redirects to HTTPS)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# HTTPS Listener for Web Services
resource "aws_lb_listener" "web" {
  count             = var.domain_name != "" ? 1 : 0
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"  # Updated to latest TLS 1.3 policy
  certificate_arn   = module.certificates.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.diagnyx_ui.arn
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.ecs_name}-web-https-listener"
    }
  )
}

# HTTPS Listener for API Services
resource "aws_lb_listener" "api" {
  count             = var.domain_name != "" ? 1 : 0
  load_balancer_arn = aws_lb.main.arn
  port              = "8443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"  # Updated to latest TLS 1.3 policy
  certificate_arn   = module.certificates.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.diagnyx_api_gateway.arn
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.ecs_name}-api-https-listener"
    }
  )
}

# Target Groups for each service

# 1. User Service Target Group
resource "aws_lb_target_group" "user_service" {
  name                 = "${local.ecs_name}-user-service"
  port                 = 8001
  protocol             = "HTTP"
  vpc_id               = module.vpc.vpc_id
  target_type          = "ip"
  deregistration_delay = 30

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/health"
    matcher             = "200"
  }

  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
    enabled         = true
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.ecs_name}-user-service"
    }
  )
}

# 2. API Gateway Target Group
resource "aws_lb_target_group" "diagnyx_api_gateway" {
  name                 = "${local.ecs_name}-api-gateway"
  port                 = 8443
  protocol             = "HTTP"
  vpc_id               = module.vpc.vpc_id
  target_type          = "ip"
  deregistration_delay = 30

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/health"
    matcher             = "200"
  }

  stickiness {
    type            = "lb_cookie"
    cookie_duration = 3600
    enabled         = true
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.ecs_name}-api-gateway"
    }
  )
}

# 3. Marketing UI Target Group
resource "aws_lb_target_group" "diagnyx_ui" {
  name                 = "${local.ecs_name}-ui"
  port                 = 3002
  protocol             = "HTTP"
  vpc_id               = module.vpc.vpc_id
  target_type          = "ip"
  deregistration_delay = 30

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/"
    matcher             = "200"
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.ecs_name}-ui"
    }
  )
}

# Path-based routing rules

# API Gateway routing (all API traffic)
resource "aws_lb_listener_rule" "api_gateway" {
  listener_arn = aws_lb_listener.api.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.diagnyx_api_gateway.arn
  }

  condition {
    path_pattern {
      values = ["/api/v1/*"]
    }
  }
}

# Direct user service routing (auth endpoints)
resource "aws_lb_listener_rule" "user_service_direct" {
  count        = var.domain_name != "" ? 1 : 0
  listener_arn = aws_lb_listener.api[0].arn
  priority     = 110

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.user_service.arn
  }

  condition {
    path_pattern {
      values = ["/api/v1/auth/*", "/api/v1/users/*"]
    }
  }
}

# Marketing site routing (default)
resource "aws_lb_listener_rule" "marketing" {
  count        = var.domain_name != "" ? 1 : 0
  listener_arn = aws_lb_listener.web[0].arn
  priority     = 200

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.diagnyx_ui.arn
  }

  condition {
    host_header {
      values = ["${var.domain_name}", "www.${var.domain_name}"]
    }
  }
}

# SSL Certificate management moved to modules/certificates
# The certificate is now managed by the certificate module in main.tf

# Route53 Zone (if not exists)
resource "aws_route53_zone" "main" {
  name = var.domain_name

  tags = merge(
    local.common_tags,
    {
      Name = var.domain_name
    }
  )
}

# Route53 A records pointing to ALB
resource "aws_route53_record" "main" {
  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "app" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "app.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "api" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "api.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}

# Variables needed
variable "domain_name" {
  description = "Domain name for the application"
  type        = string
  default     = "diagnyx.ai"  # Replace with your domain
}

# Outputs
output "alb_dns_name" {
  value       = aws_lb.main.dns_name
  description = "DNS name of the Application Load Balancer"
}

output "alb_zone_id" {
  value       = aws_lb.main.zone_id
  description = "Zone ID of the Application Load Balancer"
}

output "app_url" {
  value       = "https://app.${var.domain_name}"
  description = "URL for the application dashboard"
}

output "api_url" {
  value       = "https://api.${var.domain_name}"
  description = "URL for the API"
}

output "website_url" {
  value       = "https://${var.domain_name}"
  description = "URL for the marketing website"
}