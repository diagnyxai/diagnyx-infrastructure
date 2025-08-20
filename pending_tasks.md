# Pending Bootstrap Tasks for Diagnyx Infrastructure

## 🔴 Critical Missing Items

### 1. AWS Organizations & Member Accounts NOT Created
- The organization exists but **NO member accounts** were created (dev, staging, UAT, prod, shared)
- Only 2 accounts exist: master account (321161022183) and an old suspended account
- The documented account IDs (215726089610, 435455014599, etc.) don't actually exist

### 2. Wrong Master Account ID Configuration
- Configuration uses 778715730121 but actual account is 321161022183
- This mismatch prevents proper deployment

### 3. Modules NOT Deployed
- ❌ **01-organizations**: AWS Organization structure and member accounts
- ❌ **03-shared-services**: Shared ECR repositories and parameter store
- ❌ **04-cost-management**: Organization-wide budgets and alerts
- ❌ **05-iam-github-oidc**: GitHub Actions OIDC provider

### 4. Only Partial Bootstrap Completed
- ✅ **00-backend**: S3 bucket and DynamoDB table (created)
- ✅ **02-account-bootstrap**: IAM roles and policies (created in master account only)

## 📋 Complete Bootstrap Plan

### Phase 1: Create AWS Organization Structure
**Directory**: `terraform/bootstrap/01-organizations`
- [ ] Fix master account ID from 778715730121 to 321161022183
- [ ] Deploy to create 5 member accounts:
  - diagnyx-development
  - diagnyx-staging
  - diagnyx-uat
  - diagnyx-production
  - diagnyx-shared-services
- [ ] Create Organizational Units:
  - Production OU
  - NonProduction OU
  - Shared OU
- [ ] Apply Service Control Policies:
  - Cost control policy (restrict instance types)
  - Region restriction policy (us-east-1 only)

### Phase 2: Deploy Shared Services
**Directory**: `terraform/bootstrap/03-shared-services`
- [ ] Deploy to shared services account once created
- [ ] Create ECR repositories for all microservices:
  - user-service
  - api-gateway
  - diagnyx-ui
- [ ] Set up shared parameter store configuration
- [ ] Create S3 buckets for ML model storage

### Phase 3: Set Up Cost Management
**Directory**: `terraform/bootstrap/04-cost-management`
- [ ] Deploy organization-wide budget configuration
- [ ] Set account-specific budgets:
  - Development: $25/month
  - Staging: $25/month
  - UAT: $25/month
  - Production: $50/month
  - Shared: $25/month
- [ ] Configure budget alerts to admin@diagnyx.com
- [ ] Set up daily cost check automation

### Phase 4: Configure GitHub OIDC
**Directory**: `terraform/bootstrap/05-iam-github-oidc`
- [ ] Deploy GitHub Actions OIDC provider
- [ ] Create CI/CD deployment roles
- [ ] Configure trust relationships for GitHub repository

### Phase 5: Deploy Bootstrap to Each Account
**Directory**: `terraform/bootstrap/02-account-bootstrap`
- [ ] Deploy to development account
- [ ] Deploy to staging account
- [ ] Deploy to UAT account
- [ ] Deploy to production account
- [ ] Deploy to shared services account

Each deployment includes:
- IAM roles and policies
- CloudWatch log groups
- Secrets Manager setup
- Account-specific resources
- Audit trail configuration

### Phase 6: Cleanup & Documentation
- [ ] Remove temporary IAM credentials from .env file
- [ ] Delete temporary IAM user if created
- [ ] Update BOOTSTRAP_SUMMARY.md with actual account IDs
- [ ] Commit state files to secure storage
- [ ] Document actual account IDs in secure location
- [ ] Set up MFA for all account root users

## 🛠️ Execution Commands

### Fix Account ID and Deploy Organizations
```bash
cd terraform/bootstrap/01-organizations
# Update terraform.tfvars with correct master account ID
terraform init
terraform plan
terraform apply
```

### Deploy Shared Services (after accounts created)
```bash
cd terraform/bootstrap/03-shared-services
# Configure for shared account
terraform init
terraform plan
terraform apply
```

### Deploy Cost Management
```bash
cd terraform/bootstrap/04-cost-management
terraform init
terraform plan
terraform apply
```

### Deploy GitHub OIDC
```bash
cd terraform/bootstrap/05-iam-github-oidc
terraform init
terraform plan
terraform apply
```

### Deploy to Each Account
```bash
cd terraform/bootstrap
./deploy-to-account.sh development
./deploy-to-account.sh staging
./deploy-to-account.sh uat
./deploy-to-account.sh production
./deploy-to-account.sh shared
```

## ⏱️ Estimated Time
- Total: 30-45 minutes
- Organizations: 10 minutes
- Shared Services: 5 minutes
- Cost Management: 5 minutes
- GitHub OIDC: 5 minutes
- Per-account bootstrap: 5 minutes each (25 minutes total)

## ⚠️ Important Notes
1. **MUST fix master account ID** before proceeding
2. Account creation may take 5-10 minutes per account
3. Email addresses for accounts must be unique and accessible
4. Service Control Policies will immediately restrict resources
5. Budget alerts will start monitoring immediately

## 🔍 Verification Steps
After completion, verify:
1. All 5 accounts visible in AWS Organizations console
2. Can assume OrganizationAccountAccessRole in each account
3. ECR repositories created in shared account
4. Budget alerts configured and active
5. GitHub OIDC provider exists
6. IAM roles deployed to all accounts
7. CloudTrail active in all accounts