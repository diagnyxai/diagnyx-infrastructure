#!/bin/bash
set -e

# Bootstrap Initialization Script
# This script sets up the AWS environment for Terraform bootstrap

echo "========================================="
echo "   Diagnyx Infrastructure Bootstrap"
echo "   Region: us-east-1 (Required)"
echo "========================================="
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if .env file exists
if [ ! -f .env ]; then
    echo -e "${RED}Error: .env file not found!${NC}"
    echo "Please copy .env.example to .env and fill in your credentials:"
    echo "  cp .env.example .env"
    echo "  nano .env  # or use your preferred editor"
    exit 1
fi

# Load environment variables
set -a
source .env
set +a

# Validate required environment variables
required_vars=(
    "AWS_ACCESS_KEY_ID"
    "AWS_SECRET_ACCESS_KEY"
    "MASTER_ACCOUNT_EMAIL"
    "BUDGET_ALERT_EMAIL"
)

missing_vars=()
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        missing_vars+=($var)
    fi
done

if [ ${#missing_vars[@]} -gt 0 ]; then
    echo -e "${RED}Error: Missing required environment variables:${NC}"
    for var in "${missing_vars[@]}"; do
        echo "  - $var"
    done
    echo ""
    echo "Please edit .env file and provide all required values."
    exit 1
fi

# Test AWS credentials
echo "Testing AWS credentials..."
if aws sts get-caller-identity > /dev/null 2>&1; then
    echo -e "${GREEN}✓ AWS credentials are valid${NC}"
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    echo "  Account ID: $ACCOUNT_ID"
    USER_ARN=$(aws sts get-caller-identity --query Arn --output text)
    echo "  User ARN: $USER_ARN"
else
    echo -e "${RED}✗ AWS credentials are invalid${NC}"
    echo "Please check your AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY in .env"
    exit 1
fi

# Check AWS region
CURRENT_REGION=$(aws configure get region || echo "us-east-1")
if [ "$CURRENT_REGION" != "us-east-1" ]; then
    echo -e "${YELLOW}Warning: Setting region to us-east-1${NC}"
    export AWS_DEFAULT_REGION=us-east-1
    export AWS_REGION=us-east-1
fi

# Verify we're in us-east-1
echo ""
echo "Verifying region configuration..."
REGION=$(aws ec2 describe-availability-zones --query 'AvailabilityZones[0].RegionName' --output text 2>/dev/null || echo "us-east-1")
if [ "$REGION" == "us-east-1" ]; then
    echo -e "${GREEN}✓ Region confirmed: us-east-1${NC}"
else
    echo -e "${RED}✗ Error: Must use us-east-1 region${NC}"
    exit 1
fi

# Check for existing Organizations
echo ""
echo "Checking for existing AWS Organizations..."
if aws organizations describe-organization > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠ AWS Organization already exists${NC}"
    ORG_ID=$(aws organizations describe-organization --query 'Organization.Id' --output text)
    echo "  Organization ID: $ORG_ID"
    echo ""
    read -p "Do you want to continue with existing organization? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Bootstrap cancelled."
        exit 1
    fi
else
    echo "No existing organization found. Will create new one."
fi

# Create S3 bucket for Terraform state (master account)
echo ""
echo "Setting up Terraform state storage..."
STATE_BUCKET="${BOOTSTRAP_STATE_BUCKET_PREFIX}-master"
LOCK_TABLE="${BOOTSTRAP_LOCK_TABLE_PREFIX}-master"

# Check if bucket exists
if aws s3api head-bucket --bucket "$STATE_BUCKET" 2>/dev/null; then
    echo -e "${YELLOW}⚠ State bucket already exists: $STATE_BUCKET${NC}"
else
    echo "Creating S3 bucket for Terraform state: $STATE_BUCKET"
    aws s3api create-bucket \
        --bucket "$STATE_BUCKET" \
        --region us-east-1 \
        --acl private

    # Enable versioning
    aws s3api put-bucket-versioning \
        --bucket "$STATE_BUCKET" \
        --versioning-configuration Status=Enabled

    # Enable encryption
    aws s3api put-bucket-encryption \
        --bucket "$STATE_BUCKET" \
        --server-side-encryption-configuration '{
            "Rules": [{
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                }
            }]
        }'

    # Block public access
    aws s3api put-public-access-block \
        --bucket "$STATE_BUCKET" \
        --public-access-block-configuration \
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

    echo -e "${GREEN}✓ State bucket created successfully${NC}"
fi

# Create DynamoDB table for state locking
if aws dynamodb describe-table --table-name "$LOCK_TABLE" > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠ Lock table already exists: $LOCK_TABLE${NC}"
else
    echo "Creating DynamoDB table for state locking: $LOCK_TABLE"
    aws dynamodb create-table \
        --table-name "$LOCK_TABLE" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region us-east-1 \
        --tags Key=Project,Value=diagnyx Key=Component,Value=terraform Key=Environment,Value=master

    # Wait for table to be active
    echo "Waiting for table to be active..."
    aws dynamodb wait table-exists --table-name "$LOCK_TABLE"
    echo -e "${GREEN}✓ Lock table created successfully${NC}"
fi

# Create terraform.tfvars file for bootstrap
echo ""
echo "Creating Terraform variables file..."
cat > 01-organizations/terraform.tfvars <<EOF
# Auto-generated Terraform variables for bootstrap
# Generated on $(date)

master_account_email = "$MASTER_ACCOUNT_EMAIL"
organization_name    = "${ORGANIZATION_NAME:-diagnyx}"

# Account emails
dev_account_email    = "${DEV_ACCOUNT_EMAIL:-aws-dev@diagnyx.com}"
staging_account_email = "${STAGING_ACCOUNT_EMAIL:-aws-staging@diagnyx.com}"
uat_account_email    = "${UAT_ACCOUNT_EMAIL:-aws-uat@diagnyx.com}"
prod_account_email   = "${PROD_ACCOUNT_EMAIL:-aws-prod@diagnyx.com}"
shared_account_email = "${SHARED_ACCOUNT_EMAIL:-aws-shared@diagnyx.com}"

# Budget configuration
budget_alert_email = "$BUDGET_ALERT_EMAIL"

# State bucket and table (for reference)
terraform_state_bucket = "$STATE_BUCKET"
terraform_lock_table   = "$LOCK_TABLE"
EOF

echo -e "${GREEN}✓ Terraform variables file created${NC}"

# Create backend configuration
echo ""
echo "Creating backend configuration..."
cat > 01-organizations/backend.tf <<EOF
# Terraform backend configuration for Organizations bootstrap
terraform {
  backend "s3" {
    bucket         = "$STATE_BUCKET"
    key            = "bootstrap/organizations/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "$LOCK_TABLE"
  }
}
EOF

echo -e "${GREEN}✓ Backend configuration created${NC}"

# Summary
echo ""
echo "========================================="
echo -e "${GREEN}Bootstrap initialization complete!${NC}"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Review the generated terraform.tfvars file"
echo "2. Run the bootstrap script: ./run-bootstrap.sh"
echo ""
echo "State Management:"
echo "  Bucket: $STATE_BUCKET"
echo "  Lock Table: $LOCK_TABLE"
echo "  Region: us-east-1"
echo ""
echo -e "${YELLOW}Important: Keep your .env file secure and never commit it!${NC}"