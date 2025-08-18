# Scheduled Scaling for Cost Optimization
# Automatically scales down dev/staging environments during off-hours

# Lambda function for scaling operations
resource "aws_lambda_function" "scheduled_scaling" {
  count = var.enable_scheduled_scaling && var.environment != "production" ? 1 : 0
  
  filename         = data.archive_file.scaling_lambda[0].output_path
  function_name    = "${local.name_prefix}-scheduled-scaling"
  role            = aws_iam_role.scaling_lambda[0].arn
  handler         = "index.handler"
  source_code_hash = data.archive_file.scaling_lambda[0].output_base64sha256
  runtime         = "python3.11"
  timeout         = 60
  
  environment {
    variables = {
      CLUSTER_NAME     = module.eks.cluster_name
      ENVIRONMENT      = var.environment
      MIN_NODES_OFF    = "0"
      MIN_NODES_ON     = tostring(var.eks_node_group_min_size)
      DESIRED_NODES_OFF = "0"
      DESIRED_NODES_ON  = tostring(var.eks_node_group_desired_size)
    }
  }
  
  tags = merge(
    local.common_tags,
    {
      Purpose = "cost-optimization"
    }
  )
}

# Lambda execution role
resource "aws_iam_role" "scaling_lambda" {
  count = var.enable_scheduled_scaling && var.environment != "production" ? 1 : 0
  
  name = "${local.name_prefix}-scaling-lambda"
  
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
  
  tags = local.common_tags
}

# Lambda IAM policy
resource "aws_iam_role_policy" "scaling_lambda" {
  count = var.enable_scheduled_scaling && var.environment != "production" ? 1 : 0
  
  name = "${local.name_prefix}-scaling-lambda-policy"
  role = aws_iam_role.scaling_lambda[0].id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeNodegroup",
          "eks:UpdateNodegroupConfig",
          "eks:ListNodegroups"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "autoscaling:UpdateAutoScalingGroup",
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:SetDesiredCapacity"
        ]
        Resource = "*"
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

# Lambda function code
data "archive_file" "scaling_lambda" {
  count = var.enable_scheduled_scaling && var.environment != "production" ? 1 : 0
  
  type        = "zip"
  output_path = "${path.module}/lambda/scheduled-scaling.zip"
  
  source {
    content  = file("${path.module}/lambda/scheduled_scaling.py")
    filename = "index.py"
  }
}

# CloudWatch Event Rules for scheduling
resource "aws_cloudwatch_event_rule" "scale_down" {
  count = var.enable_scheduled_scaling && var.environment != "production" ? 1 : 0
  
  name                = "${local.name_prefix}-scale-down"
  description         = "Scale down ${var.environment} environment"
  schedule_expression = "cron(${var.scale_down_schedule})"
  
  tags = local.common_tags
}

resource "aws_cloudwatch_event_rule" "scale_up" {
  count = var.enable_scheduled_scaling && var.environment != "production" ? 1 : 0
  
  name                = "${local.name_prefix}-scale-up"
  description         = "Scale up ${var.environment} environment"
  schedule_expression = "cron(${var.scale_up_schedule})"
  
  tags = local.common_tags
}

# CloudWatch Event Targets
resource "aws_cloudwatch_event_target" "scale_down" {
  count = var.enable_scheduled_scaling && var.environment != "production" ? 1 : 0
  
  rule      = aws_cloudwatch_event_rule.scale_down[0].name
  target_id = "ScaleDownLambda"
  arn       = aws_lambda_function.scheduled_scaling[0].arn
  
  input = jsonencode({
    action = "scale_down"
  })
}

resource "aws_cloudwatch_event_target" "scale_up" {
  count = var.enable_scheduled_scaling && var.environment != "production" ? 1 : 0
  
  rule      = aws_cloudwatch_event_rule.scale_up[0].name
  target_id = "ScaleUpLambda"
  arn       = aws_lambda_function.scheduled_scaling[0].arn
  
  input = jsonencode({
    action = "scale_up"
  })
}

# Lambda permissions for CloudWatch Events
resource "aws_lambda_permission" "scale_down" {
  count = var.enable_scheduled_scaling && var.environment != "production" ? 1 : 0
  
  statement_id  = "AllowExecutionFromCloudWatchScaleDown"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scheduled_scaling[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.scale_down[0].arn
}

resource "aws_lambda_permission" "scale_up" {
  count = var.enable_scheduled_scaling && var.environment != "production" ? 1 : 0
  
  statement_id  = "AllowExecutionFromCloudWatchScaleUp"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scheduled_scaling[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.scale_up[0].arn
}

# RDS Scheduled Actions for cost optimization
resource "aws_db_instance_automated_backups_replication" "scheduled_stop" {
  count = var.enable_scheduled_scaling && var.environment != "production" ? 1 : 0
  
  source_db_instance_arn = aws_db_instance.main[0].arn
  
  lifecycle {
    ignore_changes = [source_db_instance_arn]
  }
}

# CloudWatch Dashboard for monitoring scaling events
resource "aws_cloudwatch_dashboard" "scaling_monitoring" {
  count = var.enable_scheduled_scaling && var.environment != "production" ? 1 : 0
  
  dashboard_name = "${local.name_prefix}-scaling-monitor"
  
  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/EKS", "node_count", { stat = "Average" }],
            ["AWS/Lambda", "Invocations", { stat = "Sum" }],
            ["AWS/Lambda", "Errors", { stat = "Sum" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "Scheduled Scaling Metrics"
        }
      },
      {
        type = "log"
        properties = {
          query   = "SOURCE '/aws/lambda/${local.name_prefix}-scheduled-scaling'"
          region  = var.aws_region
          title   = "Scaling Lambda Logs"
        }
      }
    ]
  })
}