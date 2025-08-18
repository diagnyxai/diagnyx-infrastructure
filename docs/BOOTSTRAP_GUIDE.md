# Bootstrap Setup Guide

This guide walks you through setting up the foundational AWS infrastructure for Diagnyx, which costs approximately **$12/month** until you deploy applications.

## Prerequisites

- AWS account with administrative access
- AWS CLI configured
- Terraform >= 1.5.0
- Unique email addresses for each AWS account (use email+alias@domain.com)

## Cost Overview

### Bootstrap Phase (~$12/month)
- KMS Keys: $5.00
- Secrets Manager: $6.00
- S3 Buckets: $0.50
- ECR (empty): $0.10
- Other: ~$0.40
- **Total: ~$12/month**

### Post-Deployment
- Development: +$78/month
- Staging: +$125/month
- Production: +$425/month

## Phase 1: AWS Organization Setup

### Step 1: Prepare Master Account

```bash
# Configure AWS CLI with master account
aws configure --profile diagnyx-master
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Default region: us-east-1
# Default output: json

# Verify access
aws sts get-caller-identity --profile diagnyx-master
```

### Step 2: Create Organization Structure

```bash
cd repositories/diagnyx-infra/terraform/bootstrap/01-organizations

# Initialize Terraform
terraform init

# Review what will be created
terraform plan

# Create organization and accounts (takes 5-10 minutes)
terraform apply
```

This creates:
- AWS Organization
- 5 member accounts (dev, staging, uat, production, shared)
- Organizational Units (OUs)
- Service Control Policies (SCPs)
- Cross-account IAM roles

### Step 3: Save Account IDs

```bash
# Save the account IDs from terraform output
terraform output account_ids > ../../../account_ids.json

# You'll need these for the next steps
cat ../../../account_ids.json
```

## Phase 2: Bootstrap Individual Accounts

### Step 4: Bootstrap Each Account

For each environment (dev, staging, uat, prod, shared):

```bash
cd ../02-account-bootstrap

# Create workspace for each environment
terraform workspace new dev
terraform workspace select dev

# Apply bootstrap configuration
terraform apply \
  -var="environment=development" \
  -var="account_id=<DEV_ACCOUNT_ID>" \
  -var="budget_alert_email=finance@diagnyx.ai"

# Repeat for other environments
terraform workspace new staging
terraform workspace select staging
terraform apply -var="environment=staging" ...
```

Each account gets:
- Terraform state S3 bucket
- DynamoDB lock table
- CloudWatch log groups
- Secrets Manager structure
- KMS encryption keys
- Budget alerts
- Cost anomaly detection

## Phase 3: Shared Services Setup

### Step 5: Configure Shared Services Account

```bash
cd ../03-shared-services

# Initialize
terraform init

# Apply shared services
terraform apply \
  -var="dev_account_id=<DEV_ID>" \
  -var="staging_account_id=<STAGING_ID>" \
  -var="uat_account_id=<UAT_ID>" \
  -var="prod_account_id=<PROD_ID>"
```

This creates:
- ECR repositories (shared across environments)
- ML model storage buckets
- Prompt library with versioning
- Parameter Store hierarchy
- Cross-account resource sharing

## Phase 4: Cost Management

### Step 6: Setup Cost Controls

```bash
cd ../04-cost-management

# Apply cost management for each account
for env in dev staging uat prod shared; do
  terraform workspace select $env
  terraform apply -var="environment=$env"
done
```

This configures:
- Monthly budget alerts
- Daily spike detection
- Cost anomaly detection
- Service-specific budgets (production only)

## Phase 5: SSO Configuration (Optional)

### Step 7: Enable AWS SSO

```bash
# In AWS Console:
# 1. Go to AWS SSO
# 2. Enable SSO
# 3. Configure identity source (AWS SSO or external IdP)

# Apply SSO configuration
cd ../01-organizations
terraform apply -target=module.sso_configuration
```

### Step 8: Create Users and Groups

In AWS SSO Console:
1. Add users or connect to Azure AD/Okta
2. Create groups: Administrators, Developers, Finance, Auditors
3. Assign permission sets to groups

## Phase 6: Verification

### Step 9: Verify Bootstrap

```bash
# Check organization structure
aws organizations describe-organization --profile diagnyx-master

# List accounts
aws organizations list-accounts --profile diagnyx-master

# Verify S3 buckets created
for account in dev staging uat prod shared; do
  echo "Checking $account..."
  aws s3 ls --profile diagnyx-$account 2>/dev/null | grep terraform-state
done

# Check ECR repositories
aws ecr describe-repositories \
  --region us-east-1 \
  --profile diagnyx-shared \
  --query 'repositories[].repositoryName'

# Verify secrets structure
aws secretsmanager list-secrets \
  --profile diagnyx-dev \
  --query 'SecretList[].Name'
```

## Bootstrap Costs Breakdown

### What You're Paying For

| Resource | Count | Cost/Month | Purpose |
|----------|-------|------------|---------|
| KMS Keys | 5 | $5.00 | Encryption at rest |
| Secrets (empty) | 15 | $6.00 | Pre-created structure |
| S3 Buckets | 10 | $0.50 | State, ML models, logs |
| ECR Storage | <500MB | $0.10 | Container images |
| CloudWatch | Minimal | $0.40 | Empty log groups |
| **Total** | | **$12.00** | |

### What's FREE

- AWS Organizations
- IAM Roles and Policies
- SSO Configuration
- Service Control Policies
- Parameter Store (standard)
- CloudTrail (first trail)
- Budget Alerts (2 per account)
- Cost Anomaly Detection

## Next Steps

### When Ready to Deploy (Month 4+)

1. **Deploy to Development First**
   ```bash
   cd ../../  # Back to main terraform directory
   terraform init -backend-config=backend-configs/dev.hcl
   terraform apply -var-file=environments/dev.tfvars
   ```

2. **Test Everything**
   - Verify services are running
   - Check auto-scaling
   - Test scheduled scaling

3. **Deploy to Other Environments**
   - Staging
   - UAT
   - Production

### Cost Optimization Tips

1. **Keep bootstrap minimal** - Don't create resources until needed
2. **Use scheduled scaling** - Configured to save 66% on non-prod
3. **Monitor budgets** - Alerts configured at 50%, 80%, 100%
4. **Review weekly** - Check Cost Explorer for anomalies

## Troubleshooting

### Account Creation Failed
```bash
# Check organization status
aws organizations describe-create-account-status \
  --create-account-request-id <REQUEST_ID>
```

### Permission Denied
```bash
# Verify role assumption works
aws sts assume-role \
  --role-arn arn:aws:iam::<ACCOUNT_ID>:role/OrganizationAccountAccessRole \
  --role-session-name test
```

### Terraform State Issues
```bash
# Reinitialize backend
terraform init -reconfigure

# Check state
terraform state list
```

## Rollback Procedure

If you need to undo the bootstrap:

```bash
# WARNING: This will delete everything!

# Remove accounts (cannot be undone!)
cd 01-organizations
terraform destroy

# Each account's resources
cd ../02-account-bootstrap
for env in dev staging uat prod shared; do
  terraform workspace select $env
  terraform destroy -var="environment=$env"
done
```

## Support

- Documentation: [diagnyx-infra/docs](../README.md)
- Slack: #infrastructure
- Email: infrastructure@diagnyx.ai

---

**Remember**: The bootstrap creates the foundation for ~$12/month. Actual application deployment will increase costs based on the environment and scale.