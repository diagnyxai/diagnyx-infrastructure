# Diagnyx Multi-Account AWS Deployment Guide

## Overview

This guide provides step-by-step instructions for deploying the Diagnyx platform across multiple AWS accounts, ensuring proper security isolation, cost optimization, and compliance while maintaining minimal overhead costs.

## Account Structure

```
AWS Organization (Master Account)
├── Security OU
│   └── Security Account (Audit, Logs, Compliance)
├── Production OU
│   └── Production Account (Production workloads)
├── NonProduction OU
│   ├── Development Account
│   ├── Staging Account
│   └── UAT Account
└── SharedServices OU
    └── Shared Services Account (ECR, Route53, Shared Resources)
```

## Cost Overview

### One-Time Setup Costs (Minimal)
- **S3 Buckets**: ~$0.023/GB for Terraform state
- **DynamoDB Tables**: Pay-per-request model (< $1/month)
- **Route53 Hosted Zones**: $0.50/month per zone
- **ACM Certificates**: FREE

### No Additional Costs
- **AWS Organizations**: FREE
- **AWS SSO**: FREE
- **IAM Roles/Policies**: FREE
- **CloudTrail** (first trail): FREE
- **Budget Alerts**: FREE (up to 2 per account)
- **Cost Allocation Tags**: FREE

## Prerequisites

1. **Master AWS Account** with billing enabled
2. **Unique email addresses** for each account (use email+alias@domain.com)
3. **AWS CLI** configured with master account credentials
4. **Terraform** >= 1.5.0 installed
5. **Administrative access** to the master account

## Phase 1: Bootstrap AWS Organization

### Step 1: Create Organization Structure

```bash
cd terraform/bootstrap

# Initialize Terraform
terraform init

# Review the organization structure
terraform plan

# Create organization and accounts
terraform apply
```

This creates:
- AWS Organization with all OUs
- All member accounts (dev, staging, uat, prod, shared, security)
- Service Control Policies for cost control
- Tag policies for compliance

**Note**: New accounts may take 5-10 minutes to be fully created.

### Step 2: Note Account IDs

After creation, save the account IDs:

```bash
terraform output account_ids > account_ids.txt
```

Update all `.tfvars` files with actual account IDs:
```hcl
master_account_id          = "111111111111"  # Replace
shared_services_account_id = "222222222222"  # Replace
security_account_id        = "333333333333"  # Replace
dev_account_id            = "444444444444"  # Replace
staging_account_id        = "555555555555"  # Replace
uat_account_id            = "666666666666"  # Replace
prod_account_id           = "777777777777"  # Replace
```

## Phase 2: Bootstrap Individual Accounts

### Step 3: Bootstrap Each Account

For each account (dev, staging, uat, prod, shared, security):

```bash
# Assume role in target account
aws sts assume-role \
  --role-arn arn:aws:iam::ACCOUNT_ID:role/OrganizationAccountAccessRole \
  --role-session-name bootstrap \
  --duration-seconds 3600

# Export credentials
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_SESSION_TOKEN=...

# Run bootstrap module
cd terraform/bootstrap/account-bootstrap

terraform init
terraform apply \
  -var="environment=development" \
  -var="alarm_email=ops@diagnyx.ai" \
  -var="budget_alert_email=finance@diagnyx.ai" \
  -var="monthly_budget_limit=200"
```

This creates in each account:
- S3 bucket for Terraform state
- DynamoDB table for state locking
- CloudTrail for audit
- KMS keys for encryption
- SNS topics for alerts
- Budget alerts
- ECR repositories

### Step 4: Configure Shared Services

Deploy shared services account resources:

```bash
# Assume role in shared services account
aws sts assume-role \
  --role-arn arn:aws:iam::SHARED_ACCOUNT_ID:role/OrganizationAccountAccessRole \
  --role-session-name shared-setup

cd terraform/bootstrap/shared-services

terraform init
terraform apply \
  -var="dev_account_id=444444444444" \
  -var="staging_account_id=555555555555" \
  -var="uat_account_id=666666666666" \
  -var="prod_account_id=777777777777"
```

## Phase 3: Configure SSO Access

### Step 5: Enable AWS SSO

```bash
cd terraform/bootstrap

# Apply SSO configuration
terraform apply -target=module.sso_configuration
```

### Step 6: Create SSO Users

1. Navigate to AWS SSO Console
2. Add users or configure external IdP (Azure AD, Okta, etc.)
3. Assign users to groups created by Terraform

### Step 7: Test SSO Access

```bash
# Get SSO portal URL
terraform output sso_portal_url

# Access portal and verify login
# Portal URL: https://your-org.awsapps.com/start
```

## Phase 4: Deploy Infrastructure

### Step 8: Deploy to Development

```bash
cd terraform

# Initialize with dev backend
terraform init -backend-config=backend-configs/dev.hcl

# Deploy infrastructure
terraform apply -var-file=environments/dev.tfvars
```

### Step 9: Deploy to Staging

```bash
# Re-initialize for staging
terraform init -backend-config=backend-configs/staging.hcl -reconfigure

# Deploy infrastructure
terraform apply -var-file=environments/staging.tfvars
```

### Step 10: Deploy to Production

```bash
# Re-initialize for production
terraform init -backend-config=backend-configs/production.hcl -reconfigure

# Review changes carefully
terraform plan -var-file=environments/production.tfvars

# Deploy with approval
terraform apply -var-file=environments/production.tfvars
```

## CI/CD Integration

### GitHub Actions Setup

```yaml
name: Deploy to AWS

on:
  push:
    branches:
      - main  # Production
      - staging
      - develop  # Development

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          role-to-assume: arn:aws:iam::${{ secrets.ACCOUNT_ID }}:role/DiagnyxCrossAccountCICD
          aws-region: us-east-1
      
      - name: Terraform Init
        run: |
          terraform init \
            -backend-config=backend-configs/${{ github.ref_name }}.hcl
      
      - name: Terraform Apply
        run: |
          terraform apply \
            -var-file=environments/${{ github.ref_name }}.tfvars \
            -auto-approve
```

## Cost Management

### Budget Limits by Account

| Account | Monthly Budget | Alert Threshold |
|---------|---------------|-----------------|
| Development | $200 | 80% |
| Staging | $400 | 80% |
| UAT | $300 | 80% |
| Production | $1,800 | 80% |
| Shared Services | $100 | 80% |
| Security | $50 | 80% |
| **Total** | **$2,850** | |

### Cost Monitoring

1. **Consolidated Billing**: View all costs in master account
2. **Budget Alerts**: Automatic emails at 50%, 80%, 100%
3. **Cost Anomaly Detection**: Daily monitoring for unusual spending
4. **Cost Explorer Access**: Cross-account role for cost analysis

```bash
# Assume cost management role
aws sts assume-role \
  --role-arn arn:aws:iam::MASTER_ACCOUNT:role/DiagnyxCostExplorerAccess \
  --role-session-name cost-analysis

# Get cost report
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics UnblendedCost \
  --group-by Type=DIMENSION,Key=LINKED_ACCOUNT
```

## Security Best Practices

### 1. MFA Requirements
- Required for production access
- Required for administrative operations
- Enforced via SCP policies

### 2. Least Privilege Access
- Developers: No production access
- DevOps: Deployment access only
- Finance: Billing access only
- Auditors: Read-only access

### 3. Audit Trail
- CloudTrail enabled in all accounts
- Logs centralized to security account
- 7-year retention for production

### 4. Network Isolation
- Separate VPCs per account
- No direct connectivity between environments
- VPC peering only where necessary

## Troubleshooting

### Account Creation Issues

```bash
# Check organization status
aws organizations describe-organization

# List accounts
aws organizations list-accounts

# Check account status
aws organizations describe-account --account-id ACCOUNT_ID
```

### SSO Access Issues

```bash
# List permission sets
aws sso-admin list-permission-sets \
  --instance-arn $(aws sso-admin list-instances --query "Instances[0].InstanceArn" --output text)

# Check assignments
aws sso-admin list-account-assignments \
  --instance-arn $(aws sso-admin list-instances --query "Instances[0].InstanceArn" --output text) \
  --account-id ACCOUNT_ID \
  --permission-set-arn PERMISSION_SET_ARN
```

### Cross-Account Access Issues

```bash
# Test role assumption
aws sts assume-role \
  --role-arn arn:aws:iam::TARGET_ACCOUNT:role/DiagnyxCrossAccountCICD \
  --role-session-name test \
  --external-id diagnyx-secure-external-id-2024

# Verify credentials
aws sts get-caller-identity
```

## Maintenance Tasks

### Weekly
- Review cost anomaly reports
- Check unused resources
- Verify backup completion

### Monthly
- Review budget vs actual spend
- Audit IAM permissions
- Update SSO group memberships
- Review and apply security patches

### Quarterly
- Review SCPs and policies
- Audit cross-account roles
- Update Reserved Instance coverage
- Security assessment

## Rollback Procedures

### Infrastructure Rollback

```bash
# Revert to previous version
terraform apply -var-file=environments/production.tfvars \
  -target=module.problematic_module \
  -replace=resource.problematic_resource
```

### Account Isolation

```bash
# Remove cross-account access
aws iam delete-role-policy --role-name DiagnyxCrossAccountCICD --policy-name CICDPolicy

# Disable SSO access
aws sso-admin delete-account-assignment \
  --instance-arn INSTANCE_ARN \
  --target-id ACCOUNT_ID \
  --target-type AWS_ACCOUNT \
  --permission-set-arn PERMISSION_SET_ARN \
  --principal-type GROUP \
  --principal-id GROUP_ID
```

## Support Contacts

- **AWS Support**: Available via AWS Console
- **Infrastructure Team**: infrastructure@diagnyx.ai
- **Security Team**: security@diagnyx.ai
- **Finance/Billing**: finance@diagnyx.ai

## Appendix: Account Bootstrap Checklist

For each new account:

- [ ] Account created in AWS Organizations
- [ ] Moved to correct OU
- [ ] SCPs applied
- [ ] Bootstrap module deployed
- [ ] Terraform state bucket created
- [ ] CloudTrail enabled
- [ ] Budget alerts configured
- [ ] Cross-account roles created
- [ ] SSO access configured
- [ ] ECR repositories created
- [ ] KMS keys created
- [ ] Cost allocation tags activated
- [ ] Monitoring enabled
- [ ] Documentation updated

## Next Steps

1. Complete account bootstrap for all environments
2. Deploy application infrastructure to development
3. Configure CI/CD pipelines
4. Set up monitoring dashboards
5. Conduct security review
6. Plan production deployment