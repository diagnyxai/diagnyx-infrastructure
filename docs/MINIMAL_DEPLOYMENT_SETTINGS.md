# Minimal Deployment Settings

This document describes the minimal deployment configuration for cost optimization during the initial MVP phase.

## 🎯 Configuration Summary

### Instance Configuration
- **All Services**: 1 instance per service in ALL environments
- **Auto-scaling**: Disabled initially (can scale to max 2-3 instances when needed)
- **Instance Type**: t4g.small (ARM-based for cost savings)

### Budget Limits

| Environment | Monthly Budget | Hard Limit | Emergency Stop |
|-------------|---------------|------------|----------------|
| **Development** | $25 | $30 | $35 |
| **Staging** | $25 | $30 | $35 |
| **UAT** | $25 | $30 | $35 |
| **Production** | $50 | $60 | $75 |
| **Shared** | $25 | $30 | $35 |

### Alert Configuration
- **All alerts sent to**: admin@diagnyx.com
- **Alert thresholds**: 50%, 80%, 100% of budget
- **Daily spending alerts**: If daily spend exceeds normal limits

## 💰 Expected Monthly Costs

### Per Environment Breakdown

#### Development Environment (~$20-25/month)
```
ECS Cluster:      $0 (free)
EC2 (t4g.small):  $12 (1 instance, on-demand)
ALB:              $20 (simplified to $5 with minimal rules)
RDS (t4g.micro):  $15
ElastiCache:      $13 (t4g.micro)
NAT Gateway:      $45 (single)
S3/Logs:          ~$2
Total:            ~$25/month with scheduled scaling
```

#### Production Environment (~$40-50/month)
```
ECS Cluster:      $0 (free)
EC2 (t4g.small):  $12 (1 instance, can scale to 2)
ALB:              $20
RDS (t4g.micro):  $15
ElastiCache:      $13
NAT Gateway:      $45
S3/Logs:          ~$5
Total:            ~$50/month
```

## 🚀 Service Configuration

### ECS Services (All running 1 instance)
1. **user-service** - Authentication and user management
2. **observability-service** - Metrics and tracing
3. **ai-quality-service** - AI evaluation
4. **optimization-service** - Cost optimization
5. **api-gateway** - API routing
6. **dashboard-service** - Web dashboard
7. **diagnyx-ui** - Marketing website

### Auto-scaling Settings
```hcl
# All services configured with:
min_capacity = 1  # Always 1 instance minimum
max_capacity = 2-3  # Can scale if needed
target_cpu = 70%  # Scale at 70% CPU
```

## 🛡️ Cost Protection Features

### Automatic Actions When Budget Exceeded

#### At $25 (Soft Limit) - Non-Production
- Email alert to admin@diagnyx.com
- No service changes

#### At $30 (Hard Limit) - Non-Production
- Scale all services to minimum (already at 1)
- Stop non-essential services (UI, dashboard)
- Alert sent

#### At $35 (Emergency) - Non-Production
- Stop ALL services except API Gateway
- Stop RDS if needed
- Emergency alert

#### At $50 (Soft Limit) - Production
- Email alert to admin@diagnyx.com
- Review required

#### At $60 (Hard Limit) - Production
- Scale non-critical services
- Stop batch jobs
- Alert sent

#### At $75 (Emergency) - Production
- Critical services only mode
- Page on-call (if configured)

## 📝 Terraform Variables to Set

```hcl
# terraform.tfvars
budget_alert_email = "admin@diagnyx.com"
ecs_instance_type  = "t4g.small"

# Per environment
development_budget = 25
staging_budget     = 25
uat_budget        = 25
production_budget  = 50
```

## 🔧 Manual Scaling Commands

### Scale Up a Service (when needed)
```bash
# Scale to 2 instances
aws ecs update-service \
  --cluster diagnyx-production \
  --service user-service \
  --desired-count 2
```

### Scale Down (to save costs)
```bash
# Scale back to 1 instance
aws ecs update-service \
  --cluster diagnyx-production \
  --service user-service \
  --desired-count 1
```

### Emergency Stop All Services
```bash
# Stop all services in an environment
for service in user-service observability-service ai-quality-service optimization-service api-gateway dashboard-service diagnyx-ui; do
  aws ecs update-service \
    --cluster diagnyx-development \
    --service $service \
    --desired-count 0
done
```

## 📊 Monitoring Your Costs

### Daily Cost Check
```bash
# Get today's cost
aws ce get-cost-and-usage \
  --time-period Start=$(date +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity DAILY \
  --metrics UnblendedCost \
  --query 'ResultsByTime[0].Total.UnblendedCost.Amount' \
  --output text
```

### Monthly Total
```bash
# Get current month total
aws ce get-cost-and-usage \
  --time-period Start=$(date +%Y-%m-01),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics UnblendedCost \
  --query 'ResultsByTime[0].Total.UnblendedCost.Amount' \
  --output text
```

## ⚡ Quick Cost Optimization Tips

1. **Use Scheduled Scaling** (already configured)
   - Non-prod scales to 0 after hours
   - Saves 66% on compute costs

2. **Stop Unused Services**
   ```bash
   # Stop UI if not needed
   aws ecs update-service --cluster diagnyx-dev --service diagnyx-ui --desired-count 0
   ```

3. **Use Spot Instances When Stable**
   - Currently disabled to minimize complexity
   - Can enable later for 70% savings

4. **Review Weekly**
   - Check Cost Explorer every Monday
   - Look for unused resources
   - Adjust budgets as needed

## 🔄 Scaling Strategy

### Phase 1 (Current) - Minimal
- 1 instance per service
- $25-50/month per environment
- Manual scaling only

### Phase 2 (When traffic increases)
- Enable auto-scaling
- 2-3 instances for critical services
- $50-100/month per environment

### Phase 3 (Production ready)
- Full auto-scaling
- Spot instances enabled
- Load-based scaling
- $200-500/month per environment

## ⚠️ Important Notes

1. **Bootstrap costs** (~$12/month) are separate from deployment costs
2. **NAT Gateway** is the most expensive component (~$45/month)
   - Consider VPC endpoints for S3/ECR to reduce data transfer
3. **Scheduled scaling** saves significant money in non-production
4. **All alerts** go to admin@diagnyx.com - monitor this inbox!
5. **Manual intervention** may be needed if emergency limits are hit

## 📞 Support

- **Budget Alerts**: admin@diagnyx.com
- **Infrastructure Issues**: Check CloudWatch Logs
- **Cost Questions**: Review Cost Explorer

---

**Remember**: These are minimal settings for MVP. As your application grows, you'll need to increase budgets and instance counts accordingly.