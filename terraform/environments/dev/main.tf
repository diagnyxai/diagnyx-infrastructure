terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2"
    }
  }
  
  backend "s3" {
    bucket         = "diagnyx-terraform-state-778715730121"
    key            = "environments/dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "diagnyx-terraform-locks-master"
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Environment = var.environment
      Project     = "diagnyx"
      ManagedBy   = "terraform"
      Owner       = var.owner_email
    }
  }
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

# Local variables
locals {
  name_prefix = "diagnyx-${var.environment}"
  
  common_tags = {
    Environment = var.environment
    Project     = "diagnyx"
    CreatedBy   = "terraform"
  }
  
  azs = slice(data.aws_availability_zones.available.names, 0, 3)
}

# Shared Resources Module (ECR repositories)
module "shared_resources" {
  source = "../../modules/shared-resources"
  
  aws_region     = var.aws_region
  common_tags    = local.common_tags
}

# Authentication Module (environment-specific) - NO VPC for local development
module "authentication" {
  source = "../../modules/authentication"

  # Environment Configuration
  environment    = var.environment
  aws_region     = var.aws_region
  project_name   = "diagnyx"
  owner_email    = var.owner_email

  # Cognito Configuration
  cognito_user_pool_name = var.cognito_user_pool_name
  cognito_client_name    = var.cognito_client_name
  password_policy        = var.password_policy

  # SES Configuration
  ses_domain = var.ses_domain
  from_email = var.from_email

  # Database Configuration (local)
  database_name            = var.database_name
  database_master_username = var.database_master_username

  # API Gateway Configuration
  api_gateway_endpoint = var.api_gateway_endpoint

  # Lambda Configuration
  lambda_runtime     = "nodejs18.x"
  lambda_timeout     = 30
  lambda_memory_size = 128

  # Common tags
  common_tags = local.common_tags

  depends_on = [
    module.shared_resources
  ]
}

# Note: VPC, ECS Cluster, and App Services modules disabled for local development
# These will be needed when moving to production cloud deployment