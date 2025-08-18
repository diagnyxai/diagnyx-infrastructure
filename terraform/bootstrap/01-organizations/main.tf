# AWS Organizations Setup - Simplified Bootstrap
# Creates organization and member accounts for Diagnyx

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
      Project     = "Diagnyx"
      Component   = "Organizations"
      ManagedBy   = "Terraform"
    }
  }
}

# Import existing organization
resource "aws_organizations_organization" "main" {
  feature_set = "ALL"
  
  aws_service_access_principals = [
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
    "sso.amazonaws.com",
    "member.org.stacksets.cloudformation.amazonaws.com"
  ]
  
  enabled_policy_types = [
    "SERVICE_CONTROL_POLICY"
  ]
}

# Organizational Units
resource "aws_organizations_organizational_unit" "production" {
  name      = "Production"
  parent_id = aws_organizations_organization.main.roots[0].id
}

resource "aws_organizations_organizational_unit" "non_production" {
  name      = "NonProduction"
  parent_id = aws_organizations_organization.main.roots[0].id
}

resource "aws_organizations_organizational_unit" "shared" {
  name      = "Shared"
  parent_id = aws_organizations_organization.main.roots[0].id
}

# Development Account
resource "aws_organizations_account" "dev" {
  name      = "diagnyx-development"
  email     = var.dev_account_email
  parent_id = aws_organizations_organizational_unit.non_production.id
  
  lifecycle {
    ignore_changes = [email]
  }
}

# Staging Account
resource "aws_organizations_account" "staging" {
  name      = "diagnyx-staging"
  email     = var.staging_account_email
  parent_id = aws_organizations_organizational_unit.non_production.id
  
  lifecycle {
    ignore_changes = [email]
  }
}

# UAT Account
resource "aws_organizations_account" "uat" {
  name      = "diagnyx-uat"
  email     = var.uat_account_email
  parent_id = aws_organizations_organizational_unit.non_production.id
  
  lifecycle {
    ignore_changes = [email]
  }
}

# Production Account
resource "aws_organizations_account" "production" {
  name      = "diagnyx-production"
  email     = var.prod_account_email
  parent_id = aws_organizations_organizational_unit.production.id
  
  lifecycle {
    ignore_changes = [email]
  }
}

# Shared Services Account
resource "aws_organizations_account" "shared_services" {
  name      = "diagnyx-shared-services"
  email     = var.shared_account_email
  parent_id = aws_organizations_organizational_unit.shared.id
  
  lifecycle {
    ignore_changes = [email]
  }
}

# Basic Service Control Policy - Cost Control
resource "aws_organizations_policy" "cost_control" {
  name        = "DiagnyxCostControl"
  description = "Enforce cost control measures"
  type        = "SERVICE_CONTROL_POLICY"
  
  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Deny"
        Action = [
          "ec2:RunInstances"
        ]
        Resource = "arn:aws:ec2:*:*:instance/*"
        Condition = {
          StringNotEquals = {
            "ec2:InstanceType": [
              "t4g.micro",
              "t4g.small",
              "t4g.medium",
              "t4g.large",
              "t3.micro",
              "t3.small",
              "t3.medium"
            ]
          }
        }
      },
      {
        Effect = "Deny"
        Action = [
          "rds:CreateDBInstance"
        ]
        Resource = "*"
        Condition = {
          StringNotLike = {
            "rds:DatabaseClass": [
              "db.t4g.*",
              "db.t3.*"
            ]
          }
        }
      }
    ]
  })
}

# Attach cost control policy to non-production OUs
resource "aws_organizations_policy_attachment" "cost_control_nonprod" {
  policy_id = aws_organizations_policy.cost_control.id
  target_id = aws_organizations_organizational_unit.non_production.id
}

# Region Restriction Policy
resource "aws_organizations_policy" "region_restriction" {
  name        = "DiagnyxRegionRestriction"
  description = "Restrict all actions to us-east-1"
  type        = "SERVICE_CONTROL_POLICY"
  
  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Deny"
        Action = "*"
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "aws:RequestedRegion": "us-east-1"
          }
        }
      }
    ]
  })
}

# Attach region restriction to all OUs
resource "aws_organizations_policy_attachment" "region_restriction_nonprod" {
  policy_id = aws_organizations_policy.region_restriction.id
  target_id = aws_organizations_organizational_unit.non_production.id
}

resource "aws_organizations_policy_attachment" "region_restriction_prod" {
  policy_id = aws_organizations_policy.region_restriction.id
  target_id = aws_organizations_organizational_unit.production.id
}

resource "aws_organizations_policy_attachment" "region_restriction_shared" {
  policy_id = aws_organizations_policy.region_restriction.id
  target_id = aws_organizations_organizational_unit.shared.id
}