#!/bin/bash
set -e

# Diagnyx Infrastructure Bootstrap Execution Script
# This script runs the Terraform bootstrap in the correct order

echo "========================================="
echo "   Diagnyx Bootstrap Execution"
echo "   Starting at: $(date)"
echo "========================================="
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Load environment variables
if [ ! -f .env ]; then
    echo -e "${RED}Error: .env file not found!${NC}"
    echo "Please run ./init-bootstrap.sh first"
    exit 1
fi

set -a
source .env
set +a

# Ensure we're in us-east-1
export AWS_DEFAULT_REGION=us-east-1
export AWS_REGION=us-east-1

# Function to run terraform in a directory
run_terraform() {
    local dir=$1
    local description=$2
    
    echo ""
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}$description${NC}"
    echo -e "${BLUE}=========================================${NC}"
    
    cd "$dir"
    
    # Initialize Terraform
    echo "Initializing Terraform..."
    terraform init -upgrade
    
    # Validate configuration
    echo "Validating configuration..."
    terraform validate
    
    # Plan the changes
    echo "Planning changes..."
    terraform plan -out=tfplan
    
    # Show the plan
    echo ""
    echo -e "${YELLOW}Review the plan above. ${NC}"
    read -p "Do you want to apply these changes? (yes/no): " -r
    
    if [[ $REPLY == "yes" ]]; then
        echo "Applying changes..."
        terraform apply tfplan
        echo -e "${GREEN}✓ $description completed successfully${NC}"
        
        # Save outputs if any
        if terraform output -json > /dev/null 2>&1; then
            terraform output -json > outputs.json
            echo "Outputs saved to outputs.json"
        fi
    else
        echo -e "${YELLOW}Skipping $description${NC}"
        rm tfplan
    fi
    
    cd ..
}

# Function to extract account IDs from Organizations output
extract_account_ids() {
    if [ -f "01-organizations/outputs.json" ]; then
        export DEV_ACCOUNT_ID=$(jq -r '.dev_account_id.value' 01-organizations/outputs.json)
        export STAGING_ACCOUNT_ID=$(jq -r '.staging_account_id.value' 01-organizations/outputs.json)
        export UAT_ACCOUNT_ID=$(jq -r '.uat_account_id.value' 01-organizations/outputs.json)
        export PROD_ACCOUNT_ID=$(jq -r '.prod_account_id.value' 01-organizations/outputs.json)
        export SHARED_ACCOUNT_ID=$(jq -r '.shared_services_account_id.value' 01-organizations/outputs.json)
        export MASTER_ACCOUNT_ID=$(jq -r '.master_account_id.value' 01-organizations/outputs.json)
        
        echo "Account IDs extracted:"
        echo "  Development: $DEV_ACCOUNT_ID"
        echo "  Staging: $STAGING_ACCOUNT_ID"
        echo "  UAT: $UAT_ACCOUNT_ID"
        echo "  Production: $PROD_ACCOUNT_ID"
        echo "  Shared Services: $SHARED_ACCOUNT_ID"
        echo "  Master: $MASTER_ACCOUNT_ID"
    else
        echo -e "${RED}Warning: Could not extract account IDs${NC}"
    fi
}

# Step 1: AWS Organizations
if [ -d "01-organizations" ]; then
    run_terraform "01-organizations" "Step 1: AWS Organizations Setup"
    extract_account_ids
else
    echo -e "${YELLOW}Skipping Organizations setup (directory not found)${NC}"
fi

# Step 2: Bootstrap each account
if [ -d "02-account-bootstrap" ]; then
    # Bootstrap each environment account
    for env in development staging uat production shared; do
        echo ""
        echo -e "${BLUE}Bootstrapping $env account...${NC}"
        
        # Get the account ID for this environment
        case $env in
            development) ACCOUNT_ID=$DEV_ACCOUNT_ID ;;
            staging) ACCOUNT_ID=$STAGING_ACCOUNT_ID ;;
            uat) ACCOUNT_ID=$UAT_ACCOUNT_ID ;;
            production) ACCOUNT_ID=$PROD_ACCOUNT_ID ;;
            shared) ACCOUNT_ID=$SHARED_ACCOUNT_ID ;;
        esac
        
        if [ -z "$ACCOUNT_ID" ]; then
            echo -e "${YELLOW}Skipping $env (no account ID)${NC}"
            continue
        fi
        
        # Create tfvars for this environment
        cat > 02-account-bootstrap/terraform.tfvars <<EOF
environment = "$env"
assume_role_arn = "arn:aws:iam::${ACCOUNT_ID}:role/OrganizationAccountAccessRole"
external_id = "${EXTERNAL_ID:-diagnyx-bootstrap-2024}"
EOF
        
        # Create backend config for this environment
        cat > 02-account-bootstrap/backend-config.hcl <<EOF
bucket         = "${BOOTSTRAP_STATE_BUCKET_PREFIX}-${env}"
key            = "bootstrap/account/terraform.tfstate"
region         = "us-east-1"
encrypt        = true
dynamodb_table = "${BOOTSTRAP_LOCK_TABLE_PREFIX}-${env}"
EOF
        
        cd 02-account-bootstrap
        
        # Initialize with backend config
        echo "Initializing Terraform for $env..."
        terraform init -backend-config=backend-config.hcl -reconfigure
        
        # Plan and apply
        echo "Planning changes for $env..."
        terraform plan -out=tfplan
        
        echo ""
        read -p "Apply bootstrap for $env account? (yes/no): " -r
        if [[ $REPLY == "yes" ]]; then
            terraform apply tfplan
            echo -e "${GREEN}✓ $env account bootstrapped${NC}"
        else
            echo -e "${YELLOW}Skipped $env bootstrap${NC}"
        fi
        
        cd ..
    done
else
    echo -e "${YELLOW}Skipping account bootstrap (directory not found)${NC}"
fi

# Step 3: Shared Services
if [ -d "03-shared-services" ] && [ ! -z "$SHARED_ACCOUNT_ID" ]; then
    # Create tfvars for shared services
    cat > 03-shared-services/terraform.tfvars <<EOF
assume_role_arn = "arn:aws:iam::${SHARED_ACCOUNT_ID}:role/OrganizationAccountAccessRole"
external_id = "${EXTERNAL_ID:-diagnyx-bootstrap-2024}"
master_account_id = "$MASTER_ACCOUNT_ID"
dev_account_id = "$DEV_ACCOUNT_ID"
staging_account_id = "$STAGING_ACCOUNT_ID"
uat_account_id = "$UAT_ACCOUNT_ID"
prod_account_id = "$PROD_ACCOUNT_ID"
EOF
    
    run_terraform "03-shared-services" "Step 3: Shared Services Setup"
else
    echo -e "${YELLOW}Skipping shared services (directory not found or no account ID)${NC}"
fi

# Step 4: Cost Management
if [ -d "04-cost-management" ]; then
    # Create tfvars for cost management
    cat > 04-cost-management/terraform.tfvars <<EOF
environment = "master"
budget_alert_email = "$BUDGET_ALERT_EMAIL"

# Account IDs for budget setup
account_ids = {
  development = "$DEV_ACCOUNT_ID"
  staging     = "$STAGING_ACCOUNT_ID"
  uat         = "$UAT_ACCOUNT_ID"
  production  = "$PROD_ACCOUNT_ID"
  shared      = "$SHARED_ACCOUNT_ID"
}

# Budget limits
budget_limits = {
  development = 25
  staging     = 25
  uat         = 25
  production  = 50
  shared      = 25
}
EOF
    
    run_terraform "04-cost-management" "Step 4: Cost Management Setup"
else
    echo -e "${YELLOW}Skipping cost management (directory not found)${NC}"
fi

# Summary
echo ""
echo "========================================="
echo -e "${GREEN}Bootstrap Execution Complete!${NC}"
echo "========================================="
echo ""
echo "Resources Created:"
echo "✓ AWS Organization with 5 accounts"
echo "✓ Service Control Policies for governance"
echo "✓ Cross-account IAM roles"
echo "✓ S3 buckets for Terraform state"
echo "✓ DynamoDB tables for state locking"
echo "✓ Secrets Manager for application secrets"
echo "✓ CloudWatch log groups"
echo "✓ ECR repositories (in shared account)"
echo "✓ Budget alerts ($25 for non-prod, $50 for prod)"
echo "✓ Automatic spending controls"
echo ""
echo "Next Steps:"
echo "1. Deploy ECS infrastructure to each environment:"
echo "   cd ../../"
echo "   ./deploy-environment.sh development"
echo ""
echo "2. Configure CI/CD pipeline with the cross-account roles"
echo ""
echo "3. Update DNS records to point to the load balancers"
echo ""
echo -e "${YELLOW}Important: Save the account IDs from 01-organizations/outputs.json${NC}"
echo ""
echo "Completed at: $(date)"