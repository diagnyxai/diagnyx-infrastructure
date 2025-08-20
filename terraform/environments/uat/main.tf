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
    key            = "environments/uat/terraform.tfstate"
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
    CostCenter  = "infrastructure"
  }
  
  azs = slice(data.aws_availability_zones.available.names, 0, 3)
}

# VPC Module
module "vpc" {
  source = "../../modules/vpc"
  
  environment = var.environment
  name_prefix = local.name_prefix
  vpc_cidr    = var.vpc_cidr
  azs         = local.azs
  
  common_tags = local.common_tags
}

# Shared Resources Module (ECR repositories)
module "shared_resources" {
  source = "../../modules/shared-resources"
  
  environment = var.environment
  common_tags = local.common_tags
  
  depends_on = [
    module.vpc
  ]
}

# App Services Module (Load balancer and target groups)
module "app_services" {
  source = "../../modules/app-services"
  
  environment     = var.environment
  vpc_id          = module.vpc.vpc_id
  private_subnets = module.vpc.private_subnets
  public_subnets  = module.vpc.public_subnets
  
  common_tags = local.common_tags
  depends_on = [module.vpc]
}

# Authentication Module
module "authentication" {
  source = "../../modules/authentication"
  
  environment = var.environment
  aws_region  = var.aws_region
  
  vpc_id            = module.vpc.vpc_id
  private_subnets   = module.vpc.private_subnets
  database_endpoint = module.authentication.database_endpoint
  
  depends_on = [module.vpc]
}