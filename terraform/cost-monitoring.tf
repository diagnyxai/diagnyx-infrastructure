# Cost Monitoring and Alerting Setup

# SNS Topic for Cost Alerts
resource "aws_sns_topic" "cost_alerts" {
  count = var.enable_monitoring ? 1 : 0
  
  name = "${local.name_prefix}-cost-alerts"
  
  tags = merge(
    local.common_tags,
    {
      Purpose = "cost-monitoring"
    }
  )
}

resource "aws_sns_topic_subscription" "cost_alerts_email" {
  count = var.enable_monitoring ? 1 : 0
  
  topic_arn = aws_sns_topic.cost_alerts[0].arn
  protocol  = "email"
  endpoint  = var.cost_alert_email != "" ? var.cost_alert_email : var.owner_email
}

# Budget Alerts
resource "aws_budgets_budget" "monthly_cost" {
  name              = "${local.name_prefix}-monthly-budget"
  budget_type       = "COST"
  limit_amount      = var.monthly_budget_limit
  limit_unit        = "USD"
  time_period_start = "2024-01-01_00:00"
  time_unit         = "MONTHLY"
  
  cost_filter {
    name = "TagKeyValue"
    values = [
      "Environment$${var.environment}"
    ]
  }
  
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 50
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_email_addresses = [var.cost_alert_email != "" ? var.cost_alert_email : var.owner_email]
  }
  
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_email_addresses = [var.cost_alert_email != "" ? var.cost_alert_email : var.owner_email]
    subscriber_sns_topic_arns  = var.enable_monitoring ? [aws_sns_topic.cost_alerts[0].arn] : []
  }
  
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_email_addresses = [var.cost_alert_email != "" ? var.cost_alert_email : var.owner_email]
    subscriber_sns_topic_arns  = var.enable_monitoring ? [aws_sns_topic.cost_alerts[0].arn] : []
  }
  
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 90
    threshold_type            = "PERCENTAGE"
    notification_type         = "FORECASTED"
    subscriber_email_addresses = [var.cost_alert_email != "" ? var.cost_alert_email : var.owner_email]
  }
}

# Service-specific budgets
resource "aws_budgets_budget" "service_budgets" {
  for_each = {
    EC2       = var.environment == "production" ? 1000 : 200
    RDS       = var.environment == "production" ? 500 : 100
    S3        = var.environment == "production" ? 200 : 50
    DataTransfer = var.environment == "production" ? 300 : 50
  }
  
  name              = "${local.name_prefix}-${lower(each.key)}-budget"
  budget_type       = "COST"
  limit_amount      = each.value
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  
  cost_filter {
    name = "Service"
    values = [
      each.key == "EC2" ? "Amazon Elastic Compute Cloud - Compute" :
      each.key == "RDS" ? "Amazon Relational Database Service" :
      each.key == "S3" ? "Amazon Simple Storage Service" :
      "AWSDataTransfer"
    ]
  }
  
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_email_addresses = [var.cost_alert_email != "" ? var.cost_alert_email : var.owner_email]
  }
}

# Cost Anomaly Detector
resource "aws_ce_anomaly_monitor" "main" {
  name              = "${local.name_prefix}-anomaly-monitor"
  monitor_type      = "DIMENSIONAL"
  monitor_dimension = "SERVICE"
}

resource "aws_ce_anomaly_subscription" "main" {
  name      = "${local.name_prefix}-anomaly-subscription"
  threshold = 100  # Alert on anomalies over $100
  frequency = "DAILY"
  
  monitor_arn_list = [aws_ce_anomaly_monitor.main.arn]
  
  subscriber {
    type    = "EMAIL"
    address = var.cost_alert_email != "" ? var.cost_alert_email : var.owner_email
  }
  
  dynamic "subscriber" {
    for_each = var.enable_monitoring ? [1] : []
    content {
      type    = "SNS"
      address = aws_sns_topic.cost_alerts[0].arn
    }
  }
}

# CloudWatch Dashboard for Cost Monitoring
resource "aws_cloudwatch_dashboard" "cost_optimization" {
  dashboard_name = "${local.name_prefix}-cost-optimization"
  
  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          title   = "Daily Costs by Service"
          metrics = [
            ["AWS/Billing", "EstimatedCharges", { stat = "Maximum", period = 86400 }]
          ]
          period = 86400
          stat   = "Maximum"
          region = "us-east-1"
          view   = "timeSeries"
        }
      },
      {
        type = "metric"
        properties = {
          title = "EC2 Instance Hours by Type"
          metrics = [
            ["AWS/EC2", "InstanceHours", { stat = "Sum", period = 3600 }]
          ]
          period = 3600
          stat   = "Sum"
          region = var.aws_region
          view   = "timeSeries"
        }
      },
      {
        type = "metric"
        properties = {
          title = "Spot vs On-Demand Usage"
          metrics = [
            ["AWS/EC2", "SpotInstanceRequests", { stat = "Average" }],
            [".", "OnDemandInstances", { stat = "Average" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          view   = "singleValue"
        }
      },
      {
        type = "metric"
        properties = {
          title = "NAT Gateway Data Transfer"
          metrics = [
            ["AWS/EC2", "NATGatewayBytesOutToDestination", { stat = "Sum" }],
            [".", "NATGatewayBytesInFromSource", { stat = "Sum" }]
          ]
          period = 3600
          stat   = "Sum"
          region = var.aws_region
          view   = "timeSeries"
        }
      },
      {
        type = "metric"
        properties = {
          title = "S3 Storage by Class"
          metrics = [
            ["AWS/S3", "BucketSizeBytes", { dimensions = { StorageType = "StandardStorage" } }],
            [".", ".", { dimensions = { StorageType = "StandardIAStorage" } }],
            [".", ".", { dimensions = { StorageType = "GlacierStorage" } }]
          ]
          period = 86400
          stat   = "Average"
          region = var.aws_region
          view   = "timeSeries"
        }
      }
    ]
  })
}

# Lambda for Cost Optimization Recommendations
resource "aws_lambda_function" "cost_optimizer" {
  filename         = data.archive_file.cost_optimizer.output_path
  function_name    = "${local.name_prefix}-cost-optimizer"
  role            = aws_iam_role.cost_optimizer.arn
  handler         = "index.handler"
  source_code_hash = data.archive_file.cost_optimizer.output_base64sha256
  runtime         = "python3.11"
  timeout         = 300  # 5 minutes for analysis
  
  environment {
    variables = {
      SNS_TOPIC_ARN = var.enable_monitoring ? aws_sns_topic.cost_alerts[0].arn : ""
      ENVIRONMENT   = var.environment
      THRESHOLD_UNDERUTILIZED = "30"  # CPU < 30% considered underutilized
      THRESHOLD_IDLE_DAYS     = "7"   # Resources idle for 7 days
    }
  }
  
  tags = merge(
    local.mandatory_tags,
    {
      Purpose = "cost-optimization-analysis"
    }
  )
}

# Cost Optimizer Lambda code
data "archive_file" "cost_optimizer" {
  type        = "zip"
  output_path = "${path.module}/lambda/cost-optimizer.zip"
  
  source {
    content  = file("${path.module}/lambda/cost_optimizer.py")
    filename = "index.py"
  }
}

# IAM Role for Cost Optimizer
resource "aws_iam_role" "cost_optimizer" {
  name = "${local.name_prefix}-cost-optimizer"
  
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
  
  tags = local.mandatory_tags
}

resource "aws_iam_role_policy" "cost_optimizer" {
  name = "${local.name_prefix}-cost-optimizer-policy"
  role = aws_iam_role.cost_optimizer.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ce:GetCostAndUsage",
          "ce:GetCostForecast",
          "ce:GetReservationUtilization",
          "ce:GetSavingsPlansUtilization",
          "ce:GetRightsizingRecommendation"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeVolumes",
          "ec2:DescribeSnapshots",
          "ec2:DescribeImages",
          "rds:DescribeDBInstances",
          "elasticache:DescribeCacheClusters",
          "cloudwatch:GetMetricStatistics"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = var.enable_monitoring ? aws_sns_topic.cost_alerts[0].arn : "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Schedule Cost Optimizer to run daily
resource "aws_cloudwatch_event_rule" "cost_optimizer_schedule" {
  name                = "${local.name_prefix}-cost-optimizer-schedule"
  description         = "Trigger cost optimization analysis daily"
  schedule_expression = "cron(0 8 * * ? *)"  # 8 AM UTC daily
  
  tags = local.mandatory_tags
}

resource "aws_cloudwatch_event_target" "cost_optimizer" {
  rule      = aws_cloudwatch_event_rule.cost_optimizer_schedule.name
  target_id = "CostOptimizerLambda"
  arn       = aws_lambda_function.cost_optimizer.arn
}

resource "aws_lambda_permission" "cost_optimizer" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cost_optimizer.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.cost_optimizer_schedule.arn
}

# Variables for Cost Monitoring
variable "monthly_budget_limit" {
  description = "Monthly budget limit in USD"
  type        = number
  default     = 2000  # Adjust based on environment
}

variable "cost_alert_email" {
  description = "Email address for cost alerts"
  type        = string
  default     = ""
}