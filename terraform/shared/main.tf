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
    key            = "shared/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "diagnyx-terraform-locks-master"
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Environment = "shared"
      Project     = "diagnyx"
      ManagedBy   = "terraform"
      Owner       = var.owner_email
    }
  }
}

# Local variables
locals {
  common_tags = {
    Environment = "shared"
    Project     = "diagnyx"
    CreatedBy   = "terraform"
  }
}

# Shared Resources Module
module "shared_resources" {
  source = "../modules/shared-resources"

  aws_region         = var.aws_region
  domain_name        = var.domain_name
  create_hosted_zone = var.create_hosted_zone
  common_tags        = local.common_tags
}