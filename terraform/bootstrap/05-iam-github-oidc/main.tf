# GitHub OIDC Provider for Passwordless CI/CD
# This module sets up OIDC provider for GitHub Actions

terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
  
  backend "s3" {}
}

provider "aws" {
  region = "us-east-1"
  
  default_tags {
    tags = {
      Project     = "Diagnyx"
      Component   = "IAM-GitHub-OIDC"
      ManagedBy   = "Terraform"
    }
  }
}

# Get GitHub's OIDC thumbprint
data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# Create the OIDC provider
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = [
    data.tls_certificate.github.certificates[0].sha1_fingerprint
  ]

  tags = {
    Name = "github-actions-oidc"
  }
}

# IAM Role for GitHub Actions - Development
resource "aws_iam_role" "github_actions_dev" {
  name = "DiagnyxGitHubActions-Development"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = [
              "repo:diagnyx/*:ref:refs/heads/develop",
              "repo:diagnyx/*:ref:refs/heads/feature/*"
            ]
          }
        }
      }
    ]
  })

  max_session_duration = 3600

  tags = {
    Name        = "DiagnyxGitHubActions-Development"
    Environment = "development"
    Purpose     = "ci-cd"
  }
}

# IAM Role for GitHub Actions - Staging
resource "aws_iam_role" "github_actions_staging" {
  name = "DiagnyxGitHubActions-Staging"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = [
              "repo:diagnyx/*:ref:refs/heads/staging",
              "repo:diagnyx/*:ref:refs/heads/release/*"
            ]
          }
        }
      }
    ]
  })

  max_session_duration = 3600

  tags = {
    Name        = "DiagnyxGitHubActions-Staging"
    Environment = "staging"
    Purpose     = "ci-cd"
  }
}

# IAM Role for GitHub Actions - Production
resource "aws_iam_role" "github_actions_prod" {
  name = "DiagnyxGitHubActions-Production"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = [
              "repo:diagnyx/*:ref:refs/heads/main",
              "repo:diagnyx/*:ref:refs/tags/v*"
            ]
          }
        }
      }
    ]
  })

  max_session_duration = 3600

  tags = {
    Name        = "DiagnyxGitHubActions-Production"
    Environment = "production"
    Purpose     = "ci-cd"
  }
}

# Policy for GitHub Actions deployment
resource "aws_iam_policy" "github_actions_deploy" {
  name        = "DiagnyxGitHubActionsDeployPolicy"
  description = "Policy for GitHub Actions to deploy to ECS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # ECR Permissions
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = "*"
      },
      # ECS Permissions
      {
        Effect = "Allow"
        Action = [
          "ecs:DescribeServices",
          "ecs:UpdateService",
          "ecs:DescribeTaskDefinition",
          "ecs:RegisterTaskDefinition",
          "ecs:DescribeTasks",
          "ecs:ListTasks",
          "ecs:RunTask"
        ]
        Resource = "*"
      },
      # IAM PassRole for ECS
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = [
          "arn:aws:iam::*:role/DiagnyxECSTask*"
        ]
      },
      # CloudFormation
      {
        Effect = "Allow"
        Action = [
          "cloudformation:DescribeStacks",
          "cloudformation:CreateStack",
          "cloudformation:UpdateStack",
          "cloudformation:DeleteStack",
          "cloudformation:DescribeStackEvents",
          "cloudformation:DescribeStackResources"
        ]
        Resource = "arn:aws:cloudformation:us-east-1:*:stack/diagnyx-*"
      },
      # S3 for artifacts
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::diagnyx-artifacts-*",
          "arn:aws:s3:::diagnyx-artifacts-*/*"
        ]
      },
      # CloudWatch Logs
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:us-east-1:*:log-group:/aws/codebuild/*"
      }
    ]
  })

  tags = {
    Name      = "DiagnyxGitHubActionsDeployPolicy"
    Purpose   = "github-actions-deployment"
    ManagedBy = "terraform"
  }
}

# Attach policies to roles
resource "aws_iam_role_policy_attachment" "github_dev_deploy" {
  role       = aws_iam_role.github_actions_dev.name
  policy_arn = aws_iam_policy.github_actions_deploy.arn
}

resource "aws_iam_role_policy_attachment" "github_staging_deploy" {
  role       = aws_iam_role.github_actions_staging.name
  policy_arn = aws_iam_policy.github_actions_deploy.arn
}

resource "aws_iam_role_policy_attachment" "github_prod_deploy" {
  role       = aws_iam_role.github_actions_prod.name
  policy_arn = aws_iam_policy.github_actions_deploy.arn
}

# Cross-account assume role policies
resource "aws_iam_policy" "assume_deploy_role" {
  name        = "DiagnyxAssumeDeployRole"
  description = "Policy to assume deployment roles in other accounts"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Resource = [
          "arn:aws:iam::215726089610:role/DiagnyxCrossAccountCICD",  # Dev
          "arn:aws:iam::435455014599:role/DiagnyxCrossAccountCICD",  # Staging
          "arn:aws:iam::318265006643:role/DiagnyxCrossAccountCICD",  # UAT
          "arn:aws:iam::921205606542:role/DiagnyxCrossAccountCICD",  # Prod
          "arn:aws:iam::008341391284:role/DiagnyxCrossAccountCICD"   # Shared
        ]
      }
    ]
  })

  tags = {
    Name      = "DiagnyxAssumeDeployRole"
    Purpose   = "cross-account-deployment"
    ManagedBy = "terraform"
  }
}

# Attach cross-account assume role policies
resource "aws_iam_role_policy_attachment" "github_dev_assume" {
  role       = aws_iam_role.github_actions_dev.name
  policy_arn = aws_iam_policy.assume_deploy_role.arn
}

resource "aws_iam_role_policy_attachment" "github_staging_assume" {
  role       = aws_iam_role.github_actions_staging.name
  policy_arn = aws_iam_policy.assume_deploy_role.arn
}

resource "aws_iam_role_policy_attachment" "github_prod_assume" {
  role       = aws_iam_role.github_actions_prod.name
  policy_arn = aws_iam_policy.assume_deploy_role.arn
}

# Outputs
output "github_oidc_provider_arn" {
  value       = aws_iam_openid_connect_provider.github.arn
  description = "ARN of the GitHub OIDC provider"
}

output "github_actions_role_arns" {
  value = {
    development = aws_iam_role.github_actions_dev.arn
    staging     = aws_iam_role.github_actions_staging.arn
    production  = aws_iam_role.github_actions_prod.arn
  }
  description = "ARNs of GitHub Actions IAM roles"
  sensitive   = true
}