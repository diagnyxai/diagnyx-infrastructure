# IAM Structure Documentation - Diagnyx Platform

## Overview

This document describes the complete IAM (Identity and Access Management) structure for the Diagnyx multi-account AWS setup. All IAM resources follow the principle of least privilege and are designed for secure cross-account access.

## 🏗️ IAM Architecture

### Account Structure
- **Master Account (778715730121)**: Organization management and billing
- **Development (215726089610)**: Development environment
- **Staging (435455014599)**: Staging environment  
- **UAT (318265006643)**: User acceptance testing
- **Production (921205606542)**: Production environment
- **Shared Services (008341391284)**: Shared resources like ECR

## 🔐 Cross-Account IAM Roles

### 1. DiagnyxCrossAccountAdmin
- **Purpose**: Emergency administrative access
- **Trust**: Master account only
- **Permissions**: AdministratorAccess
- **Session Duration**: 1 hour
- **Security**: 
  - Requires external ID
  - IP restriction capability
  - MFA recommended

### 2. DiagnyxCrossAccountCICD
- **Purpose**: Automated deployments from CI/CD
- **Trust**: Master account and Shared Services account
- **Permissions**: Custom deployment policy
- **Session Duration**: 2 hours
- **Use Case**: GitHub Actions, Jenkins, etc.

### 3. DiagnyxCrossAccountDeveloper
- **Purpose**: Developer debugging and monitoring
- **Trust**: Master account only
- **Permissions**: Read-only + ECS execute command
- **Session Duration**: 4 hours
- **Security**: Requires MFA

### 4. DiagnyxCrossAccountReadOnly
- **Purpose**: Monitoring and auditing
- **Trust**: Master account and Shared Services
- **Permissions**: ReadOnlyAccess
- **Session Duration**: 12 hours

### 5. DiagnyxCrossAccountCostExplorer
- **Purpose**: Cost analysis and optimization
- **Trust**: Master account only
- **Permissions**: Billing and Cost Explorer access
- **Session Duration**: 12 hours

## 🚀 ECS Service Roles

### Task Execution Role
**DiagnyxECSTaskExecutionRole**
- Pull container images from ECR
- Write logs to CloudWatch
- Access secrets from Secrets Manager
- Read parameters from Parameter Store

### Service-Specific Task Roles

| Service | Role Name | Key Permissions |
|---------|-----------|-----------------|
| User Service | DiagnyxECSTaskRole-UserService | Secrets Manager (JWT), SES (email), S3 (avatars) |
| Observability | DiagnyxECSTaskRole-ObservabilityService | Kinesis, S3 (traces/metrics), Timestream, X-Ray |
| AI Quality | DiagnyxECSTaskRole-AIQualityService | Bedrock, S3 (ML models), SageMaker endpoints |
| Optimization | DiagnyxECSTaskRole-OptimizationService | Cost Explorer, S3 (prompts), DynamoDB (versions) |
| API Gateway | DiagnyxECSTaskRole-APIGateway | ElastiCache, WAF, CloudWatch metrics |

## 🔑 GitHub Actions OIDC

### OIDC Provider
- **URL**: https://token.actions.githubusercontent.com
- **Audience**: sts.amazonaws.com
- **Thumbprint**: Automatically managed

### GitHub Actions Roles

| Role | Trusted Branches | Environment |
|------|------------------|-------------|
| DiagnyxGitHubActions-Development | develop, feature/* | Development |
| DiagnyxGitHubActions-Staging | staging, release/* | Staging |
| DiagnyxGitHubActions-Production | main, tags/v* | Production |

### Permissions
- ECR: Push/pull images
- ECS: Update services, register task definitions
- CloudFormation: Manage stacks
- S3: Store artifacts
- IAM: Pass roles to ECS tasks

## 📋 Custom IAM Policies

### DiagnyxCICDDeploymentPolicy
Full deployment permissions for CI/CD:
- ECS and ECR full access
- Load balancer management
- CloudFormation operations
- Limited IAM (PassRole only)
- S3 for artifacts
- CloudWatch logging

### DiagnyxDeveloperPolicy
Developer access for debugging:
- Read-only for most services
- ECS ExecuteCommand (dev/staging only)
- Parameter Store read access
- Secrets Manager read access
- CloudWatch logs access

### DiagnyxSecretsAccessPolicy
Secure secrets management:
- Secrets Manager read access (diagnyx-* secrets)
- Parameter Store read access (/diagnyx/* parameters)
- KMS decrypt for secrets

### DiagnyxDatabaseAccessPolicy
Database connectivity:
- RDS describe and connect
- ElastiCache describe

### DiagnyxS3AccessPolicy
S3 bucket operations:
- Read/write to diagnyx-* buckets
- List all buckets

### DiagnyxCloudWatchAccessPolicy
Monitoring and logging:
- Put metrics
- Create log streams
- Write log events

### DiagnyxKMSAccessPolicy
Encryption key usage:
- Encrypt/decrypt with diagnyx-* keys
- Generate data keys
- Create grants

## 🔄 How to Assume Roles

### AWS CLI
```bash
# Assume cross-account role
aws sts assume-role \
  --role-arn arn:aws:iam::ACCOUNT_ID:role/DiagnyxCrossAccountDeveloper \
  --role-session-name my-session \
  --external-id diagnyx-secure-2024

# Configure AWS CLI with assumed role
export AWS_ACCESS_KEY_ID=<AccessKeyId>
export AWS_SECRET_ACCESS_KEY=<SecretAccessKey>
export AWS_SESSION_TOKEN=<SessionToken>
```

### AWS Console
1. Click username → Switch Role
2. Enter Account ID
3. Enter Role name (e.g., DiagnyxCrossAccountDeveloper)
4. Optional: Set display name and color

### GitHub Actions
```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v2
  with:
    role-to-assume: arn:aws:iam::778715730121:role/DiagnyxGitHubActions-Production
    aws-region: us-east-1
```

## 🛡️ Security Best Practices

### External ID
All cross-account roles use external ID: `diagnyx-secure-2024`
- Prevents confused deputy attack
- Required for role assumption
- Should be kept secret

### MFA Requirements
- Developer role requires MFA
- Admin role recommends MFA
- Production access should always use MFA

### Session Duration
- Admin: 1 hour (emergency only)
- CI/CD: 2 hours (deployment window)
- Developer: 4 hours (debugging session)
- Read-only: 12 hours (monitoring)

### IP Restrictions
- Admin role can be restricted by IP
- Add office IP ranges for additional security
- VPN IPs should be whitelisted

## 📊 Monitoring and Audit

### CloudTrail
All IAM actions are logged to CloudTrail:
- Role assumptions
- Policy changes
- Permission usage
- Failed authentication attempts

### Access Analyzer
Regular reviews with IAM Access Analyzer:
- Unused roles
- Overly permissive policies
- External access points

### Rotation Schedule
- Review IAM roles quarterly
- Rotate credentials if used
- Update external IDs annually
- Review and prune unused roles

## 🚨 Emergency Procedures

### Lost Access
1. Use root account (last resort)
2. Contact AWS Support
3. Use OrganizationAccountAccessRole

### Compromised Credentials
1. Immediately revoke IAM role sessions
2. Rotate external ID
3. Review CloudTrail logs
4. Update affected policies

### Role Deletion Recovery
1. Check CloudTrail for deletion event
2. Recreate from Terraform
3. Restore from version control

## 📝 Compliance

### Least Privilege
- Each role has minimal required permissions
- Service-specific roles for isolation
- Time-limited sessions

### Separation of Duties
- Different roles for different functions
- No single role with all permissions
- Audit trail for all actions

### Regular Reviews
- Quarterly access reviews
- Annual security audit
- Continuous monitoring with CloudWatch

## 🔧 Maintenance

### Adding New Permissions
1. Update Terraform files
2. Test in development first
3. Apply to each account
4. Document changes

### Creating New Roles
1. Define trust relationship
2. Create custom policy
3. Test role assumption
4. Update documentation

### Removing Access
1. Remove from Terraform
2. Apply changes
3. Verify removal in console
4. Update documentation

## 📞 Support

For IAM-related issues:
- **Email**: admin@diagnyx.com
- **CloudWatch Alarms**: Automated alerts
- **AWS Support**: For account recovery

---

**Last Updated**: August 17, 2025
**Version**: 1.0
**Maintained By**: Diagnyx Platform Team