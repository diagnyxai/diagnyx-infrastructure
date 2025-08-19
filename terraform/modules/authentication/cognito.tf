# Local variables for naming
locals {
  name_prefix = "${var.project_name}-${var.environment}"
  
  user_pool_name = var.cognito_user_pool_name != null ? var.cognito_user_pool_name : "${local.name_prefix}-user-pool"
  client_name    = var.cognito_client_name != null ? var.cognito_client_name : "${local.name_prefix}-client"
}

# Cognito User Pool
resource "aws_cognito_user_pool" "main" {
  name = local.user_pool_name

  # Password Policy
  password_policy {
    minimum_length                   = var.password_policy.minimum_length
    require_lowercase                = var.password_policy.require_lowercase
    require_numbers                  = var.password_policy.require_numbers
    require_symbols                  = var.password_policy.require_symbols
    require_uppercase                = var.password_policy.require_uppercase
    temporary_password_validity_days = 7
  }

  # User Pool Settings
  auto_verified_attributes = ["email"]
  username_attributes      = ["email"]
  
  # Account Recovery
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  # User Attributes
  schema {
    attribute_data_type = "String"
    name               = "email"
    required           = true
    mutable            = true
    
    string_attribute_constraints {
      min_length = 7
      max_length = 255
    }
  }

  schema {
    attribute_data_type = "String"
    name               = "given_name"
    required           = true
    mutable            = true
    
    string_attribute_constraints {
      min_length = 1
      max_length = 50
    }
  }

  schema {
    attribute_data_type = "String"
    name               = "family_name"
    required           = true
    mutable            = true
    
    string_attribute_constraints {
      min_length = 1
      max_length = 50
    }
  }

  # Custom attributes for account type and organization
  schema {
    attribute_data_type = "String"
    name               = "account_type"
    required           = false
    mutable            = true
    
    string_attribute_constraints {
      min_length = 1
      max_length = 20
    }
  }

  schema {
    attribute_data_type = "String"
    name               = "organization_id"
    required           = false
    mutable            = true
    
    string_attribute_constraints {
      min_length = 1
      max_length = 50
    }
  }

  # Email Configuration
  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  # Verification Messages
  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
    email_subject         = "Verify your Diagnyx account"
    email_message         = "Please enter this verification code to verify your email: {####}"
  }

  # Admin Create User Config
  admin_create_user_config {
    allow_admin_create_user_only = false
    
    invite_message_template {
      email_subject = "Welcome to Diagnyx - Complete your account setup"
      email_message = "You have been invited to join Diagnyx. Username: {username}. Your temporary password is {####}. Please log in and change your password."
      sms_message   = "Welcome to Diagnyx! Username: {username}. Your temporary password is {####}. Please log in and change your password."
    }
  }

  # Lambda Triggers
  lambda_config {
    post_confirmation = aws_lambda_function.post_confirmation.arn
    pre_token_generation = aws_lambda_function.pre_token_generation.arn
  }

  tags = merge(var.common_tags, {
    Name = local.user_pool_name
    Type = "Authentication"
  })
}

# Cognito User Pool Client
resource "aws_cognito_user_pool_client" "main" {
  name         = local.client_name
  user_pool_id = aws_cognito_user_pool.main.id

  # Client Settings
  generate_secret                      = true
  prevent_user_existence_errors       = "ENABLED"
  enable_token_revocation             = true
  enable_propagate_additional_user_context_data = true

  # Token Validity
  access_token_validity  = 24   # 24 hours
  id_token_validity     = 24   # 24 hours
  refresh_token_validity = 168  # 7 days (168 hours)

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "hours"
  }

  # Allowed OAuth Flows
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                = ["openid", "email", "profile"]
  allowed_oauth_flows_user_pool_client = true

  # Callback URLs
  callback_urls = [
    "https://app.diagnyx.ai/auth/callback",
    "http://localhost:3002/auth/callback"
  ]

  logout_urls = [
    "https://app.diagnyx.ai/auth/logout",
    "http://localhost:3002/auth/logout"
  ]

  # Supported Identity Providers
  supported_identity_providers = ["COGNITO"]

  # Read and Write Attributes
  read_attributes = [
    "email",
    "email_verified",
    "given_name",
    "family_name",
    "custom:account_type",
    "custom:organization_id"
  ]

  write_attributes = [
    "email",
    "given_name",
    "family_name",
    "custom:account_type",
    "custom:organization_id"
  ]

  # Explicit Auth Flows
  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH"
  ]
  
  # Note: Cognito user pool client does not support tags
}

# Cognito User Pool Domain
resource "aws_cognito_user_pool_domain" "main" {
  domain       = "${local.name_prefix}-auth"
  user_pool_id = aws_cognito_user_pool.main.id

  depends_on = [aws_cognito_user_pool.main]
}

# Lambda Permissions for Cognito Triggers
resource "aws_lambda_permission" "allow_cognito_post_confirmation" {
  statement_id  = "AllowExecutionFromCognito"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.post_confirmation.function_name
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = aws_cognito_user_pool.main.arn
}

resource "aws_lambda_permission" "allow_cognito_pre_token_generation" {
  statement_id  = "AllowExecutionFromCognito"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.pre_token_generation.function_name
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = aws_cognito_user_pool.main.arn
}