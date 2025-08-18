#!/bin/bash
set -e

# Deploy IAM and bootstrap resources to specific account
# Usage: ./deploy-to-account.sh <environment>

ENVIRONMENT=$1

if [ -z "$ENVIRONMENT" ]; then
    echo "Usage: ./deploy-to-account.sh <environment>"
    echo "Environments: development, staging, uat, production, shared"
    exit 1
fi

# Load environment variables
source .env

# Set account ID based on environment
case $ENVIRONMENT in
    development)
        ACCOUNT_ID=$DEV_ACCOUNT_ID
        ;;
    staging)
        ACCOUNT_ID=$STAGING_ACCOUNT_ID
        ;;
    uat)
        ACCOUNT_ID=$UAT_ACCOUNT_ID
        ;;
    production)
        ACCOUNT_ID=$PROD_ACCOUNT_ID
        ;;
    shared)
        ACCOUNT_ID=$SHARED_ACCOUNT_ID
        ;;
    *)
        echo "Invalid environment: $ENVIRONMENT"
        exit 1
        ;;
esac

echo "========================================="
echo "Deploying to $ENVIRONMENT account"
echo "Account ID: $ACCOUNT_ID"
echo "========================================="

# Configure AWS credentials
export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION=us-east-1

# Assume role in target account
echo "Assuming role in $ENVIRONMENT account..."
CREDS=$(aws sts assume-role \
    --role-arn arn:aws:iam::${ACCOUNT_ID}:role/OrganizationAccountAccessRole \
    --role-session-name terraform-deployment \
    --duration-seconds 3600 \
    --output json 2>&1)

# Check if assume role succeeded
if [ $? -ne 0 ]; then
    echo "Failed to assume role. Error: $CREDS"
    echo "Checking caller identity..."
    aws sts get-caller-identity
    exit 1
fi

# Extract credentials
export AWS_ACCESS_KEY_ID=$(echo $CREDS | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo $CREDS | jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo $CREDS | jq -r '.Credentials.SessionToken')

echo "Successfully assumed role"

# Deploy account bootstrap
echo ""
echo "Deploying account bootstrap resources..."
cd 02-account-bootstrap

# Update tfvars for this environment
cat > terraform.tfvars <<EOF
environment = "$ENVIRONMENT"
assume_role_arn = ""
external_id = "$EXTERNAL_ID"
budget_alert_email = "$BUDGET_ALERT_EMAIL"
alarm_email = "$BUDGET_ALERT_EMAIL"
monthly_budget_limit = "$( [ "$ENVIRONMENT" == "production" ] && echo "50" || echo "25" )"

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
  "environment" = "$ENVIRONMENT"
}
EOF

# Update backend config
cat > backend-config.hcl <<EOF
bucket         = "diagnyx-terraform-state-master"
key            = "bootstrap/account-$ENVIRONMENT/terraform.tfstate"
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
echo "✅ $ENVIRONMENT account deployment complete!"
echo "========================================="
echo ""

# Return to bootstrap directory
cd ..

# Clear session token
unset AWS_SESSION_TOKEN