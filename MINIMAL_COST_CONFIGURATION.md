# Diagnyx Infrastructure - Minimal Cost Configuration

## Overview
This document outlines the bare minimum infrastructure configuration implemented across all Diagnyx environments to minimize AWS costs while maintaining basic functionality.

## 🎯 **Cost Optimization Philosophy: "Minimal Everything"**

### Key Principles:
- **Start with 0**: All services scale from 0 instances
- **Scale only when needed**: Auto-scaling triggers when demand requires
- **Minimum viable resources**: Smallest possible instance types and storage
- **Unified configuration**: Same minimal config for all environments (dev, uat, staging, production)

## 💰 **Estimated Monthly Costs (Per Environment)**

| Component | Configuration | Monthly Cost |
|-----------|---------------|--------------|
| **RDS PostgreSQL** | db.t4g.micro, 20GB, 1-day backup | ~$15 |
| **ECS Instances** | t4g.nano, starts at 0, max 1 | ~$5 |
| **NAT Instance** | t4g.nano (non-production only) | ~$3 |
| **CloudWatch Logs** | 1-day retention | ~$2 |
| **VPC & Networking** | Basic VPC, security groups | ~$0 |
| **S3 Storage** | Minimal with lifecycle | ~$1 |
| **CloudFront** | PriceClass_100, minimal usage | ~$1 |
| **Total per Environment** |  | **~$27** |

### **Total for All 4 Environments: ~$108/month**

## 📋 **Detailed Configuration by Component**

### Database Configuration (All Environments)
```hcl
# RDS PostgreSQL - Absolute minimum
instance_class = "db.t4g.micro"
allocated_storage = 20  # GB
max_allocated_storage = 100  # GB
backup_retention_period = 1  # day
multi_az = false
performance_insights_enabled = false
monitoring_interval = 0
skip_final_snapshot = true
deletion_protection = false
```

**Features:**
- ✅ Single AZ deployment (no high availability)
- ✅ 1-day backup retention only
- ✅ No performance insights
- ✅ No enhanced monitoring
- ✅ GP3 storage for cost efficiency
- ❌ No final snapshots
- ❌ No deletion protection

### ECS Infrastructure
```hcl
# ECS Cluster Configuration
instance_type = "t4g.nano"  # Smallest ARM instance
min_size = 0  # Can scale to 0
max_size = 1  # Maximum 1 instance
desired_capacity = 0  # Start with 0

# ECS Services
user_service: min=0, max=1, desired=0
api_gateway: min=0, max=1, desired=0
ui_service: min=0, max=1, desired=0

# Task Definitions
cpu = "256"  # Minimum CPU units
memory = "512"  # Minimum memory MB
```

**Features:**
- ✅ ARM-based Graviton instances (20% cost savings)
- ✅ Auto-scaling from 0 instances
- ✅ Spot instance support (70% savings)
- ✅ Minimal task resources
- ✅ On-demand scaling only

### Storage & Logging
```hcl
# CloudWatch Logs
retention_in_days = 1  # Minimum retention

# EBS Volumes
volume_size = 20  # GB minimum
volume_type = "gp3"

# S3 Lifecycle
transition_to_ia = 7  # days
transition_to_glacier = 30  # days
expiration = 90  # days
```

### Networking
```hcl
# Non-production environments
nat_gateway_enabled = false
nat_instance_type = "t4g.nano"

# Production environment
nat_gateway_enabled = true  # For reliability
single_nat_gateway = true  # Cost optimization
```

### Cost Controls
```hcl
# Budget Alerts
monthly_budget = "$50"
ec2_budget = "$30"
alert_threshold = 80%  # Alert at 80% of budget
```

## 🚀 **Auto-Scaling Strategy**

### Demand-Based Scaling
1. **Cold Start**: All services start at 0 instances
2. **Scale Up**: Auto-scaling triggers when CPU > 70% or Memory > 80%
3. **Scale Down**: Automatic scale-down during low usage
4. **Weekend Shutdown**: Non-production environments scale to 0 on weekends

### Scheduled Scaling (Non-Production)
```bash
# Weekday shutdown: 7 PM UTC
# Weekday startup: 11 AM UTC
# Weekend: Complete shutdown Friday 6 PM - Monday 11 AM
```

## 🛡️ **What's Sacrificed for Cost Savings**

### Availability & Reliability
- ❌ No Multi-AZ database deployments
- ❌ No redundant NAT Gateways
- ❌ Single instance maximum capacity
- ❌ No deletion protection
- ❌ Minimal backup retention (1 day)

### Monitoring & Observability
- ❌ No enhanced RDS monitoring
- ❌ No Performance Insights
- ❌ Minimal log retention (1 day)
- ❌ Basic CloudWatch metrics only

### Performance
- ❌ Cold start delays (scale from 0)
- ❌ Single task per service (no redundancy)
- ❌ Minimal CPU/memory allocation
- ❌ Shared infrastructure resources

## 🔧 **Manual Scaling for Testing/Demos**

When you need active services for development or testing:

```bash
# Scale up manually via AWS CLI or Console
aws ecs update-service --cluster diagnyx-dev --service user-service --desired-count 1
aws ecs update-service --cluster diagnyx-dev --service api-gateway --desired-count 1
aws ecs update-service --cluster diagnyx-dev --service ui-service --desired-count 1

# Scale down after use
aws ecs update-service --cluster diagnyx-dev --service user-service --desired-count 0
aws ecs update-service --cluster diagnyx-dev --service api-gateway --desired-count 0
aws ecs update-service --cluster diagnyx-dev --service ui-service --desired-count 0
```

## 📊 **Cost Comparison**

| Configuration | Monthly Cost | Annual Cost | Use Case |
|---------------|--------------|-------------|----------|
| **Previous Optimized** | ~$307 | ~$3,684 | Production-ready with redundancy |
| **Minimal Configuration** | ~$108 | ~$1,296 | Development/testing focused |
| **Savings** | **$199** | **$2,388** | **65% reduction** |

## 🚨 **Important Considerations**

### When to Use This Configuration
- ✅ Early development phases
- ✅ Testing and experimentation
- ✅ Cost-sensitive environments
- ✅ Proof of concept deployments
- ✅ Learning and training environments

### When NOT to Use This Configuration
- ❌ Production workloads requiring high availability
- ❌ Applications needing guaranteed uptime
- ❌ Compliance requirements for data retention
- ❌ High-traffic applications
- ❌ Mission-critical business operations

### Risks & Mitigations
1. **Data Loss Risk**: 1-day backup retention
   - **Mitigation**: Manual snapshots before major changes
   
2. **Service Downtime**: Single instance deployment
   - **Mitigation**: Quick auto-scaling, monitoring alerts
   
3. **Cold Start Delays**: Scale from 0 instances
   - **Mitigation**: Warm-up scripts, pre-scaling for demos
   
4. **Limited Debugging**: Minimal log retention
   - **Mitigation**: Export logs to S3 for important issues

## 🔄 **Upgrade Path**

When ready to scale up for production:

1. **Database**: Upgrade to db.t4g.small or larger
2. **Multi-AZ**: Enable for production database
3. **ECS Capacity**: Increase max instances to 2-3
4. **Monitoring**: Enable Performance Insights and enhanced monitoring
5. **Backup Retention**: Increase to 7-30 days
6. **Log Retention**: Increase to 7-14 days

## 📋 **Environment-Specific Notes**

### Development Environment
- Perfect for this minimal configuration
- Developers can scale up when actively coding
- Automatic weekend shutdown saves additional costs

### UAT Environment
- Suitable for user acceptance testing
- Manual scale-up before testing sessions
- Scale down immediately after testing

### Staging Environment
- Good for integration testing
- Consider keeping 1 instance running during business hours
- Use for deployment validation

### Production Environment
- **Consider upgrading** key components:
  - Database to db.t4g.small minimum
  - Enable Multi-AZ for database
  - Keep 1 instance running always
  - Increase backup retention to 7 days

## 🎯 **Conclusion**

This minimal configuration provides:
- **65% cost reduction** compared to standard setup
- **Full functionality** with acceptable trade-offs
- **Scalable foundation** for future growth
- **Learning-friendly** environment for development

Perfect for startups, learning environments, and cost-conscious deployments where maximum availability isn't the primary concern.

**Total Annual Savings: $2,388** 💰