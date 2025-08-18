# Provider Configuration for Shared Services - us-east-1 only

terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  backend "s3" {
    bucket         = "diagnyx-terraform-shared-state"
    key            = "bootstrap/shared-services/terraform.tfstate"
    region         = "us-east-1"  # Always use us-east-1
    encrypt        = true
    dynamodb_table = "diagnyx-terraform-shared-locks"
  }
}

provider "aws" {
  region = "us-east-1"  # All resources in us-east-1
  
  # Assume role in shared services account
  dynamic "assume_role" {
    for_each = var.assume_role_arn != "" ? [1] : []
    content {
      role_arn     = var.assume_role_arn
      session_name = "terraform-shared-services"
      external_id  = var.external_id
    }
  }
  
  default_tags {
    tags = {
      Project     = "Diagnyx"
      Environment = "shared"
      Component   = "SharedServices"
      ManagedBy   = "Terraform"
      Region      = "us-east-1"
    }
  }
}

# Variables
variable "assume_role_arn" {
  description = "IAM role to assume for deployment"
  type        = string
  default     = ""
}

variable "external_id" {
  description = "External ID for role assumption"
  type        = string
  default     = "diagnyx-shared-2024"
}

variable "master_account_id" {
  description = "Master account ID"
  type        = string
}

variable "dev_account_id" {
  description = "Development account ID"
  type        = string
}

variable "staging_account_id" {
  description = "Staging account ID"
  type        = string
}

variable "uat_account_id" {
  description = "UAT account ID"
  type        = string
}

variable "prod_account_id" {
  description = "Production account ID"
  type        = string
}

variable "is_shared_account" {
  description = "Flag to indicate this is the shared services account"
  type        = bool
  default     = true
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
      error_message = "Shared services must be deployed in us-east-1 region."
    }
  }
}

# Common locals
locals {
  common_tags = {
    Project     = "Diagnyx"
    Environment = "shared"
    ManagedBy   = "Terraform"
    Component   = "SharedServices"
    Region      = "us-east-1"
  }
}