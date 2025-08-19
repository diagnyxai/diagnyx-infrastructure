# IAM Policies for Users

# CI/CD User Policy (GitHub Actions)
resource "aws_iam_policy" "ci_cd_policy" {
  name        = "${local.name_prefix}-ci-cd-policy"
  description = "Policy for CI/CD user (GitHub Actions)"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:UpdateFunctionCode",
          "lambda:UpdateFunctionConfiguration",
          "lambda:GetFunction",
          "lambda:ListVersionsByFunction"
        ]
        Resource = [
          "arn:aws:lambda:${var.aws_region}:*:function:${local.name_prefix}-*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "cognito-idp:UpdateUserPool",
          "cognito-idp:UpdateUserPoolClient",
          "cognito-idp:DescribeUserPool",
          "cognito-idp:DescribeUserPoolClient"
        ]
        Resource = [
          "arn:aws:cognito-idp:${var.aws_region}:*:userpool/*"
        ]
        Condition = {
          StringLike = {
            "aws:ResourceTag/Project" = "diagnyx"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ecs:UpdateService",
          "ecs:DescribeServices",
          "ecs:DescribeTaskDefinition",
          "ecs:RegisterTaskDefinition"
        ]
        Resource = [
          "arn:aws:ecs:${var.aws_region}:*:service/diagnyx-*/*",
          "arn:aws:ecs:${var.aws_region}:*:task-definition/diagnyx-*:*"
        ]
      },
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
        Resource = [
          "arn:aws:ecr:${var.aws_region}:*:repository/diagnyx-*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          "arn:aws:secretsmanager:${var.aws_region}:*:secret:${local.name_prefix}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-ci-cd-policy"
    Type = "IAMPolicy"
  })
}

# Application Deployer Policy
resource "aws_iam_policy" "app_deployer_policy" {
  name        = "${local.name_prefix}-app-deployer-policy"
  description = "Policy for application deployment user"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:UpdateFunctionCode",
          "lambda:UpdateFunctionConfiguration",
          "lambda:GetFunction"
        ]
        Resource = [
          "arn:aws:lambda:${var.aws_region}:*:function:${local.name_prefix}-*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ecs:UpdateService",
          "ecs:DescribeServices"
        ]
        Resource = [
          "arn:aws:ecs:${var.aws_region}:*:service/diagnyx-*/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "rds:DescribeDBInstances",
          "rds:DescribeDBClusters"
        ]
        Resource = [
          "arn:aws:rds:${var.aws_region}:*:db:diagnyx-*",
          "arn:aws:rds:${var.aws_region}:*:cluster:diagnyx-*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          "arn:aws:secretsmanager:${var.aws_region}:*:secret:${local.name_prefix}/*"
        ]
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-app-deployer-policy"
    Type = "IAMPolicy"
  })
}

# Monitoring User Policy (Read-only)
resource "aws_iam_policy" "monitoring_policy" {
  name        = "${local.name_prefix}-monitoring-policy"
  description = "Policy for monitoring user (read-only access)"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:Get*",
          "cloudwatch:List*",
          "cloudwatch:Describe*"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:Get*",
          "logs:Describe*",
          "logs:FilterLogEvents",
          "logs:StartQuery",
          "logs:StopQuery",
          "logs:GetQueryResults"
        ]
        Resource = [
          "arn:aws:logs:${var.aws_region}:*:log-group:/aws/lambda/${local.name_prefix}-*",
          "arn:aws:logs:${var.aws_region}:*:log-group:/ecs/diagnyx-*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "rds:DescribeDBInstances",
          "rds:DescribeDBClusters",
          "rds:DescribeDBLogFiles",
          "rds:DownloadDBLogFilePortion"
        ]
        Resource = [
          "arn:aws:rds:${var.aws_region}:*:db:diagnyx-*",
          "arn:aws:rds:${var.aws_region}:*:cluster:diagnyx-*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:GetFunction",
          "lambda:ListFunctions",
          "lambda:GetFunctionConfiguration"
        ]
        Resource = [
          "arn:aws:lambda:${var.aws_region}:*:function:${local.name_prefix}-*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ecs:DescribeServices",
          "ecs:DescribeTasks",
          "ecs:DescribeTaskDefinition",
          "ecs:DescribeClusters",
          "ecs:ListServices",
          "ecs:ListTasks"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "aws:ResourceTag/Project" = "diagnyx"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-monitoring-policy"
    Type = "IAMPolicy"
  })
}

# Backup User Policy
resource "aws_iam_policy" "backup_policy" {
  name        = "${local.name_prefix}-backup-policy"
  description = "Policy for backup user (database backup operations)"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rds:CreateDBSnapshot",
          "rds:DescribeDBSnapshots",
          "rds:DeleteDBSnapshot",
          "rds:CopyDBSnapshot",
          "rds:RestoreDBInstanceFromDBSnapshot"
        ]
        Resource = [
          "arn:aws:rds:${var.aws_region}:*:db:diagnyx-*",
          "arn:aws:rds:${var.aws_region}:*:snapshot:diagnyx-*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::diagnyx-backups-${var.environment}",
          "arn:aws:s3:::diagnyx-backups-${var.environment}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          "arn:aws:secretsmanager:${var.aws_region}:*:secret:${local.name_prefix}/database-*"
        ]
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-backup-policy"
    Type = "IAMPolicy"
  })
}

# Attach policies to users
resource "aws_iam_user_policy_attachment" "ci_cd_user_policy" {
  user       = aws_iam_user.ci_cd_user.name
  policy_arn = aws_iam_policy.ci_cd_policy.arn
}

resource "aws_iam_user_policy_attachment" "app_deployer_user_policy" {
  user       = aws_iam_user.app_deployer_user.name
  policy_arn = aws_iam_policy.app_deployer_policy.arn
}

resource "aws_iam_user_policy_attachment" "monitoring_user_policy" {
  user       = aws_iam_user.monitoring_user.name
  policy_arn = aws_iam_policy.monitoring_policy.arn
}

resource "aws_iam_user_policy_attachment" "backup_user_policy" {
  user       = aws_iam_user.backup_user.name
  policy_arn = aws_iam_policy.backup_policy.arn
}