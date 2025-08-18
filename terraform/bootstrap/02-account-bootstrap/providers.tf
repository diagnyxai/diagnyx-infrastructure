# Provider Configuration for Account Bootstrap - us-east-1 only

terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  backend "s3" {
    bucket         = "diagnyx-terraform-state"
    key            = "bootstrap/account/terraform.tfstate"
    region         = "us-east-1"  # Always use us-east-1
    encrypt        = true
    dynamodb_table = "diagnyx-terraform-locks"
  }
}

provider "aws" {
  region = "us-east-1"  # All resources in us-east-1
  
  # Assume role if provided
  dynamic "assume_role" {
    for_each = var.assume_role_arn != "" ? [1] : []
    content {
      role_arn     = var.assume_role_arn
      session_name = "terraform-account-bootstrap"
      external_id  = var.external_id
    }
  }
  
  default_tags {
    tags = {
      Project     = "Diagnyx"
      Environment = var.environment
      Component   = "Bootstrap"
      ManagedBy   = "Terraform"
      Region      = "us-east-1"
    }
  }
}

# Variables
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "assume_role_arn" {
  description = "IAM role to assume for deployment"
  type        = string
  default     = ""
}

variable "external_id" {
  description = "External ID for role assumption"
  type        = string
  default     = "diagnyx-bootstrap-2024"
}

# Data sources
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# Ensure we're in us-east-1
resource "null_resource" "region_check" {
  triggers = {
    region = data.aws_region.current.name
  }
  
  lifecycle {
    precondition {
      condition     = data.aws_region.current.name == "us-east-1"
      error_message = "Account bootstrap must be deployed in us-east-1 region."
    }
  }
}

# Common locals
locals {
  common_tags = {
    Project     = "Diagnyx"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Component   = "AccountBootstrap"
    Region      = "us-east-1"
  }
}