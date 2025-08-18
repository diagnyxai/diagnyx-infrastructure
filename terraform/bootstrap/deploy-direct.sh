#!/bin/bash
set -e

# Direct deployment script for account bootstrap
# This script deploys directly to the current account without role assumption

echo "========================================="
echo "Deploying Bootstrap Resources"
echo "========================================="

# Load environment variables
source .env

# Configure AWS
export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION=us-east-1

echo "Checking AWS identity..."
aws sts get-caller-identity

# Deploy account bootstrap
echo ""
echo "Deploying account bootstrap resources..."
cd 02-account-bootstrap

# Update tfvars for deployment
cat > terraform.tfvars <<EOF
environment = "master"
assume_role_arn = ""
external_id = "$EXTERNAL_ID"
budget_alert_email = "$BUDGET_ALERT_EMAIL"
alarm_email = "$BUDGET_ALERT_EMAIL"
monthly_budget_limit = "50"

ecr_repositories = [
  "user-service",
  "observability-service",
  "ai-quality-service",
  "optimization-service",
  "api-gateway",
  "dashboard-service",
  "diagnyx-ui"
]

initial_parameters = {
  "database_host" = "placeholder"
  "redis_host" = "placeholder"
  "environment" = "master"
}
EOF

# Update backend config
cat > backend-config.hcl <<EOF
bucket         = "diagnyx-terraform-state-778715730121"
key            = "bootstrap/account-master/terraform.tfstate"
region         = "us-east-1"
encrypt        = true
dynamodb_table = "diagnyx-terraform-locks-master"
EOF

# Initialize Terraform
echo "Initializing Terraform..."
terraform init -backend-config=backend-config.hcl -reconfigure

# Plan changes
echo "Planning changes..."
terraform plan -out=tfplan

# Apply changes
echo "Applying changes..."
terraform apply tfplan

echo ""
echo "========================================="
echo "✅ Bootstrap deployment complete!"
echo "========================================="
echo ""

# Return to bootstrap directory
cd ..