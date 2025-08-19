#!/bin/bash

# Script to populate AWS Secrets Manager with actual secret values
# This should be run once per environment after Terraform creates the secret structure
# Usage: ./populate-secrets.sh <environment> [region]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if environment is provided
if [ $# -lt 1 ]; then
    echo -e "${RED}Error: Environment not specified${NC}"
    echo "Usage: $0 <environment> [region]"
    echo "Environment must be: dev, staging, or prod"
    exit 1
fi

ENVIRONMENT=$1
AWS_REGION=${2:-us-east-1}
PROJECT_NAME="diagnyx"

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    echo -e "${RED}Error: Invalid environment '$ENVIRONMENT'${NC}"
    echo "Environment must be: dev, staging, or prod"
    exit 1
fi

echo -e "${GREEN}=== Diagnyx Secrets Population Script ===${NC}"
echo -e "Environment: ${YELLOW}$ENVIRONMENT${NC}"
echo -e "Region: ${YELLOW}$AWS_REGION${NC}"
echo ""

# Function to generate a secure random password
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

# Function to generate a secure API key
generate_api_key() {
    echo "${PROJECT_NAME}_${ENVIRONMENT}_$(openssl rand -hex 16)"
}

# Function to update or create a secret
update_secret() {
    local secret_name=$1
    local secret_value=$2
    local description=$3
    
    echo -n "Updating secret: $secret_name... "
    
    # Check if running in CI/CD or interactive mode
    if [ -z "$CI" ]; then
        # Interactive mode - ask for confirmation
        echo ""
        echo -e "${YELLOW}Value: [hidden]${NC}"
        read -p "Update this secret? (y/n): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Skipped${NC}"
            return
        fi
    fi
    
    # Update the secret in AWS Secrets Manager
    aws secretsmanager put-secret-value \
        --secret-id "${PROJECT_NAME}/${ENVIRONMENT}/${secret_name}" \
        --secret-string "{\"value\":\"${secret_value}\",\"description\":\"${description}\",\"updated_at\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" \
        --region "$AWS_REGION" \
        --output text > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC}"
        echo -e "${RED}Failed to update secret: $secret_name${NC}"
    fi
}

# Confirm before proceeding
if [ -z "$CI" ]; then
    echo -e "${YELLOW}WARNING: This will update secrets in AWS Secrets Manager for the $ENVIRONMENT environment.${NC}"
    read -p "Do you want to continue? (yes/no): " -r
    if [[ ! $REPLY == "yes" ]]; then
        echo "Aborted."
        exit 0
    fi
    echo ""
fi

echo "Generating and updating secrets..."
echo ""

# Common secrets for simplified architecture
echo -e "${GREEN}[Common Secrets]${NC}"

# Database credentials
update_secret "database/password" "$(generate_password)" "PostgreSQL database password"

# JWT secrets for authentication
update_secret "jwt/secret" "$(openssl rand -base64 64 | tr -d '\n')" "JWT signing secret"

echo ""
echo -e "${GREEN}[User Service Secrets]${NC}"
# User service specific secrets
update_secret "user-service/api-key" "$(generate_api_key)" "User service internal API key"

echo ""
echo -e "${GREEN}[API Gateway Secrets]${NC}"
# API Gateway specific secrets
update_secret "api-gateway/rate-limit-key" "$(generate_api_key)" "API Gateway rate limiting key"

echo ""
echo -e "${GREEN}[External Service API Keys]${NC}"
# Optional external service keys (leave blank if not used)
echo -e "${YELLOW}Note: The following are optional. Leave blank if not using these services.${NC}"

read -p "OpenAI API Key (optional): " OPENAI_KEY
if [ ! -z "$OPENAI_KEY" ]; then
    update_secret "external/openai-api-key" "$OPENAI_KEY" "OpenAI API key for LLM integrations"
fi

read -p "Anthropic API Key (optional): " ANTHROPIC_KEY
if [ ! -z "$ANTHROPIC_KEY" ]; then
    update_secret "external/anthropic-api-key" "$ANTHROPIC_KEY" "Anthropic API key for Claude integrations"
fi

echo ""
echo -e "${GREEN}=== Secrets population completed ===${NC}"
echo -e "${YELLOW}Note: Simplified architecture - removed secrets for:${NC}"
echo -e "${YELLOW}- Redis (removed from platform)${NC}"
echo -e "${YELLOW}- Observability service (removed)${NC}"
echo -e "${YELLOW}- AI quality service (removed)${NC}"
echo -e "${YELLOW}- Optimization service (removed)${NC}"
echo -e "${YELLOW}- Dashboard service (removed)${NC}"
echo ""
echo -e "${GREEN}Total secrets created: 3-7 (depending on external services)${NC}"

echo ""
echo -e "${GREEN}Next steps:${NC}"
echo "1. Update service configurations to use AWS Secrets Manager"
echo "2. Remove any hardcoded secrets from code and configuration files"
echo "3. Test services with the new secret configuration"
echo "4. Set up secret rotation if needed"
echo ""

if [ "$ENVIRONMENT" != "dev" ]; then
    echo -e "${YELLOW}IMPORTANT: For $ENVIRONMENT environment:${NC}"
    echo "- Replace placeholder API keys with actual values"
    echo "- Enable secret rotation for production secrets"
    echo "- Set up CloudWatch alarms for secret access"
    echo ""
fi