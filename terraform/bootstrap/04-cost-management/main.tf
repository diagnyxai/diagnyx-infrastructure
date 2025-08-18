# Cost Management - Simple Budget Setup
terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  backend "s3" {}
}

provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = {
      Project   = "Diagnyx"
      Component = "CostManagement"
      ManagedBy = "Terraform"
    }
  }
}

# Master Account Budget
resource "aws_budgets_budget" "master" {
  name              = "diagnyx-master-budget"
  budget_type       = "COST"
  limit_amount      = "150"
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_email_addresses = ["admin@diagnyx.com"]
  }
}

# Total Organization Budget
resource "aws_budgets_budget" "total" {
  name              = "diagnyx-total-organization-budget"
  budget_type       = "COST"
  limit_amount      = "175"  # $25*5 + $50 = $175 total
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 50
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_email_addresses = ["admin@diagnyx.com"]
  }
  
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_email_addresses = ["admin@diagnyx.com"]
  }
  
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type            = "PERCENTAGE"
    notification_type         = "FORECASTED"
    subscriber_email_addresses = ["admin@diagnyx.com"]
  }
}

output "budget_names" {
  value = {
    master = aws_budgets_budget.master.name
    total  = aws_budgets_budget.total.name
  }
  description = "Budget names created"
}