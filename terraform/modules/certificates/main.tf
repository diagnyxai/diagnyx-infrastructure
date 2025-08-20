# SSL Certificate Management Module
# This module manages SSL/TLS certificates using AWS Certificate Manager (ACM)

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Data source for existing Route53 hosted zone
data "aws_route53_zone" "main" {
  count        = var.domain_name != "" ? 1 : 0
  name         = var.domain_name
  private_zone = false
}

# Primary SSL certificate for the domain
resource "aws_acm_certificate" "main" {
  count             = var.domain_name != "" ? 1 : 0
  domain_name       = var.domain_name
  validation_method = "DNS"
  
  subject_alternative_names = var.subject_alternative_names
  
  lifecycle {
    create_before_destroy = true
  }
  
  tags = merge(var.tags, {
    Name        = "${var.environment}-ssl-certificate"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Purpose     = "SSL/TLS certificate for Diagnyx platform"
  })
}

# DNS validation records for certificate
resource "aws_route53_record" "cert_validation" {
  for_each = var.domain_name != "" ? {
    for dvo in aws_acm_certificate.main[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}
  
  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.main[0].zone_id
}

# Certificate validation
resource "aws_acm_certificate_validation" "main" {
  count           = var.domain_name != "" ? 1 : 0
  certificate_arn = aws_acm_certificate.main[0].arn
  validation_record_fqdns = [
    for record in aws_route53_record.cert_validation : record.fqdn
  ]
  
  timeouts {
    create = "5m"
  }
}

# CloudWatch log group for certificate renewal monitoring
resource "aws_cloudwatch_log_group" "cert_renewal" {
  count             = var.enable_monitoring ? 1 : 0
  name              = "/aws/lambda/cert-renewal-monitor-${var.environment}"
  retention_in_days = var.log_retention_days
  
  tags = merge(var.tags, {
    Name        = "${var.environment}-cert-renewal-logs"
    Environment = var.environment
    Purpose     = "Certificate renewal monitoring logs"
  })
}

# Lambda function for certificate expiry monitoring
resource "aws_lambda_function" "cert_monitor" {
  count         = var.enable_monitoring ? 1 : 0
  filename      = data.archive_file.cert_monitor_zip[0].output_path
  function_name = "cert-renewal-monitor-${var.environment}"
  role          = aws_iam_role.cert_monitor_role[0].arn
  handler       = "index.handler"
  runtime       = "python3.11"
  timeout       = 60
  
  source_code_hash = data.archive_file.cert_monitor_zip[0].output_base64sha256
  
  environment {
    variables = {
      CERTIFICATE_ARN = var.domain_name != "" ? aws_acm_certificate.main[0].arn : ""
      SNS_TOPIC_ARN   = var.notification_topic_arn
      ENVIRONMENT     = var.environment
    }
  }
  
  tags = merge(var.tags, {
    Name        = "${var.environment}-cert-monitor"
    Environment = var.environment
    Purpose     = "Monitor certificate expiry"
  })
}

# Certificate monitoring Lambda code
data "archive_file" "cert_monitor_zip" {
  count       = var.enable_monitoring ? 1 : 0
  type        = "zip"
  output_path = "${path.module}/cert_monitor.zip"
  
  source {
    content = templatefile("${path.module}/cert_monitor.py", {
      environment = var.environment
    })
    filename = "index.py"
  }
}

# IAM role for certificate monitoring Lambda
resource "aws_iam_role" "cert_monitor_role" {
  count = var.enable_monitoring ? 1 : 0
  name  = "cert-monitor-role-${var.environment}"
  
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
  
  tags = merge(var.tags, {
    Name        = "${var.environment}-cert-monitor-role"
    Environment = var.environment
  })
}

# IAM policy for certificate monitoring
resource "aws_iam_role_policy" "cert_monitor_policy" {
  count = var.enable_monitoring ? 1 : 0
  name  = "cert-monitor-policy-${var.environment}"
  role  = aws_iam_role.cert_monitor_role[0].id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "acm:DescribeCertificate",
          "acm:ListCertificates"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = var.notification_topic_arn
      }
    ]
  })
}

# EventBridge rule to trigger certificate monitoring weekly
resource "aws_cloudwatch_event_rule" "cert_monitor_schedule" {
  count               = var.enable_monitoring ? 1 : 0
  name                = "cert-monitor-schedule-${var.environment}"
  description         = "Trigger certificate expiry monitoring weekly"
  schedule_expression = "cron(0 8 ? * MON *)" # Every Monday at 8 AM UTC
  
  tags = merge(var.tags, {
    Name        = "${var.environment}-cert-monitor-schedule"
    Environment = var.environment
  })
}

# EventBridge target for certificate monitoring
resource "aws_cloudwatch_event_target" "cert_monitor_target" {
  count     = var.enable_monitoring ? 1 : 0
  rule      = aws_cloudwatch_event_rule.cert_monitor_schedule[0].name
  target_id = "CertMonitorTarget"
  arn       = aws_lambda_function.cert_monitor[0].arn
}

# Lambda permission for EventBridge
resource "aws_lambda_permission" "allow_eventbridge" {
  count         = var.enable_monitoring ? 1 : 0
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cert_monitor[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.cert_monitor_schedule[0].arn
}