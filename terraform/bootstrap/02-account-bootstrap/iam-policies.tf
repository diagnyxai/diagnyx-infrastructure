# Custom IAM Policies for Diagnyx Services

# ==================== CI/CD DEPLOYMENT POLICY ====================
resource "aws_iam_policy" "cicd_deployment" {
  name        = "DiagnyxCICDDeploymentPolicy"
  description = "Policy for CI/CD deployments"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # ECS Permissions
      {
        Effect = "Allow"
        Action = [
          "ecs:*",
          "ecr:*"
        ]
        Resource = "*"
      },
      # Load Balancer Permissions
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:*",
          "ec2:Describe*",
          "ec2:CreateSecurityGroup",
          "ec2:CreateTags",
          "ec2:AuthorizeSecurityGroup*",
          "ec2:RevokeSecurityGroup*"
        ]
        Resource = "*"
      },
      # CloudFormation Permissions
      {
        Effect = "Allow"
        Action = [
          "cloudformation:*"
        ]
        Resource = "*"
      },
      # IAM Permissions (limited)
      {
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:PutRolePolicy",
          "iam:AttachRolePolicy",
          "iam:PassRole",
          "iam:GetRole",
          "iam:GetRolePolicy",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies"
        ]
        Resource = [
          "arn:aws:iam::*:role/Diagnyx*",
          "arn:aws:iam::*:role/ecs*"
        ]
      },
      # S3 Permissions
      {
        Effect = "Allow"
        Action = [
          "s3:*"
        ]
        Resource = [
          "arn:aws:s3:::diagnyx-*",
          "arn:aws:s3:::diagnyx-*/*"
        ]
      },
      # CloudWatch Logs
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name      = "DiagnyxCICDDeploymentPolicy"
    Purpose   = "cicd-deployment"
    ManagedBy = "terraform"
  }
}

# Attach to CI/CD role
resource "aws_iam_role_policy_attachment" "cicd_deployment_policy" {
  role       = aws_iam_role.cicd_deployment.name
  policy_arn = aws_iam_policy.cicd_deployment.arn
}

# ==================== DEVELOPER POLICY ====================
resource "aws_iam_policy" "developer_access" {
  name        = "DiagnyxDeveloperPolicy"
  description = "Policy for developer access"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Read-only for most services
      {
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "ecs:Describe*",
          "ecs:List*",
          "ecr:Describe*",
          "ecr:List*",
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "elasticloadbalancing:Describe*",
          "cloudwatch:Describe*",
          "cloudwatch:Get*",
          "cloudwatch:List*",
          "logs:Describe*",
          "logs:Get*",
          "logs:FilterLogEvents",
          "logs:StartQuery",
          "logs:StopQuery",
          "rds:Describe*",
          "elasticache:Describe*",
          "s3:List*",
          "s3:Get*"
        ]
        Resource = "*"
      },
      # ECS Execute Command (for debugging)
      {
        Effect = "Allow"
        Action = [
          "ecs:ExecuteCommand"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/Environment": ["development", "staging"]
          }
        }
      },
      # Parameter Store Read
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = "arn:aws:ssm:*:*:parameter/diagnyx/*"
      },
      # Secrets Manager Read
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:*:*:secret:diagnyx-*"
      }
    ]
  })

  tags = {
    Name      = "DiagnyxDeveloperPolicy"
    Purpose   = "developer-access"
    ManagedBy = "terraform"
  }
}

# Attach to developer role
resource "aws_iam_role_policy_attachment" "developer_policy" {
  role       = aws_iam_role.cross_account_developer.name
  policy_arn = aws_iam_policy.developer_access.arn
}

# ==================== SECRETS ACCESS POLICY ====================
resource "aws_iam_policy" "secrets_access" {
  name        = "DiagnyxSecretsAccessPolicy"
  description = "Policy for accessing secrets and parameters"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecrets"
        ]
        Resource = [
          "arn:aws:secretsmanager:us-east-1:*:secret:diagnyx-*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath",
          "ssm:DescribeParameters"
        ]
        Resource = [
          "arn:aws:ssm:us-east-1:*:parameter/diagnyx/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = [
          "arn:aws:kms:us-east-1:*:key/*"
        ]
        Condition = {
          StringLike = {
            "kms:ViaService": [
              "secretsmanager.us-east-1.amazonaws.com",
              "ssm.us-east-1.amazonaws.com"
            ]
          }
        }
      }
    ]
  })

  tags = {
    Name      = "DiagnyxSecretsAccessPolicy"
    Purpose   = "secrets-management"
    ManagedBy = "terraform"
  }
}

# ==================== DATABASE ACCESS POLICY ====================
resource "aws_iam_policy" "database_access" {
  name        = "DiagnyxDatabaseAccessPolicy"
  description = "Policy for database access"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rds:Describe*",
          "rds:ListTagsForResource",
          "rds-db:connect"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticache:Describe*",
          "elasticache:List*"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name      = "DiagnyxDatabaseAccessPolicy"
    Purpose   = "database-access"
    ManagedBy = "terraform"
  }
}

# ==================== S3 ACCESS POLICY ====================
resource "aws_iam_policy" "s3_access" {
  name        = "DiagnyxS3AccessPolicy"
  description = "Policy for S3 bucket access"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::diagnyx-*",
          "arn:aws:s3:::diagnyx-*/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListAllMyBuckets",
          "s3:GetBucketLocation"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name      = "DiagnyxS3AccessPolicy"
    Purpose   = "s3-access"
    ManagedBy = "terraform"
  }
}

# ==================== CLOUDWATCH POLICY ====================
resource "aws_iam_policy" "cloudwatch_access" {
  name        = "DiagnyxCloudWatchAccessPolicy"
  description = "Policy for CloudWatch access"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "cloudwatch:GetMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          "arn:aws:logs:us-east-1:*:log-group:/aws/diagnyx/*",
          "arn:aws:logs:us-east-1:*:log-group:/ecs/diagnyx/*"
        ]
      }
    ]
  })

  tags = {
    Name      = "DiagnyxCloudWatchAccessPolicy"
    Purpose   = "monitoring"
    ManagedBy = "terraform"
  }
}

# ==================== KMS ACCESS POLICY ====================
resource "aws_iam_policy" "kms_access" {
  name        = "DiagnyxKMSAccessPolicy"
  description = "Policy for KMS key usage"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey",
          "kms:CreateGrant"
        ]
        Resource = [
          "arn:aws:kms:us-east-1:*:key/*"
        ]
        Condition = {
          StringLike = {
            "kms:AliasName": "alias/diagnyx-*"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "kms:ListKeys",
          "kms:ListAliases"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name      = "DiagnyxKMSAccessPolicy"
    Purpose   = "encryption"
    ManagedBy = "terraform"
  }
}