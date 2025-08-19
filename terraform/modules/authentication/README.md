# Authentication Module

This Terraform module provisions the complete authentication infrastructure for the Diagnyx platform, including user management, signup/login flows, and security components.

## Architecture Overview

The authentication system consists of:

1. **AWS Cognito** - Primary authentication service
2. **Lambda Triggers** - User activation and JWT token customization  
3. **Amazon SES** - Email verification and notifications
4. **RDS PostgreSQL** - User profiles and organization data
5. **IAM Users & Roles** - Deployment and service access management
6. **AWS Secrets Manager** - Secure credential storage

## Resources Created

### Core Authentication
- AWS Cognito User Pool with custom attributes
- Cognito User Pool Client with OAuth configuration
- Cognito User Pool Domain for hosted UI
- 2 Lambda functions for Cognito triggers
- Lambda execution roles and policies

### Database Infrastructure
- RDS PostgreSQL instance (shared across microservices)
- Database security groups
- RDS parameter group with optimizations
- Database credentials in Secrets Manager

### Email Services
- SES domain identity and DKIM verification
- SES email templates (welcome, verification, password reset)
- SES configuration set with CloudWatch integration
- SES identity policies for service access

### IAM Management
- 4 IAM users for different operational roles:
  - `ci-cd-user` - GitHub Actions deployments
  - `app-deployer` - Application updates
  - `monitoring-user` - Read-only monitoring access
  - `backup-user` - Database backup operations
- Custom IAM policies following least privilege principle
- Service roles for Lambda and ECS tasks
- Access keys stored securely in Secrets Manager

### Security & Configuration
- Multiple Secrets Manager secrets for different configurations
- CloudWatch Log Groups for monitoring
- Security groups with minimal required access

## Usage

### Basic Usage

```hcl
module "authentication" {
  source = "./modules/authentication"

  # Environment Configuration
  environment    = "production"
  aws_region     = "us-east-1"
  project_name   = "diagnyx"
  owner_email    = "ops@diagnyx.ai"

  # Cognito Configuration
  cognito_user_pool_name = "diagnyx-production-user-pool"
  cognito_client_name    = "diagnyx-production-client"
  password_policy = {
    minimum_length    = 12
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  # SES Configuration
  ses_domain = "diagnyx.ai"
  from_email = "noreply@diagnyx.ai"

  # Database Configuration
  database_name            = "diagnyx_users"
  database_master_username = "postgres"

  # API Gateway Configuration
  api_gateway_endpoint = "https://api.diagnyx.ai"

  # Common tags
  common_tags = {
    Environment = "production"
    Project     = "diagnyx"
    ManagedBy   = "terraform"
  }
}
```

### Environment-Specific Configurations

#### Development
```hcl
# Relaxed security for development
password_policy = {
  minimum_length    = 6
  require_lowercase = true
  require_numbers   = true
  require_symbols   = false
  require_uppercase = true
}
ses_domain = "dev.diagnyx.ai"
database_name = "diagnyx_users_dev"
```

#### Production
```hcl
# Strict security for production
password_policy = {
  minimum_length    = 12
  require_lowercase = true
  require_numbers   = true
  require_symbols   = true
  require_uppercase = true
}
ses_domain = "diagnyx.ai"
database_name = "diagnyx_users"
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| environment | Environment name (dev, staging, production) | string | n/a | yes |
| aws_region | AWS region | string | "us-east-1" | no |
| project_name | Project name for resource naming | string | "diagnyx" | no |
| owner_email | Email of the project owner | string | n/a | yes |
| cognito_user_pool_name | Name for the Cognito User Pool | string | null | no |
| cognito_client_name | Name for the Cognito User Pool Client | string | null | no |
| password_policy | Password policy configuration | object | See below | no |
| ses_domain | Domain for SES email sending | string | "diagnyx.ai" | no |
| from_email | From email address for notifications | string | "noreply@diagnyx.ai" | no |
| database_name | Name of the user service database | string | "diagnyx_users" | no |
| database_master_username | Master username for RDS instance | string | "postgres" | no |
| api_gateway_endpoint | API Gateway endpoint for Lambda callbacks | string | "https://api.diagnyx.ai" | no |
| lambda_runtime | Runtime for Lambda functions | string | "nodejs18.x" | no |
| lambda_timeout | Timeout for Lambda functions in seconds | number | 30 | no |
| lambda_memory_size | Memory size for Lambda functions in MB | number | 128 | no |
| common_tags | Common tags to be applied to all resources | map(string) | {} | no |

### Password Policy Object

```hcl
password_policy = {
  minimum_length    = number  # Minimum password length (6-128)
  require_lowercase = bool    # Require lowercase letters
  require_numbers   = bool    # Require numbers
  require_symbols   = bool    # Require symbols
  require_uppercase = bool    # Require uppercase letters
}
```

## Outputs

| Name | Description |
|------|-------------|
| cognito_user_pool_id | ID of the Cognito User Pool |
| cognito_user_pool_arn | ARN of the Cognito User Pool |
| cognito_user_pool_client_id | ID of the Cognito User Pool Client |
| cognito_user_pool_client_secret | Secret of the Cognito User Pool Client (sensitive) |
| cognito_user_pool_domain | Domain of the Cognito User Pool |
| post_confirmation_lambda_arn | ARN of the post confirmation Lambda function |
| pre_token_generation_lambda_arn | ARN of the pre token generation Lambda function |
| ses_domain_identity_arn | ARN of the SES domain identity |
| ses_from_email | Verified from email address |
| ci_cd_user_name | Name of the CI/CD IAM user |
| app_deployer_user_name | Name of the app deployer IAM user |
| monitoring_user_name | Name of the monitoring IAM user |
| backup_user_name | Name of the backup IAM user |
| database_secret_arn | ARN of the database credentials secret |
| cognito_secret_arn | ARN of the Cognito configuration secret |
| api_keys_secret_arn | ARN of the API keys secret |
| lambda_execution_role_arn | ARN of the Lambda execution role |
| microservice_role_arn | ARN of the microservice role |
| ses_sending_role_arn | ARN of the SES sending role |

## Post-Deployment Setup

### 1. SES Domain Verification

After deployment, you must verify the SES domain:

1. **Add DNS records** for domain verification (provided in Terraform output)
2. **Add DKIM records** for email authentication
3. **Request production access** if sending >200 emails/day

```bash
# Get the verification records
terraform output ses_domain_identity_verification_token
```

### 2. Database Initialization

The RDS instance is created but databases need to be initialized:

```sql
-- Connect as master user and create service databases
CREATE DATABASE diagnyx_users;
CREATE DATABASE diagnyx_observability;
CREATE DATABASE diagnyx_optimization;

-- Create service users
CREATE USER user_service WITH PASSWORD 'password_from_secrets_manager';
GRANT ALL ON DATABASE diagnyx_users TO user_service;

-- Run migration scripts from each service
```

### 3. Cognito Configuration

The Cognito User Pool is ready for use with:
- Email-based username
- Custom attributes for account type and organization
- Lambda triggers for user activation and token customization

### 4. Lambda Environment Variables

Lambda functions automatically receive environment variables from Secrets Manager:
- `API_ENDPOINT` - Internal API endpoint
- `INTERNAL_API_KEY` - For secure service-to-service communication
- `ENVIRONMENT` - Current environment name

### 5. IAM User Access Keys

Retrieve access keys for deployment users:

```bash
# Get CI/CD credentials for GitHub Actions
aws secretsmanager get-secret-value --secret-id "diagnyx-prod/ci-cd-credentials"

# Get monitoring credentials
aws secretsmanager get-secret-value --secret-id "diagnyx-prod/monitoring-credentials"
```

## Security Considerations

### IAM Policies
- All policies follow least privilege principle
- Resource-based restrictions using ARN patterns
- Environment-specific access controls

### Network Security
- RDS isolated in private subnets
- Security groups with minimal required access
- Lambda functions can access RDS and external APIs only

### Secrets Management
- All sensitive data stored in AWS Secrets Manager
- Automatic rotation supported for database credentials
- Lambda functions retrieve secrets at runtime

### Database Security
- Encryption at rest enabled
- Encryption in transit enforced
- Enhanced monitoring for production
- Automated backups with point-in-time recovery

## Monitoring and Logging

### CloudWatch Integration
- Lambda function logs retained for 14 days
- RDS logs forwarded to CloudWatch
- SES events tracked via CloudWatch metrics

### Alarms and Notifications
- Failed authentication attempts
- Lambda function errors
- Database connection issues
- SES bounce/complaint rates

## Cost Optimization

### Development Environment
- Single-AZ RDS instance
- Minimal backup retention (1-7 days)
- Basic monitoring only

### Production Environment
- Multi-AZ RDS for high availability
- 30-day backup retention
- Enhanced monitoring and performance insights

### Estimated Monthly Costs

| Environment | RDS | Lambda | SES | Secrets Manager | Total |
|-------------|-----|--------|-----|-----------------|-------|
| Development | $15 | $1 | $1 | $2 | ~$20 |
| Staging | $30 | $2 | $2 | $3 | ~$40 |
| Production | $100 | $5 | $5 | $5 | ~$120 |

## Troubleshooting

### Common Issues

1. **SES in Sandbox Mode**
   - Request production access through AWS console
   - Verify domain and email addresses

2. **Lambda Trigger Failures**
   - Check CloudWatch logs for error details
   - Verify API endpoint accessibility
   - Ensure internal API key is correct

3. **Database Connection Issues**
   - Verify security group rules
   - Check database credentials in Secrets Manager
   - Ensure Lambda functions are in correct VPC

4. **Cognito Configuration**
   - Verify callback URLs match your application
   - Check OAuth scopes and flows
   - Ensure client secret is properly configured

### Debugging Commands

```bash
# Check Lambda function logs
aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/diagnyx"

# Test database connectivity
aws rds describe-db-instances --db-instance-identifier diagnyx-prod-postgres

# Verify SES configuration
aws ses get-identity-verification-attributes --identities diagnyx.ai

# Check secrets
aws secretsmanager list-secrets --filters Key=name,Values=diagnyx-prod
```

## Development Workflow

### Local Testing
1. Use development environment for testing
2. Lambda functions can be tested locally with SAM CLI
3. Database migrations should be tested in staging first

### Deployment Process
1. Changes are deployed via Terraform
2. CI/CD user handles automated deployments
3. Manual verification required for production changes

### Rollback Procedures
1. Terraform state allows for easy rollbacks
2. Database snapshots provide data recovery
3. Lambda function versions enable quick reverts

## Contributing

When modifying this module:

1. **Update documentation** - Keep README current
2. **Test in development** - Always test changes first
3. **Follow naming conventions** - Use consistent resource naming
4. **Add appropriate tags** - Ensure all resources are tagged
5. **Update outputs** - Expose necessary information for other modules

For questions or issues, contact the Diagnyx infrastructure team.