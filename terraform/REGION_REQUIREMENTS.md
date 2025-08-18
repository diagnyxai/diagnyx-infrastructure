# Region Requirements - US-EAST-1 Only

## 🌍 Mandatory Region: us-east-1

All Diagnyx infrastructure **MUST** be deployed in the **us-east-1** (N. Virginia) region.

## Why us-east-1?

1. **Cost Optimization**
   - Lowest pricing for most AWS services
   - Most mature region with all services available
   - Best spot instance availability and pricing

2. **Service Availability**
   - All AWS services are available in us-east-1
   - New features and services launch here first
   - AWS Budgets and Cost Explorer require us-east-1 for certain features

3. **Bootstrap Requirements**
   - AWS Organizations management must be in us-east-1
   - Billing metrics only available in us-east-1
   - Cost allocation tags processed in us-east-1

## Enforcement Mechanisms

### 1. Terraform Validation
```hcl
# variables.tf
variable "aws_region" {
  validation {
    condition     = var.aws_region == "us-east-1"
    error_message = "AWS region must be us-east-1 for all Diagnyx infrastructure."
  }
}
```

### 2. Provider Configuration
```hcl
# providers.tf
provider "aws" {
  region = "us-east-1"  # Hard-coded to us-east-1
}
```

### 3. Runtime Validation
```hcl
# Terraform will fail if not in us-east-1
resource "null_resource" "region_validation" {
  lifecycle {
    precondition {
      condition     = data.aws_region.current.name == "us-east-1"
      error_message = "This infrastructure must be deployed in us-east-1 region."
    }
  }
}
```

### 4. Service Control Policies
```json
{
  "Effect": "Deny",
  "Action": "*",
  "Resource": "*",
  "Condition": {
    "StringNotEquals": {
      "aws:RequestedRegion": "us-east-1"
    }
  }
}
```

## Region Configuration Files

All configuration files enforce us-east-1:

| File | Region Setting |
|------|---------------|
| `/terraform/providers.tf` | `region = "us-east-1"` |
| `/terraform/variables.tf` | `default = "us-east-1"` with validation |
| `/terraform/environments/dev.tfvars` | `aws_region = "us-east-1"` |
| `/terraform/environments/staging.tfvars` | `aws_region = "us-east-1"` |
| `/terraform/environments/production.tfvars` | `aws_region = "us-east-1"` |
| `/terraform/bootstrap/*/providers.tf` | All set to `region = "us-east-1"` |

## Backend State Storage

Terraform state is also stored in us-east-1:

```hcl
backend "s3" {
  region = "us-east-1"  # Always us-east-1
  bucket = "diagnyx-terraform-state-${environment}"
}
```

## Multi-Region Considerations

**Current Status**: Single region (us-east-1) only

**Future Expansion**: If multi-region is needed in the future:
1. Data residency requirements
2. Disaster recovery setup
3. Cross-region replication
4. Global load balancing

For now, all resources remain in us-east-1 for cost optimization and simplicity.

## Deployment Commands

Always ensure region is set correctly:

```bash
# Export region
export AWS_REGION=us-east-1
export AWS_DEFAULT_REGION=us-east-1

# Verify region
aws configure get region
# Should output: us-east-1

# Deploy infrastructure
terraform init
terraform plan -var="aws_region=us-east-1"
terraform apply -var="aws_region=us-east-1"
```

## Cost Impact

Using us-east-1 provides these cost benefits:
- EC2: Baseline pricing (other regions may be 10-20% more expensive)
- RDS: Lowest pricing tier
- S3: Cheapest storage costs
- Data Transfer: Lower egress costs to internet
- Spot Instances: Best availability and pricing

## Monitoring and Alerts

All CloudWatch alarms and metrics are configured for us-east-1:
- Budget alerts monitor us-east-1 spending
- Cost anomaly detection runs in us-east-1
- CloudWatch dashboards aggregate us-east-1 metrics

## Compliance

Ensure your compliance requirements allow us-east-1 deployment:
- ✅ HIPAA compliant region
- ✅ SOC 1/2/3 compliant
- ✅ PCI DSS compliant
- ✅ ISO 27001/27017/27018 compliant

## Support

If you see region-related errors:
1. Check `AWS_REGION` environment variable
2. Verify terraform variables
3. Ensure AWS CLI is configured for us-east-1
4. Contact admin@diagnyx.com for assistance

---

**Remember**: Any attempt to deploy outside us-east-1 will be blocked by multiple validation layers.