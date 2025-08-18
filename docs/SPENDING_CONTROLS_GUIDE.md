# AWS Spending Controls & Hard Limits Guide

## Overview

This guide explains how to set up maximum spending budgets with automatic enforcement actions for each AWS account. When limits are reached, resources are automatically scaled down or stopped to prevent overspending.

## 🎯 Spending Control Levels

### Three-Tier Protection System

| Level | Action | Purpose |
|-------|--------|---------|
| **Soft Limit** | Alerts only | Early warning (80% of budget) |
| **Hard Limit** | Auto scale-down | Prevent overspending (100% of budget) |
| **Emergency** | Stop services | Emergency brake (120% of budget) |

## 💰 Configured Spending Limits

### Monthly Limits by Environment

| Environment | Soft Limit | Hard Limit | Emergency | Actions at Hard Limit |
|-------------|------------|------------|-----------|----------------------|
| **Development** | $200 | $250 | $300 | Scale to 1 instance, stop non-essential |
| **Staging** | $400 | $500 | $600 | Scale to 1 instance, stop non-essential |
| **UAT** | $300 | $400 | $500 | Scale to 1 instance, stop non-essential |
| **Production** | $1,800 | $2,200 | $2,500 | Scale non-critical, maintain critical |
| **Shared** | $100 | $150 | $200 | Alert and review |

### Daily Spending Limits (Catch Anomalies Fast)

| Environment | Normal | Warning (150%) | Critical (200%) |
|-------------|--------|----------------|-----------------|
| Development | $10 | $15 | $20 |
| Staging | $20 | $30 | $40 |
| UAT | $15 | $22 | $30 |
| Production | $60 | $90 | $120 |

## 🚨 Automatic Actions

### When Hard Limit is Reached

#### Non-Production (Dev, Staging, UAT):
1. **Scale Down Services** - All services to 1 instance
2. **Stop Non-Essential** - Dashboard, UI, AI Quality, Optimization
3. **Keep Running** - API Gateway, User Service only
4. **Alert Team** - Email + Slack notification

#### Production:
1. **Scale Non-Critical** - Reduce to minimum viable
2. **Maintain Critical** - API Gateway, User Service, Observability
3. **Stop Batch Jobs** - Any scheduled tasks
4. **Page On-Call** - SMS + Phone alert

### When Emergency Limit is Reached

**All Environments:**
1. **Critical Only Mode** - Stop everything except API and Auth
2. **Stop RDS** (non-production only)
3. **Scale ASGs to 0**
4. **Emergency Alert** - All channels

## 🔧 Setup Instructions

### 1. Deploy Spending Controls

```bash
cd terraform/bootstrap/04-cost-management

# Create Lambda function package
cd lambda
zip -r cost-controller.zip cost-controller.py
cd ..

# Deploy spending controls
terraform apply \
  -var="environment=development" \
  -var="budget_alert_email=finance@diagnyx.ai" \
  -var="emergency_contact_email=cto@diagnyx.ai" \
  -var="oncall_phone_number=+1234567890"
```

### 2. Configure Alert Recipients

```hcl
# terraform.tfvars
budget_alert_email      = "finance@diagnyx.ai"
emergency_contact_email = "cto@diagnyx.ai"
oncall_phone_number    = "+1234567890"  # Production only
slack_webhook_url      = "https://hooks.slack.com/services/..."
```

### 3. Verify Budget Creation

```bash
# List all budgets
aws budgets describe-budgets \
  --account-id $(aws sts get-caller-identity --query Account --output text)

# Check specific budget
aws budgets describe-budget \
  --account-id $(aws sts get-caller-identity --query Account --output text) \
  --budget-name diagnyx-development-hard-limit
```

## 📊 Monitoring Spending

### CloudWatch Dashboard

Each environment has a spending dashboard:
```
https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=diagnyx-{environment}-spending
```

Shows:
- Current month spending
- Daily spending trend
- Soft/hard limit lines
- Service-level costs

### AWS Cost Explorer

Quick links for cost analysis:
- [Current Month](https://console.aws.amazon.com/cost-management/home#/cost-explorer)
- [Daily Costs](https://console.aws.amazon.com/cost-management/home#/cost-explorer?chartStyle=STACK&costAggregate=unBlendedCost&endDate=2024-01-31&granularity=Daily&groupBy=%5B%5D&historicalRelativeRange=LAST_30_DAYS&isDefault=false&reportName=Daily%20costs&showOnlyUncategorized=false&showOnlyUntagged=false&startDate=2024-01-01&usageAggregate=usageQuantity&useNormalizedUnits=false)
- [Service Breakdown](https://console.aws.amazon.com/cost-management/home#/cost-explorer?chartStyle=STACK&costAggregate=unBlendedCost&endDate=2024-01-31&granularity=Monthly&groupBy=%5B%22Service%22%5D)

### CLI Commands

```bash
# Get current month spend
aws ce get-cost-and-usage \
  --time-period Start=$(date +%Y-%m-01),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics UnblendedCost \
  --query 'ResultsByTime[0].Total.UnblendedCost.Amount' \
  --output text

# Get daily spend for last 7 days
aws ce get-cost-and-usage \
  --time-period Start=$(date -d '7 days ago' +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity DAILY \
  --metrics UnblendedCost \
  --query 'ResultsByTime[].{Date:TimePeriod.Start,Cost:Total.UnblendedCost.Amount}' \
  --output table
```

## 🛠️ Manual Override

### Temporarily Disable Auto-Shutdown

```bash
# Disable Lambda function
aws lambda update-function-configuration \
  --function-name diagnyx-development-cost-controller \
  --environment Variables={ACTIONS='{"100":["alert"]}'} 

# Re-enable later
aws lambda update-function-configuration \
  --function-name diagnyx-development-cost-controller \
  --environment Variables={ACTIONS='{"80":["alert"],"100":["scale_down","alert"],"120":["stop_non_essential","alert"]}'}
```

### Restart Stopped Services

```bash
# Scale services back up
aws ecs update-service \
  --cluster diagnyx-development \
  --service dashboard-service \
  --desired-count 2

# Start RDS if stopped
aws rds start-db-instance \
  --db-instance-identifier diagnyx-development
```

## 📱 Alert Channels

### Email Alerts
- Sent to configured email addresses
- Include current spend, percentage, and actions taken

### Slack Integration (Optional)
```python
# Add to Lambda function
import requests

def send_slack_alert(message):
    webhook_url = os.environ.get('SLACK_WEBHOOK_URL')
    if webhook_url:
        requests.post(webhook_url, json={'text': message})
```

### SMS/Phone (Production Only)
- Critical alerts via SMS
- Phone call for emergency limit

## 🔄 Automatic Recovery

### Daily Reset Check
Every day at noon UTC, the system:
1. Checks if spending is back under control
2. Automatically scales services back up if budget allows
3. Sends recovery notification

### Manual Recovery
```bash
# Run recovery script
./scripts/recover-from-shutdown.sh development
```

## ⚠️ Important Considerations

### What Gets Stopped

**Safe to Stop:**
- Dashboard UI
- Marketing website
- AI quality service (in emergency)
- Optimization service (in emergency)
- Batch processing jobs

**Never Stopped:**
- API Gateway (critical)
- User/Auth Service (critical)
- Database (production)
- Observability (production)

### Grace Periods

- **Development/Staging**: Immediate action
- **Production**: 5-minute grace period before scaling
- **Emergency**: No grace period

### Exemptions

Add exemption tags to prevent shutdown:
```bash
aws ecs tag-resource \
  --resource-arn arn:aws:ecs:region:account:service/cluster/service \
  --tags key=BudgetExempt,value=true
```

## 📈 Cost Optimization Tips

### Proactive Measures
1. **Review weekly** - Check Cost Explorer every Monday
2. **Tag everything** - Proper cost allocation
3. **Use schedules** - Already configured for non-prod
4. **Clean up** - Remove unused resources
5. **Right-size** - Review instance sizes monthly

### Reactive Measures
1. **Investigate alerts** - Don't ignore warnings
2. **Find root cause** - Why did costs spike?
3. **Optimize** - Can we use smaller instances?
4. **Reserved Instances** - For predictable workloads

## 🆘 Troubleshooting

### Budget Actions Not Triggering

```bash
# Check Lambda logs
aws logs tail /aws/lambda/diagnyx-development-cost-controller --follow

# Test Lambda manually
aws lambda invoke \
  --function-name diagnyx-development-cost-controller \
  --payload '{"action":"test"}' \
  response.json
```

### Services Not Stopping

```bash
# Check ECS service events
aws ecs describe-services \
  --cluster diagnyx-development \
  --services dashboard-service \
  --query 'services[0].events[:5]'
```

### False Positives

If shutdown was triggered incorrectly:
1. Check for cost anomalies in Cost Explorer
2. Verify budget configuration
3. Adjust thresholds if needed
4. Add exemption tags to critical services

## 📝 Summary

With these spending controls:
- ✅ **Automatic protection** from runaway costs
- ✅ **Multiple warning levels** before action
- ✅ **Graceful degradation** (scale before stop)
- ✅ **Production protection** (critical services maintained)
- ✅ **Quick recovery** when budget allows
- ✅ **Full audit trail** of all actions

**Remember:** These controls are your safety net, not a replacement for proactive cost management!