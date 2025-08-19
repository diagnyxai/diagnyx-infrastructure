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