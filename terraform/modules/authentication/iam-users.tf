# IAM Users for Deployment and Management

# CI/CD User for GitHub Actions
resource "aws_iam_user" "ci_cd_user" {
  name = "${local.name_prefix}-ci-cd-user"
  path = "/service-accounts/"

  tags = merge(var.common_tags, {
    Name        = "${local.name_prefix}-ci-cd-user"
    Type        = "ServiceAccount"
    Purpose     = "GitHub Actions CI/CD"
    Environment = var.environment
  })
}

resource "aws_iam_access_key" "ci_cd_user_key" {
  user = aws_iam_user.ci_cd_user.name
}

# Application Deployer User
resource "aws_iam_user" "app_deployer_user" {
  name = "${local.name_prefix}-app-deployer"
  path = "/service-accounts/"

  tags = merge(var.common_tags, {
    Name        = "${local.name_prefix}-app-deployer"
    Type        = "ServiceAccount"
    Purpose     = "Application Deployment"
    Environment = var.environment
  })
}

resource "aws_iam_access_key" "app_deployer_user_key" {
  user = aws_iam_user.app_deployer_user.name
}

# Monitoring User
resource "aws_iam_user" "monitoring_user" {
  name = "${local.name_prefix}-monitoring-user"
  path = "/service-accounts/"

  tags = merge(var.common_tags, {
    Name        = "${local.name_prefix}-monitoring-user"
    Type        = "ServiceAccount"
    Purpose     = "Monitoring and Observability"
    Environment = var.environment
  })
}

resource "aws_iam_access_key" "monitoring_user_key" {
  user = aws_iam_user.monitoring_user.name
}

# Backup User
resource "aws_iam_user" "backup_user" {
  name = "${local.name_prefix}-backup-user"
  path = "/service-accounts/"

  tags = merge(var.common_tags, {
    Name        = "${local.name_prefix}-backup-user"
    Type        = "ServiceAccount"
    Purpose     = "Database Backup and Recovery"
    Environment = var.environment
  })
}

resource "aws_iam_access_key" "backup_user_key" {
  user = aws_iam_user.backup_user.name
}

# Hybrid Secrets Management Strategy
# CI/CD credentials will be manually added to GitHub Secrets
# Operational credentials will be stored in local secure file (not in Terraform state)
# Only store CI/CD credentials in AWS Secrets Manager for automation

resource "aws_secretsmanager_secret" "ci_cd_credentials" {
  name        = "${local.name_prefix}/ci-cd-credentials"
  description = "CI/CD user credentials for GitHub Actions automation"

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-ci-cd-credentials"
    Type = "GitHubSecrets"
  })
}

resource "aws_secretsmanager_secret_version" "ci_cd_credentials" {
  secret_id = aws_secretsmanager_secret.ci_cd_credentials.id
  secret_string = jsonencode({
    access_key_id     = aws_iam_access_key.ci_cd_user_key.id
    secret_access_key = aws_iam_access_key.ci_cd_user_key.secret
    user_name         = aws_iam_user.ci_cd_user.name
    environment       = var.environment
    github_secret_names = {
      access_key = "AWS_ACCESS_KEY_ID_${upper(var.environment)}"
      secret_key = "AWS_SECRET_ACCESS_KEY_${upper(var.environment)}"
    }
  })
}