# Database Configuration - RDS PostgreSQL with Aurora Serverless v2 for non-production

locals {
  is_production = var.environment == "production"
  
  # Database subnet group - requires VPC to be created first
  db_subnet_group_name = var.environment == "production" ? 
    aws_db_subnet_group.main[0].name : 
    aws_db_subnet_group.main[0].name
}

# Security Group for ECS Services (if not already defined)
resource "aws_security_group" "ecs_services" {
  name_prefix = "${local.name_prefix}-ecs-services-"
  description = "Security group for ECS services"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description     = "HTTPS from ALB"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description     = "Custom ports from ALB"
    from_port       = 3000
    to_port         = 8443
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description = "All traffic within VPC"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ecs-services-sg"
  })
}

# Database Subnet Group
resource "aws_db_subnet_group" "main" {
  count      = 1
  name       = "${local.name_prefix}-db-subnet-group"
  subnet_ids = module.vpc.private_subnets

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-db-subnet-group"
  })
}

# Security Group for Database
resource "aws_security_group" "database" {
  name_prefix = "${local.name_prefix}-database-"
  description = "Security group for PostgreSQL database"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "PostgreSQL from ECS services"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_services.id]
  }

  ingress {
    description = "PostgreSQL within VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-database-sg"
  })
}

# RDS PostgreSQL Instance for all environments
# Production: Standard RDS with Multi-AZ
# Staging: Single AZ with smaller instance
# Dev: Smallest instance with minimal backup retention
resource "aws_db_instance" "main" {
  identifier = "${local.name_prefix}-postgres"

  # Engine configuration
  engine         = "postgres"
  engine_version = var.rds_engine_version
  # Environment-specific instance sizing for MVP
  instance_class = var.environment == "production" ? "db.t4g.small" : (
    var.environment == "uat" ? "db.t4g.micro" : "db.t4g.micro"
  )

  # Environment-specific storage sizing for MVP
  allocated_storage = var.environment == "production" ? 50 : (
    var.environment == "uat" ? 30 : 20
  )
  max_allocated_storage = var.environment == "production" ? 200 : (
    var.environment == "uat" ? 100 : 50
  )
  storage_type          = "gp3"
  storage_encrypted     = true

  # Database credentials
  db_name  = var.database_name
  username = var.database_master_username
  manage_master_user_password = true

  # Network configuration
  db_subnet_group_name   = aws_db_subnet_group.main[0].name
  vpc_security_group_ids = [aws_security_group.database.id]
  publicly_accessible    = false

  # Environment-specific backup configuration
  backup_retention_period = var.environment == "production" ? 7 : (
    var.environment == "uat" ? 3 : 1
  )
  backup_window          = "07:00-09:00"
  maintenance_window     = "sun:04:00-sun:06:00"

  # Environment-specific availability and monitoring
  multi_az = var.environment == "production" ? true : false  # Multi-AZ only for production

  # Performance monitoring for production and UAT
  performance_insights_enabled = (var.environment == "production" || var.environment == "uat") ? true : false
  performance_insights_retention_period = (var.environment == "production" || var.environment == "uat") ? 7 : null
  monitoring_interval = var.environment == "production" ? 60 : 0
  monitoring_role_arn = var.environment == "production" ? aws_iam_role.rds_enhanced_monitoring[0].arn : null

  # Environment-specific snapshot and protection settings
  skip_final_snapshot = (var.environment == "dev" || var.environment == "staging") ? true : false
  final_snapshot_identifier = (var.environment == "dev" || var.environment == "staging") ? null : "${local.name_prefix}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  deletion_protection = var.environment == "production" ? true : false

  # Parameter group for optimization
  parameter_group_name = aws_db_parameter_group.main.name

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-postgres"
    Type = "RDS-PostgreSQL"
    Environment = var.environment
  })
}

# DB Parameter Group for performance optimization
resource "aws_db_parameter_group" "main" {
  family = "postgres15"
  name   = "${local.name_prefix}-postgres15-params"

  parameter {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements"
  }

  parameter {
    name  = "log_statement"
    value = var.environment == "production" ? "ddl" : "all"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = var.environment == "production" ? "1000" : "100"  # Log slow queries
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-postgres-params"
  })
}

# Enhanced monitoring role for production RDS only

# Enhanced monitoring role for production RDS
resource "aws_iam_role" "rds_enhanced_monitoring" {
  count = local.is_production ? 1 : 0
  name  = "${local.name_prefix}-rds-enhanced-monitoring"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  count      = local.is_production ? 1 : 0
  role       = aws_iam_role.rds_enhanced_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# Database password secret (legacy - now using RDS managed secrets)
resource "aws_secretsmanager_secret" "db_password" {
  name        = "${local.name_prefix}/database/password"
  description = "Database master password (legacy)"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-db-password"
  })
}

# JWT Secret for application authentication
resource "aws_secretsmanager_secret" "jwt_secret" {
  name        = "${local.name_prefix}/app/jwt-secret"
  description = "JWT signing secret for application authentication"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-jwt-secret"
  })
}

resource "aws_secretsmanager_secret_version" "jwt_secret" {
  secret_id = aws_secretsmanager_secret.jwt_secret.id
  secret_string = jsonencode({
    secret = random_password.jwt_secret.result
  })
}

resource "random_password" "jwt_secret" {
  length  = 64
  special = true
}

# Outputs
output "database_endpoint" {
  description = "Database endpoint"
  value = aws_db_instance.main.endpoint
}

output "database_port" {
  description = "Database port"
  value = aws_db_instance.main.port
}

output "database_secret_arn" {
  description = "Database password secret ARN"
  value = aws_db_instance.main.master_user_secret[0].secret_arn
}

output "database_name" {
  description = "Database name"
  value = aws_db_instance.main.db_name
}

output "database_username" {
  description = "Database master username"
  value = aws_db_instance.main.username
  sensitive = true
}