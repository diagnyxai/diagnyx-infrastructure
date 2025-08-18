# Cross-Account IAM Roles
# These roles allow secure access between accounts

locals {
  master_account_id = "778715730121"
  external_id      = "diagnyx-secure-2024"
  
  # Account IDs
  account_ids = {
    dev        = "215726089610"
    staging    = "435455014599"
    uat        = "318265006643"
    production = "921205606542"
    shared     = "008341391284"
  }
}

# ==================== CROSS-ACCOUNT ADMIN ROLE ====================
# Emergency access from master account only
resource "aws_iam_role" "cross_account_admin" {
  name               = "DiagnyxCrossAccountAdmin"
  description        = "Admin access from master account for emergency situations"
  max_session_duration = 3600  # 1 hour

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${local.master_account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = local.external_id
          }
          IpAddress = {
            "aws:SourceIp" = [
              "0.0.0.0/0"  # Update with your office IP ranges
            ]
          }
        }
      }
    ]
  })

  tags = {
    Name        = "DiagnyxCrossAccountAdmin"
    Purpose     = "emergency-access"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "admin_access" {
  role       = aws_iam_role.cross_account_admin.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# ==================== CI/CD DEPLOYMENT ROLE ====================
# For GitHub Actions and CI/CD pipelines
resource "aws_iam_role" "cicd_deployment" {
  name               = "DiagnyxCrossAccountCICD"
  description        = "CI/CD deployment role for automated deployments"
  max_session_duration = 7200  # 2 hours

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = [
            "arn:aws:iam::${local.master_account_id}:root",
            "arn:aws:iam::${local.account_ids.shared}:root"
          ]
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = local.external_id
          }
        }
      }
    ]
  })

  tags = {
    Name        = "DiagnyxCrossAccountCICD"
    Purpose     = "cicd-deployment"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# ==================== DEVELOPER ACCESS ROLE ====================
# For developers to debug and monitor
resource "aws_iam_role" "cross_account_developer" {
  name               = "DiagnyxCrossAccountDeveloper"
  description        = "Developer access for debugging and monitoring"
  max_session_duration = 14400  # 4 hours

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${local.master_account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = local.external_id
          }
          Bool = {
            "aws:MultiFactorAuthPresent" = "true"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "DiagnyxCrossAccountDeveloper"
    Purpose     = "developer-access"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# ==================== READ-ONLY ACCESS ROLE ====================
# For monitoring and auditing
resource "aws_iam_role" "cross_account_readonly" {
  name               = "DiagnyxCrossAccountReadOnly"
  description        = "Read-only access for monitoring and auditing"
  max_session_duration = 43200  # 12 hours

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = [
            "arn:aws:iam::${local.master_account_id}:root",
            "arn:aws:iam::${local.account_ids.shared}:root"
          ]
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = local.external_id
          }
        }
      }
    ]
  })

  tags = {
    Name        = "DiagnyxCrossAccountReadOnly"
    Purpose     = "readonly-access"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "readonly_access" {
  role       = aws_iam_role.cross_account_readonly.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# ==================== COST EXPLORER ACCESS ROLE ====================
# For cost analysis and optimization
resource "aws_iam_role" "cross_account_cost_explorer" {
  name               = "DiagnyxCrossAccountCostExplorer"
  description        = "Cost analysis and optimization access"
  max_session_duration = 43200  # 12 hours

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${local.master_account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = local.external_id
          }
        }
      }
    ]
  })

  tags = {
    Name        = "DiagnyxCrossAccountCostExplorer"
    Purpose     = "cost-analysis"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Attach cost explorer policies
resource "aws_iam_role_policy_attachment" "cost_explorer_access" {
  role       = aws_iam_role.cross_account_cost_explorer.name
  policy_arn = "arn:aws:iam::aws:policy/job-function/Billing"
}

# ==================== ORGANIZATION ACCESS ROLE ====================
# Default role created by AWS Organizations (already exists)
resource "aws_iam_role" "organization_account_access" {
  count = var.environment != "master" ? 1 : 0
  
  name = "OrganizationAccountAccessRole"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${local.master_account_id}:root"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
  
  lifecycle {
    ignore_changes = all  # This role is managed by AWS Organizations
  }

  tags = {
    Name        = "OrganizationAccountAccessRole"
    Purpose     = "organization-management"
    Environment = var.environment
    ManagedBy   = "aws-organizations"
  }
}

# Outputs
output "cross_account_role_arns" {
  value = {
    admin        = aws_iam_role.cross_account_admin.arn
    cicd         = aws_iam_role.cicd_deployment.arn
    developer    = aws_iam_role.cross_account_developer.arn
    readonly     = aws_iam_role.cross_account_readonly.arn
    cost_explorer = aws_iam_role.cross_account_cost_explorer.arn
  }
  description = "ARNs of cross-account IAM roles"
  sensitive   = true
}