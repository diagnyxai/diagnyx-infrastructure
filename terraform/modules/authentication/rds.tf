# RDS Configuration (DISABLED for local development)
# Using local PostgreSQL database instead of AWS RDS for development environment
# 
# For production deployment, uncomment and configure the RDS resources below
# when moving from local development to cloud deployment

# Note: Lambda functions still need proper network configuration
# Security Group for Lambda functions (minimal setup without VPC dependency)
resource "aws_security_group" "lambda" {
  name_prefix = "${local.name_prefix}-lambda-sg"
  description = "Security group for Lambda functions (local dev)"

  # For local development, we use default VPC or create minimal networking
  # In production, this should reference the proper VPC

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-lambda-sg"
    Type = "SecurityGroup"
  })
}

# Placeholder for database configuration - using local PostgreSQL
# Connection details will be configured in environment variables for local development
locals {
  database_config = {
    host     = "localhost"
    port     = 5432
    database = "diagnyx_users"
    username = "diagnyx"
    password = "diagnyx123"
    engine   = "postgres"
  }
}

# Store local database configuration in Secrets Manager for Lambda functions
resource "aws_secretsmanager_secret" "local_db_config" {
  name        = "${local.name_prefix}/database/local-config"
  description = "Local database configuration for development"

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-local-db-config"
    Type = "Configuration"
  })
}

resource "aws_secretsmanager_secret_version" "local_db_config" {
  secret_id = aws_secretsmanager_secret.local_db_config.id
  secret_string = jsonencode(local.database_config)
}

# Lambda execution role will need permissions to access this secret
# This allows Lambda functions to connect to local database for development