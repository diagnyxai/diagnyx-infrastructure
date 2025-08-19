# SES Configuration for Email Services

# SES Domain Identity
resource "aws_ses_domain_identity" "main" {
  domain = var.ses_domain

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-ses-domain"
    Type = "SES"
  })
}

# SES Domain DKIM
resource "aws_ses_domain_dkim" "main" {
  domain = aws_ses_domain_identity.main.domain
}

# SES Email Identity (for from address)
resource "aws_ses_email_identity" "from_email" {
  email = var.from_email

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-ses-email"
    Type = "SES"
  })
}

# SES Configuration Set
resource "aws_ses_configuration_set" "main" {
  name = "${local.name_prefix}-config-set"

  # Enable bounce and complaint tracking
  delivery_options {
    tls_policy = "Require"
  }

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-ses-config-set"
    Type = "SES"
  })
}

# SES Event Destination for bounces and complaints
resource "aws_ses_event_destination" "cloudwatch" {
  name                   = "cloudwatch-destination"
  configuration_set_name = aws_ses_configuration_set.main.name
  enabled                = true
  matching_types         = ["bounce", "complaint", "delivery", "send", "reject"]

  cloudwatch_destination {
    default_value  = "0"
    dimension_name = "EmailAddress"
    value_source   = "emailAddress"
  }
}

# SES Receipt Rule Set (for handling bounces if needed)
resource "aws_ses_receipt_rule_set" "main" {
  rule_set_name = "${local.name_prefix}-receipt-rules"

  depends_on = [aws_ses_domain_identity.main]
}

# CloudWatch Log Group for SES events
resource "aws_cloudwatch_log_group" "ses_logs" {
  name              = "/aws/ses/${local.name_prefix}"
  retention_in_days = 30

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-ses-logs"
    Type = "Logs"
  })
}

# Email Templates for different types of emails
resource "aws_ses_template" "welcome_email" {
  name    = "${local.name_prefix}-welcome"
  subject = "Welcome to Diagnyx - Get Started with LLM Observability"
  html    = templatefile("${path.module}/email-templates/welcome.html", {
    app_url = var.environment == "production" ? "https://app.diagnyx.ai" : "http://localhost:3002"
  })
  text = templatefile("${path.module}/email-templates/welcome.txt", {
    app_url = var.environment == "production" ? "https://app.diagnyx.ai" : "http://localhost:3002"
  })

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-welcome-template"
    Type = "SESTemplate"
  })
}

resource "aws_ses_template" "verification_email" {
  name    = "${local.name_prefix}-verification"
  subject = "Verify your Diagnyx account"
  html    = templatefile("${path.module}/email-templates/verification.html", {
    app_url = var.environment == "production" ? "https://app.diagnyx.ai" : "http://localhost:3002"
  })
  text = templatefile("${path.module}/email-templates/verification.txt", {
    app_url = var.environment == "production" ? "https://app.diagnyx.ai" : "http://localhost:3002"
  })

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-verification-template"
    Type = "SESTemplate"
  })
}

resource "aws_ses_template" "password_reset" {
  name    = "${local.name_prefix}-password-reset"
  subject = "Reset your Diagnyx password"
  html    = templatefile("${path.module}/email-templates/password-reset.html", {
    app_url = var.environment == "production" ? "https://app.diagnyx.ai" : "http://localhost:3002"
  })
  text = templatefile("${path.module}/email-templates/password-reset.txt", {
    app_url = var.environment == "production" ? "https://app.diagnyx.ai" : "http://localhost:3002"
  })

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-password-reset-template"
    Type = "SESTemplate"
  })
}

# SES Identity Policy to allow sending from Cognito and Lambda
resource "aws_ses_identity_policy" "cognito_sending_policy" {
  identity = aws_ses_domain_identity.main.arn
  name     = "${local.name_prefix}-cognito-sending-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = [
            aws_iam_role.ses_sending_role.arn,
            aws_iam_role.lambda_execution_role.arn,
            aws_iam_role.microservice_role.arn
          ]
        }
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail"
        ]
        Resource = aws_ses_domain_identity.main.arn
      }
    ]
  })
}