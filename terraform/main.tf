terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  backend "s3" {
    bucket         = "diagnyx-terraform-state-778715730121"
    key            = "infrastructure/terraform.tfstate"
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

# Certificate Management Module
module "certificates" {
  source = "./modules/certificates"

  # Environment Configuration
  environment = var.environment
  domain_name = var.domain_name
  
  # Subject alternative names for wildcard and subdomains
  subject_alternative_names = [
    "*.${var.domain_name}",
    "api.${var.domain_name}",
    "www.${var.domain_name}",
    "app.${var.domain_name}"
  ]

  # Certificate monitoring configuration
  enable_monitoring         = var.environment == "production" ? true : false
  notification_topic_arn    = var.notification_topic_arn
  log_retention_days        = var.environment == "production" ? 90 : 30
  early_renewal_days        = var.environment == "production" ? 30 : 14

  # Common tags
  tags = merge(local.common_tags, {
    Name    = "${var.environment}-ssl-certificates"
    Purpose = "SSL/TLS certificates for Diagnyx platform"
  })
}

# Authentication Module
module "authentication" {
  source = "./modules/authentication"

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

  # Database Configuration
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
    # Ensure VPC and networking are created first
    # These dependencies will be added when VPC module exists
  ]
}