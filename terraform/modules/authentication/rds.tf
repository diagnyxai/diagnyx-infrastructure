# RDS PostgreSQL Configuration for Shared Database
# This creates a single RDS instance to host multiple databases for all microservices

# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${local.name_prefix}-db-subnet-group"
  subnet_ids = var.environment == "production" ? data.aws_subnets.private.ids : data.aws_subnets.private.ids

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-db-subnet-group"
    Type = "Database"
  })
}

# Data source for private subnets (these should be created by the main VPC module)
data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }

  filter {
    name   = "tag:Type"
    values = ["private"]
  }
}

# Data source for VPC
data "aws_vpc" "main" {
  filter {
    name   = "tag:Name"
    values = ["${var.project_name}-${var.environment}-vpc"]
  }
}

# Security Group for RDS
resource "aws_security_group" "rds" {
  name_prefix = "${local.name_prefix}-rds-sg"
  vpc_id      = data.aws_vpc.main.id
  description = "Security group for RDS PostgreSQL instance"

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = var.ecs_services_security_group_id != "" ? [var.ecs_services_security_group_id] : []
    description     = "PostgreSQL access from ECS services"
  }

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda.id]
    description     = "PostgreSQL access from Lambda functions"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-rds-sg"
    Type = "SecurityGroup"
  })
}

# Security Group for ECS Services will be passed as variable

# Security Group for Lambda functions
resource "aws_security_group" "lambda" {
  name_prefix = "${local.name_prefix}-lambda-sg"
  vpc_id      = data.aws_vpc.main.id
  description = "Security group for Lambda functions"

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

# Generate random password for RDS master user
resource "random_password" "rds_master_password" {
  length  = 32
  special = true
}

# RDS Parameter Group for PostgreSQL optimization
resource "aws_db_parameter_group" "main" {
  family = "postgres15"
  name   = "${local.name_prefix}-db-params"

  # Optimizations for multi-database workload
  parameter {
    name  = "shared_buffers"
    value = "{DBInstanceClassMemory/32768}"
  }

  parameter {
    name  = "effective_cache_size"
    value = "{DBInstanceClassMemory/16384}"
  }

  parameter {
    name  = "maintenance_work_mem"
    value = "64MB"
  }

  parameter {
    name  = "checkpoint_completion_target"
    value = "0.7"
  }

  parameter {
    name  = "wal_buffers"
    value = "16MB"
  }

  parameter {
    name  = "default_statistics_target"
    value = "100"
  }

  parameter {
    name  = "log_statement"
    value = "mod"
  }

  parameter {
    name  = "log_duration"
    value = "1"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"  # Log queries taking more than 1 second
  }

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-db-params"
    Type = "Database"
  })
}

# Main RDS Instance
resource "aws_db_instance" "main" {
  identifier     = "${local.name_prefix}-postgres"
  engine         = "postgres"
  engine_version = "15.4"
  
  instance_class        = var.environment == "production" ? "db.t4g.large" : "db.t4g.medium"
  allocated_storage     = 50
  max_allocated_storage = var.environment == "production" ? 500 : 200
  storage_type          = "gp3"
  storage_encrypted     = true

  # Database Configuration
  db_name  = var.database_name
  username = var.database_master_username
  password = random_password.rds_master_password.result

  # Network & Security
  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
  publicly_accessible    = false

  # Backup Configuration
  backup_retention_period = var.environment == "production" ? 30 : 7
  backup_window          = "03:00-04:00"  # UTC
  maintenance_window     = "sun:04:00-sun:05:00"  # UTC
  
  # High Availability
  multi_az = var.environment == "production" ? true : false

  # Parameter Group
  parameter_group_name = aws_db_parameter_group.main.name

  # Monitoring
  monitoring_interval                   = var.environment == "production" ? 60 : 0
  monitoring_role_arn                  = var.environment == "production" ? aws_iam_role.rds_monitoring_role.arn : null
  enabled_cloudwatch_logs_exports      = ["postgresql"]
  performance_insights_enabled         = var.environment == "production" ? true : false
  performance_insights_retention_period = var.environment == "production" ? 7 : null

  # Deletion Protection
  deletion_protection = var.environment == "production" ? true : false
  skip_final_snapshot = var.environment != "production"
  final_snapshot_identifier = var.environment == "production" ? "${local.name_prefix}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}" : null

  # Auto Minor Version Upgrade
  auto_minor_version_upgrade = false

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-postgres"
    Type = "Database"
  })

  depends_on = [
    aws_cloudwatch_log_group.rds_logs
  ]
}

# CloudWatch Log Group for RDS logs
resource "aws_cloudwatch_log_group" "rds_logs" {
  name              = "/aws/rds/instance/${local.name_prefix}-postgres/postgresql"
  retention_in_days = var.environment == "production" ? 30 : 14

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-rds-logs"
    Type = "Logs"
  })
}

# Store RDS credentials in Secrets Manager
resource "aws_secretsmanager_secret" "rds_master_credentials" {
  name        = "${local.name_prefix}/rds/master-credentials"
  description = "Master credentials for RDS PostgreSQL instance"

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-rds-master-credentials"
    Type = "Credentials"
  })
}

resource "aws_secretsmanager_secret_version" "rds_master_credentials" {
  secret_id = aws_secretsmanager_secret.rds_master_credentials.id
  secret_string = jsonencode({
    host     = aws_db_instance.main.endpoint
    port     = aws_db_instance.main.port
    username = aws_db_instance.main.username
    password = random_password.rds_master_password.result
    database = aws_db_instance.main.db_name
    engine   = "postgres"
  })
}

# Create individual database credentials for each service
resource "random_password" "user_service_password" {
  length  = 32
  special = true
}

resource "aws_secretsmanager_secret" "user_service_db_credentials" {
  name        = "${local.name_prefix}/database/user-service"
  description = "Database credentials for user service"

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-user-service-db-credentials"
    Type = "Credentials"
  })
}

resource "aws_secretsmanager_secret_version" "user_service_db_credentials" {
  secret_id = aws_secretsmanager_secret.user_service_db_credentials.id
  secret_string = jsonencode({
    host     = aws_db_instance.main.endpoint
    port     = aws_db_instance.main.port
    username = "user_service"
    password = random_password.user_service_password.result
    database = "diagnyx_users"
    engine   = "postgres"
  })
}