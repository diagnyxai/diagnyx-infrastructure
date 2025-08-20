# Cost Optimization Resources
# Reserved Instance recommendations and cost anomaly detection

# Cost Anomaly Detection
resource "aws_ce_anomaly_detector" "service_monitor" {
  name           = "${local.name_prefix}-service-cost-anomaly"
  monitor_type   = "DIMENSIONAL"
  
  specification = jsonencode({
    Dimension = "SERVICE"
    MatchOptions = ["EQUALS"]
    Values = ["Amazon Elastic Compute Cloud - Compute", "Amazon Relational Database Service"]
  })

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-service-cost-anomaly"
    Type = "CostMonitoring"
  })
}

resource "aws_ce_anomaly_detector" "ec2_monitor" {
  name           = "${local.name_prefix}-ec2-cost-anomaly"
  monitor_type   = "DIMENSIONAL"
  
  specification = jsonencode({
    Dimension = "SERVICE"
    MatchOptions = ["EQUALS"]
    Values = ["Amazon Elastic Compute Cloud - Compute"]
  })

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ec2-cost-anomaly"
    Type = "CostMonitoring"
  })
}

# Cost Anomaly Subscription
resource "aws_ce_anomaly_subscription" "cost_alerts" {
  name      = "${local.name_prefix}-cost-anomaly-alerts"
  frequency = "DAILY"
  
  monitor_arn_list = [
    aws_ce_anomaly_detector.service_monitor.arn,
    aws_ce_anomaly_detector.ec2_monitor.arn
  ]
  
  subscriber {
    type    = "EMAIL"
    address = var.owner_email
  }

  threshold_expression {
    and {
      dimension {
        key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
        values        = ["100"]  # Alert when anomaly impact > $100
        match_options = ["GREATER_THAN_OR_EQUAL"]
      }
    }
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-cost-anomaly-subscription"
  })
}

# Budget for overall monthly spend - Environment-specific for MVP
resource "aws_budgets_budget" "monthly_cost" {
  name       = "${local.name_prefix}-monthly-budget"
  budget_type = "COST"
  # Environment-specific budgets for MVP
  limit_amount = var.environment == "production" ? "80" : (
    var.environment == "uat" ? "40" : "30"
  )
  limit_unit   = "USD"
  time_unit    = "MONTHLY"
  time_period_start = formatdate("YYYY-MM-01_00:00", timestamp())

  cost_filters {
    service = [
      "Amazon Elastic Compute Cloud - Compute",
      "Amazon Relational Database Service",
      "Amazon Virtual Private Cloud",
      "Amazon Elastic Container Service"
    ]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                 = 80
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_email_addresses = [var.owner_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                 = 100
    threshold_type            = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.owner_email]
  }

  depends_on = [aws_ce_anomaly_detector.service_monitor]
}

# Budget for EC2 instances specifically - Environment-specific for MVP
resource "aws_budgets_budget" "ec2_cost" {
  name       = "${local.name_prefix}-ec2-budget"
  budget_type = "COST"
  # Environment-specific EC2 budgets for MVP
  limit_amount = var.environment == "production" ? "50" : (
    var.environment == "uat" ? "25" : "15"
  )
  limit_unit   = "USD"
  time_unit    = "MONTHLY"
  time_period_start = formatdate("YYYY-MM-01_00:00", timestamp())

  cost_filters {
    service = ["Amazon Elastic Compute Cloud - Compute"]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                 = 90
    threshold_type            = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.owner_email]
  }
}

# CloudWatch Dashboard for Cost Monitoring
resource "aws_cloudwatch_dashboard" "cost_optimization" {
  dashboard_name = "${local.name_prefix}-cost-optimization"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", "InstanceId", "i-1234567890abcdef0"],
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "EC2 CPU Utilization"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", "${local.name_prefix}-alb"],
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "ALB Request Count"
          period  = 300
        }
      }
    ]
  })
}

# Reserved Instance Purchase Recommendations (via SNS notification)
resource "aws_sns_topic" "ri_recommendations" {
  name = "${local.name_prefix}-ri-recommendations"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ri-recommendations"
    Type = "CostOptimization"
  })
}

resource "aws_sns_topic_subscription" "ri_recommendations_email" {
  topic_arn = aws_sns_topic.ri_recommendations.arn
  protocol  = "email"
  endpoint  = var.owner_email
}

# Lambda function to check RI recommendations weekly
resource "aws_lambda_function" "ri_recommendations" {
  filename         = "ri_recommendations.zip"
  function_name    = "${local.name_prefix}-ri-recommendations"
  role            = aws_iam_role.ri_lambda_role.arn
  handler         = "index.handler"
  source_code_hash = data.archive_file.ri_lambda_zip.output_base64sha256
  runtime         = "python3.9"
  timeout         = 300

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.ri_recommendations.arn
      ENVIRONMENT   = var.environment
    }
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ri-recommendations-lambda"
  })
}

# Lambda function code
data "archive_file" "ri_lambda_zip" {
  type        = "zip"
  output_path = "ri_recommendations.zip"
  source {
    content = <<EOF
import boto3
import json
import os

def handler(event, context):
    ce_client = boto3.client('ce')
    sns_client = boto3.client('sns')
    
    try:
        # Get RI recommendations
        response = ce_client.get_rightsizing_recommendation(
            Service='EC2-Instance'
        )
        
        recommendations = response.get('RightsizingRecommendations', [])
        
        if recommendations:
            message = f"Found {len(recommendations)} Reserved Instance recommendations for {os.environ['ENVIRONMENT']}:\n\n"
            
            for rec in recommendations[:5]:  # Limit to first 5
                current_instance = rec.get('CurrentInstance', {})
                message += f"Instance: {current_instance.get('ResourceId', 'N/A')}\n"
                message += f"Current: {current_instance.get('InstanceType', 'N/A')}\n"
                
                modify_rec = rec.get('ModifyRecommendationDetail', {})
                if modify_rec:
                    target_instances = modify_rec.get('TargetInstances', [])
                    if target_instances:
                        message += f"Recommended: {target_instances[0].get('InstanceType', 'N/A')}\n"
                
                message += f"Estimated Monthly Savings: ${rec.get('EstimatedMonthlySavings', 'N/A')}\n\n"
            
            sns_client.publish(
                TopicArn=os.environ['SNS_TOPIC_ARN'],
                Subject=f'Reserved Instance Recommendations - {os.environ["ENVIRONMENT"]}',
                Message=message
            )
        
        return {
            'statusCode': 200,
            'body': json.dumps('RI recommendations checked successfully')
        }
        
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }
EOF
    filename = "index.py"
  }
}

# IAM role for Lambda function
resource "aws_iam_role" "ri_lambda_role" {
  name = "${local.name_prefix}-ri-lambda-role"

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

resource "aws_iam_role_policy" "ri_lambda_policy" {
  name = "${local.name_prefix}-ri-lambda-policy"
  role = aws_iam_role.ri_lambda_role.id

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
          "ce:GetRightsizingRecommendation",
          "ce:GetReservationPurchaseRecommendation"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.ri_recommendations.arn
      }
    ]
  })
}

# CloudWatch Event Rule to trigger Lambda weekly
resource "aws_cloudwatch_event_rule" "ri_recommendations_schedule" {
  name                = "${local.name_prefix}-ri-recommendations-schedule"
  description         = "Trigger RI recommendations check weekly"
  schedule_expression = "rate(7 days)"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ri-recommendations-schedule"
  })
}

resource "aws_cloudwatch_event_target" "ri_recommendations_target" {
  rule      = aws_cloudwatch_event_rule.ri_recommendations_schedule.name
  target_id = "RIRecommendationsLambdaTarget"
  arn       = aws_lambda_function.ri_recommendations.arn
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ri_recommendations.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ri_recommendations_schedule.arn
}