# Bootstrap Instructions - Using Temporary IAM User

## 🔐 Prerequisites

Before running the bootstrap, you need to create a temporary IAM user in your AWS master account.

### Step 1: Create Temporary IAM User

1. **Log into AWS Console** with your master account
2. **Navigate to IAM** → Users → Add User
3. **Create user with:**
   ```
   Username: diagnyx-bootstrap-temp
   Access type: ✅ Programmatic access
   ```

4. **Attach Policy:**
   - Select: `AdministratorAccess` (temporary - will be removed after bootstrap)
   
5. **Save the credentials:**
   - Access Key ID
   - Secret Access Key
   - ⚠️ **IMPORTANT**: Save these securely, you won't see them again!

### Step 2: Configure Bootstrap Environment

1. **Copy the example environment file:**
   ```bash
   cd terraform/bootstrap
   cp .env.example .env
   ```

2. **Edit .env file** with your credentials:
   ```bash
   nano .env  # or use your preferred editor
   ```

3. **Fill in the following values:**
   ```env
   # Your temporary IAM user credentials
   AWS_ACCESS_KEY_ID=AKIA...your-key-here
   AWS_SECRET_ACCESS_KEY=...your-secret-here
   AWS_DEFAULT_REGION=us-east-1
   
   # Your master account ID (from AWS Console)
   MASTER_ACCOUNT_ID=123456789012
   
   # Email for all alerts
   BUDGET_ALERT_EMAIL=admin@diagnyx.com
   
   # Organization details
   ORGANIZATION_NAME=diagnyx
   ORGANIZATION_ROOT_EMAIL=admin@diagnyx.com
   
   # Account emails (must be unique)
   DEV_ACCOUNT_EMAIL=aws-dev@diagnyx.com
   STAGING_ACCOUNT_EMAIL=aws-staging@diagnyx.com
   UAT_ACCOUNT_EMAIL=aws-uat@diagnyx.com
   PROD_ACCOUNT_EMAIL=aws-prod@diagnyx.com
   SHARED_ACCOUNT_EMAIL=aws-shared@diagnyx.com
   ```

   **Note**: Each account email must be unique and not already associated with an AWS account.

### Step 3: Initialize Bootstrap

Run the initialization script:

```bash
chmod +x init-bootstrap.sh
./init-bootstrap.sh
```

This script will:
- ✅ Validate your AWS credentials
- ✅ Verify you're in us-east-1 region
- ✅ Create S3 bucket for Terraform state
- ✅ Create DynamoDB table for state locking
- ✅ Generate terraform.tfvars files

### Step 4: Run Bootstrap

Execute the bootstrap:

```bash
chmod +x run-bootstrap.sh
./run-bootstrap.sh
```

The script will execute in order:
1. **AWS Organizations** - Creates organization and 5 accounts
2. **Account Bootstrap** - Sets up each account with base resources
3. **Shared Services** - Creates ECR, ML buckets, Parameter Store
4. **Cost Management** - Sets up budgets and spending controls

**⚠️ IMPORTANT**: The script will ask for confirmation before each step. Review the Terraform plan carefully!

## 📊 What Gets Created

### Bootstrap Resources (Total: ~$12/month)

| Component | Resources | Cost |
|-----------|-----------|------|
| **Organizations** | Organization structure, 5 accounts, SCPs | $0 |
| **State Management** | 6 S3 buckets, 6 DynamoDB tables | ~$2/month |
| **Secrets Manager** | 30 secrets (6 per account) | $6/month |
| **CloudWatch Logs** | Log groups with 30-day retention | ~$2/month |
| **ECR Repositories** | 7 container registries | ~$1/month |
| **Parameter Store** | Configuration parameters | $0 |
| **Budget Alerts** | 5 budgets with email alerts | $0 |
| **Lambda Functions** | Cost control automation | <$1/month |

### Account Structure

```
Master Account (Organization Root)
├── Development Account ($25/month budget)
├── Staging Account ($25/month budget)
├── UAT Account ($25/month budget)
├── Production Account ($50/month budget)
└── Shared Services Account (ECR, Route53)
```

## 🔍 Verification Steps

After bootstrap completes:

1. **Check AWS Organizations:**
   ```bash
   aws organizations list-accounts
   ```

2. **Verify State Buckets:**
   ```bash
   aws s3 ls | grep diagnyx-terraform
   ```

3. **Check Budget Alerts:**
   ```bash
   aws budgets describe-budgets --account-id <account-id>
   ```

4. **Verify ECR Repositories:**
   ```bash
   aws ecr describe-repositories --region us-east-1
   ```

## 🧹 Cleanup After Bootstrap

**IMPORTANT**: After successful bootstrap, clean up the temporary IAM user:

1. **Delete the temporary IAM user:**
   ```bash
   aws iam delete-access-key --user-name diagnyx-bootstrap-temp --access-key-id <KEY_ID>
   aws iam detach-user-policy --user-name diagnyx-bootstrap-temp --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
   aws iam delete-user --user-name diagnyx-bootstrap-temp
   ```

2. **Secure the .env file:**
   ```bash
   # Remove the .env file after bootstrap
   rm .env
   
   # Or move it to secure storage
   mv .env ~/.diagnyx-bootstrap-backup.env
   chmod 600 ~/.diagnyx-bootstrap-backup.env
   ```

3. **Use cross-account roles** for future deployments instead of IAM users

## 🚀 Next Steps

After bootstrap:

1. **Deploy ECS Infrastructure:**
   ```bash
   cd ../..  # Back to main terraform directory
   ./deploy-environment.sh development
   ```

2. **Set up CI/CD:**
   - Use the cross-account roles created during bootstrap
   - Configure GitHub Actions or your preferred CI/CD tool

3. **Configure DNS:**
   - Point your domain to the ALB endpoints
   - Set up SSL certificates

## ⚠️ Troubleshooting

### Invalid Credentials Error
- Verify AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY in .env
- Ensure the IAM user has AdministratorAccess policy

### Region Error
- All resources MUST be in us-east-1
- Check AWS_DEFAULT_REGION=us-east-1 in .env

### Email Already in Use
- Each AWS account needs a unique email address
- You can use email aliases (e.g., admin+aws-dev@diagnyx.com)

### State Lock Error
- Someone else might be running Terraform
- Check DynamoDB table for locks
- Force unlock if needed: `terraform force-unlock <LOCK_ID>`

### Organization Already Exists
- The script will detect existing organizations
- You can continue with the existing org or cancel

## 📝 Important Notes

1. **Budget Alerts** go to admin@diagnyx.com - monitor this inbox!
2. **Spending Limits** are enforced at $25 (non-prod) and $50 (prod)
3. **All resources** are in us-east-1 region
4. **State files** are stored in S3 with versioning and encryption
5. **Cross-account roles** use external ID for additional security

## 🆘 Support

If you encounter issues:
1. Check the CloudWatch logs in the master account
2. Review the Terraform state files
3. Contact admin@diagnyx.com for assistance

---

**Security Reminder**: Never commit .env files or AWS credentials to version control!