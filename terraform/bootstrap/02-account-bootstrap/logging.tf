# CloudWatch Log Groups - Pre-created with retention policies
# Cost: ~$1.00/month when populated (currently $0 when empty)
# Purpose: Standardized logging structure with cost-optimized retention

locals {
  # Log group configurations with retention policies
  log_groups = {
    # ECS Service logs
    "/ecs/diagnyx/${var.environment}/services" = {
      retention_days = var.environment == "production" ? 30 : 7
      description    = "ECS service logs"
    }
    
    # Application trace logs
    "/application/diagnyx/${var.environment}/traces" = {
      retention_days = var.environment == "production" ? 14 : 3
      description    = "Application trace logs"
    }
    
    # Metrics and monitoring
    "/application/diagnyx/${var.environment}/metrics" = {
      retention_days = var.environment == "production" ? 30 : 7
      description    = "Application metrics"
    }
    
    # AI quality evaluations
    "/application/diagnyx/${var.environment}/evaluations" = {
      retention_days = var.environment == "production" ? 30 : 7
      description    = "AI quality evaluation results"
    }
    
    # Lambda function logs
    "/aws/lambda/diagnyx-${var.environment}" = {
      retention_days = var.environment == "production" ? 14 : 3
      description    = "Lambda function logs"
    }
    
    # RDS logs
    "/aws/rds/diagnyx-${var.environment}" = {
      retention_days = var.environment == "production" ? 7 : 3
      description    = "RDS database logs"
    }
    
    # API Gateway logs
    "/aws/apigateway/diagnyx-${var.environment}" = {
      retention_days = var.environment == "production" ? 14 : 7
      description    = "API Gateway access logs"
    }
    
    # ALB access logs processor
    "/aws/lambda/alb-logs-processor-${var.environment}" = {
      retention_days = var.environment == "production" ? 7 : 3
      description    = "ALB logs processor Lambda"
    }
    
    # Cost optimization Lambda
    "/aws/lambda/cost-optimizer-${var.environment}" = {
      retention_days = 7
      description    = "Cost optimization automation logs"
    }
    
    # Security audit logs
    "/security/diagnyx/${var.environment}/audit" = {
      retention_days = var.environment == "production" ? 90 : 30
      description    = "Security audit logs"
    }
  }
}

# Create CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "application_logs" {
  for_each = local.log_groups
  
  name              = each.key
  retention_in_days = each.value.retention_days
  
  kms_key_id = aws_kms_key.logs.arn
  
  tags = merge(
    local.common_tags,
    {
      Description = each.value.description
      Retention   = "${each.value.retention_days} days"
    }
  )
}

# KMS key for log encryption
resource "aws_kms_key" "logs" {
  description             = "KMS key for CloudWatch Logs encryption in ${var.environment}"
  deletion_window_in_days = var.environment == "production" ? 30 : 7
  enable_key_rotation     = true
  
  tags = merge(
    local.common_tags,
    {
      Name = "diagnyx-${var.environment}-logs-key"
    }
  )
}

resource "aws_kms_alias" "logs" {
  name          = "alias/diagnyx-${var.environment}-logs"
  target_key_id = aws_kms_key.logs.key_id
}

# CloudWatch Log Insights queries for common tasks
resource "aws_cloudwatch_query_definition" "common_queries" {
  for_each = {
    errors = {
      name  = "Diagnyx-${var.environment}-Errors"
      query = <<-EOT
        fields @timestamp, @message
        | filter @message like /ERROR/
        | sort @timestamp desc
        | limit 100
      EOT
    }
    
    slow_requests = {
      name  = "Diagnyx-${var.environment}-SlowRequests"
      query = <<-EOT
        fields @timestamp, duration, @message
        | filter duration > 1000
        | sort duration desc
        | limit 50
      EOT
    }
    
    cost_analysis = {
      name  = "Diagnyx-${var.environment}-CostAnalysis"
      query = <<-EOT
        fields @timestamp, service, cost, @message
        | filter @message like /COST/
        | stats sum(cost) by service
      EOT
    }
    
    security_events = {
      name  = "Diagnyx-${var.environment}-SecurityEvents"
      query = <<-EOT
        fields @timestamp, eventType, userIdentity.principalId, @message
        | filter eventType like /Security/
        | sort @timestamp desc
        | limit 100
      EOT
    }
  }
  
  name = each.value.name
  
  log_group_names = [
    for lg in aws_cloudwatch_log_group.application_logs : lg.name
  ]
  
  query_string = each.value.query
}

# CloudWatch Log Metric Filters for alerting
resource "aws_cloudwatch_log_metric_filter" "error_count" {
  name           = "diagnyx-${var.environment}-error-count"
  pattern        = "[ERROR]"
  log_group_name = aws_cloudwatch_log_group.application_logs["/application/diagnyx/${var.environment}/traces"].name
  
  metric_transformation {
    name      = "ErrorCount"
    namespace = "Diagnyx/${var.environment}"
    value     = "1"
    unit      = "Count"
  }
}

resource "aws_cloudwatch_log_metric_filter" "slow_requests" {
  name           = "diagnyx-${var.environment}-slow-requests"
  pattern        = "[duration > 1000]"
  log_group_name = aws_cloudwatch_log_group.application_logs["/application/diagnyx/${var.environment}/metrics"].name
  
  metric_transformation {
    name      = "SlowRequests"
    namespace = "Diagnyx/${var.environment}"
    value     = "1"
    unit      = "Count"
  }
}

# Log Group Outputs
output "log_group_names" {
  value = {
    for k, v in aws_cloudwatch_log_group.application_logs : k => v.name
  }
  description = "Names of all created log groups"
}

output "log_group_arns" {
  value = {
    for k, v in aws_cloudwatch_log_group.application_logs : k => v.arn
  }
  description = "ARNs of all created log groups"
}

output "logs_kms_key_id" {
  value       = aws_kms_key.logs.id
  description = "KMS key ID for log encryption"
}