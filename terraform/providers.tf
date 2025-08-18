# Multi-Account Provider Configuration
# This file configures providers for cross-account deployment

terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
  }
  
  # Dynamic backend configuration based on environment
  backend "s3" {
    # These will be provided via backend config file
    # bucket         = "diagnyx-terraform-state-${environment}"
    # key            = "infrastructure/terraform.tfstate"
    # Always use us-east-1 for state storage
    region         = "us-east-1"
    # encrypt        = true
    # dynamodb_table = "diagnyx-terraform-locks-${environment}"
  }
}

# Primary provider for the target account
provider "aws" {
  region = var.aws_region
  
  # Assume role in target account if not running in that account
  dynamic "assume_role" {
    for_each = var.assume_role_arn != "" ? [1] : []
    content {
      role_arn     = var.assume_role_arn
      session_name = "terraform-diagnyx-${var.environment}"
      external_id  = var.external_id
    }
  }
  
  default_tags {
    tags = local.common_tags
  }
}

# Provider for shared services account (ECR, Route53, etc.)
provider "aws" {
  alias  = "shared"
  region = var.aws_region
  
  assume_role {
    role_arn     = "arn:aws:iam::${var.shared_services_account_id}:role/DiagnyxCrossAccountCICD"
    session_name = "terraform-diagnyx-shared"
    external_id  = var.external_id
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

# Provider for security account (logs, audit)
provider "aws" {
  alias  = "security"
  region = var.aws_region
  
  assume_role {
    role_arn     = "arn:aws:iam::${var.security_account_id}:role/DiagnyxCrossAccountCICD"
    session_name = "terraform-diagnyx-security"
    external_id  = var.external_id
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

# Provider for master account (billing, organizations)
provider "aws" {
  alias  = "master"
  region = var.aws_region
  
  assume_role {
    role_arn     = "arn:aws:iam::${var.master_account_id}:role/DiagnyxCrossAccountReadOnly"
    session_name = "terraform-diagnyx-master"
    external_id  = var.external_id
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

# Kubernetes provider configuration
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = concat(
      ["eks", "get-token", "--cluster-name", module.eks.cluster_name],
      var.assume_role_arn != "" ? ["--role-arn", var.assume_role_arn] : []
    )
  }
}

# Helm provider configuration
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = concat(
        ["eks", "get-token", "--cluster-name", module.eks.cluster_name],
        var.assume_role_arn != "" ? ["--role-arn", var.assume_role_arn] : []
      )
    }
  }
}

# kubectl provider configuration
provider "kubectl" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  load_config_file       = false
  
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = concat(
      ["eks", "get-token", "--cluster-name", module.eks.cluster_name],
      var.assume_role_arn != "" ? ["--role-arn", var.assume_role_arn] : []
    )
  }
}

# Data sources for account information
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_organizations_organization" "current" {
  provider = aws.master
}

# Region validation - ensure we're always in us-east-1
resource "null_resource" "region_validation" {
  triggers = {
    region = data.aws_region.current.name
  }
  
  lifecycle {
    precondition {
      condition     = data.aws_region.current.name == "us-east-1"
      error_message = "This infrastructure must be deployed in us-east-1 region. Current region: ${data.aws_region.current.name}"
    }
  }
}

# Local variables
locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
  
  # Account mapping
  account_map = {
    development = var.dev_account_id
    staging     = var.staging_account_id
    uat         = var.uat_account_id
    production  = var.prod_account_id
    shared      = var.shared_services_account_id
    security    = var.security_account_id
    master      = var.master_account_id
  }
  
  # Current account ID based on environment
  target_account_id = local.account_map[var.environment]
  
  # Common tags applied to all resources
  common_tags = {
    Environment     = var.environment
    AccountId       = local.account_id
    Project         = "diagnyx"
    ManagedBy       = "terraform"
    Owner           = var.owner_email
    CostCenter      = var.environment == "production" ? "operations" : "development"
    Region          = "us-east-1"
    LastModified    = timestamp()
  }
}

# Variables for multi-account configuration
variable "assume_role_arn" {
  description = "ARN of the role to assume in the target account"
  type        = string
  default     = ""
}

variable "external_id" {
  description = "External ID for role assumption"
  type        = string
  default     = "diagnyx-secure-external-id-2024"
}

variable "master_account_id" {
  description = "Master account ID"
  type        = string
}

variable "shared_services_account_id" {
  description = "Shared services account ID"
  type        = string
}

variable "security_account_id" {
  description = "Security account ID"
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