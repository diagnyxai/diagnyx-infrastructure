# Multi-Account Provider Configuration
# This file configures additional providers for cross-account deployment
# Note: Main provider configuration is in main.tf to avoid duplicates

# Provider for master account (billing, organizations)
provider "aws" {
  alias  = "master"
  region = var.aws_region
  
  # Only configure if master account variables are provided
  dynamic "assume_role" {
    for_each = var.master_account_id != "" ? [1] : []
    content {
      role_arn     = "arn:aws:iam::${var.master_account_id}:role/DiagnyxCrossAccountReadOnly"
      session_name = "terraform-diagnyx-master"
      external_id  = var.external_id
    }
  }
  
  default_tags {
    tags = merge(
      local.common_tags,
      {
        AccessedFrom = var.environment
      }
    )
  }
}

# Note: Kubernetes and Helm providers would be configured here if using EKS
# Currently using ECS for simplified architecture