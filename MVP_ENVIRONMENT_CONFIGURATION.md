# Diagnyx Infrastructure - MVP Environment-Specific Configuration

## Overview
This document outlines the environment-specific configurations implemented for Diagnyx MVP deployments. The configuration balances cost optimization with appropriate functionality levels for each environment stage.

## 🎯 **MVP Philosophy: "Right-sized for Purpose"**

### Configuration Strategy:
- **Development/Staging**: Minimal cost configuration for testing and development
- **UAT**: Moderate configuration for user acceptance testing 
- **Production**: Recommended MVP configuration for live workloads (not aggressive)

## 💰 **Estimated Monthly Costs by Environment**

| Environment | Total Monthly Cost | Primary Use Case |
|-------------|-------------------|------------------|
| **Development** | ~$27 | Developer testing, CI/CD validation |
| **Staging** | ~$27 | Integration testing, deployment validation |
| **UAT** | ~$45 | User acceptance testing, demo environments |
| **Production** | ~$65 | Live MVP application with basic reliability |
| **Total (All 4)** | **~$164** | Full pipeline from dev to production |

## 📋 **Environment-Specific Configuration Matrix**

### Database Configuration (RDS PostgreSQL)

| Setting | Dev/Staging | UAT | Production |
|---------|-------------|-----|------------|
| **Instance Class** | db.t4g.micro | db.t4g.micro | db.t4g.small |
| **Storage** | 20GB | 30GB | 50GB |
| **Max Storage** | 50GB | 100GB | 200GB |
| **Multi-AZ** | ❌ No | ❌ No | ✅ Yes |
| **Backup Retention** | 1 day | 3 days | 7 days |
| **Performance Insights** | ❌ No | ✅ Yes | ✅ Yes |
| **Enhanced Monitoring** | ❌ No | ❌ No | ✅ Yes (60s) |
| **Deletion Protection** | ❌ No | ❌ No | ✅ Yes |

### ECS Infrastructure

| Setting | Dev/Staging | UAT | Production |
|---------|-------------|-----|------------|
| **Instance Type** | t4g.nano | t4g.micro | t4g.small |
| **Min Capacity** | 0 | 1 | 1 |
| **Max Capacity** | 1 | 2 | 3 |
| **Desired Count** | 0 | 1 | 1 |
| **Task CPU** | 256 units | 256 units | 512 units |
| **Task Memory** | 512 MB | 512 MB | 1024 MB |
| **Container Insights** | ❌ Disabled | ❌ Disabled | ✅ Enabled |

### Service Scaling Configuration

| Service | Dev/Staging | UAT | Production |
|---------|-------------|-----|------------|
| **User Service** | min=0, max=1 | min=1, max=2 | min=1, max=3 |
| **API Gateway** | min=0, max=1 | min=1, max=2 | min=1, max=3 |
| **UI Service** | min=0, max=1 | min=1, max=1 | min=1, max=2 |

### Monitoring & Logging

| Setting | Dev/Staging | UAT | Production |
|---------|-------------|-----|------------|
| **CloudWatch Log Retention** | 1 day | 3 days | 7 days |
| **CloudFront Log Retention** | 7 days | 14 days | 30 days |
| **Container Insights** | ❌ Disabled | ❌ Disabled | ✅ Enabled |
| **Performance Insights** | ❌ Disabled | ✅ Enabled | ✅ Enabled |

### Cost Controls

| Setting | Dev/Staging | UAT | Production |
|---------|-------------|-----|------------|
| **Monthly Budget** | $30 | $40 | $80 |
| **EC2 Budget** | $15 | $25 | $50 |
| **Budget Alert Threshold** | 80% | 80% | 80% |

## 🚀 **Deployment Strategies by Environment**

### Development Environment
- **Purpose**: Developer testing and experimentation
- **Availability**: Can scale to 0 during nights/weekends
- **Deployment**: Continuous deployment from feature branches
- **Data**: Synthetic test data, can be reset frequently

### Staging Environment  
- **Purpose**: Integration testing and deployment validation
- **Availability**: Can scale to 0 during nights/weekends
- **Deployment**: Automatic deployment from develop branch
- **Data**: Stable test datasets for integration testing

### UAT Environment
- **Purpose**: User acceptance testing and stakeholder demos
- **Availability**: Available during business hours, minimal nights/weekends
- **Deployment**: Manual deployment of release candidates
- **Data**: Production-like data for realistic testing

### Production Environment
- **Purpose**: Live MVP application serving real users
- **Availability**: 24/7 with basic redundancy
- **Deployment**: Manual deployment with approval process
- **Data**: Live customer data with full backup strategy

## 🔧 **Scaling Recommendations for Growth**

### From MVP to Scale (When Ready)

#### Database Scaling Path:
1. **Current MVP**: db.t4g.small (Production)
2. **Light Growth**: db.t4g.medium 
3. **Moderate Growth**: db.r6g.large with Multi-AZ
4. **Heavy Growth**: db.r6g.xlarge with Read Replicas

#### ECS Scaling Path:
1. **Current MVP**: t4g.small instances, max 3 tasks
2. **Light Growth**: t4g.medium instances, max 5 tasks  
3. **Moderate Growth**: m6g.large instances, max 10 tasks
4. **Heavy Growth**: Multiple AZs, auto-scaling groups

## 📊 **Cost Optimization Features Implemented**

### All Environments:
- ✅ ARM-based Graviton instances (20% cost savings)
- ✅ GP3 storage for better price/performance
- ✅ Spot instance support (up to 70% savings)
- ✅ Scheduled scaling for non-production
- ✅ CloudFront caching to reduce origin load
- ✅ VPC Endpoints to reduce data transfer costs
- ✅ ECR lifecycle policies for image cleanup

### Environment-Specific:
- ✅ Minimal log retention for dev/staging
- ✅ No redundancy for non-production
- ✅ Performance monitoring only where needed
- ✅ Right-sized budgets with alerts

## ⚠️ **Trade-offs and Considerations**

### What's Optimized:
- **Cost**: 65% reduction from standard enterprise setup
- **Development Speed**: Rapid iteration in dev/staging
- **MVP Readiness**: Production suitable for early customers

### What's Limited:
- **High Availability**: Production uses basic redundancy only
- **Disaster Recovery**: 7-day backup retention max
- **Advanced Monitoring**: Basic observability stack
- **Global Scale**: Single region deployment

## 🔄 **Operational Procedures**

### Development Workflow:
```bash
# Scale up for development
aws ecs update-service --cluster diagnyx-dev --service user-service --desired-count 1

# Scale down after development  
aws ecs update-service --cluster diagnyx-dev --service user-service --desired-count 0
```

### UAT Testing Workflow:
```bash
# Services auto-scale based on demand during business hours
# Manual intervention only needed for load testing
```

### Production Monitoring:
- Budget alerts at 80% of monthly spend
- Cost anomaly detection for unexpected spikes
- Basic CloudWatch dashboards for key metrics

## 📈 **Success Metrics**

### Cost Targets:
- **Development**: <$30/month per environment
- **UAT**: <$45/month (moderate usage)
- **Production**: <$80/month for MVP (up to 1000 users)

### Performance Targets:
- **API Response**: <500ms p95
- **Database**: <100ms query response
- **UI Load Time**: <3 seconds first load, <1 second cached

### Availability Targets:
- **Development/Staging**: No SLA
- **UAT**: 95% during business hours
- **Production**: 99% uptime (basic MVP SLA)

## 🎯 **Next Steps for Scaling**

### When to Scale Up (Indicators):
1. **User Growth**: >500 concurrent users
2. **Cost Threshold**: Approaching budget limits consistently  
3. **Performance Issues**: Response times >1 second
4. **Availability Needs**: Customer demands for higher SLA

### Immediate Upgrades (in order):
1. **Production Database**: Scale to db.t4g.medium
2. **ECS Capacity**: Increase max tasks to 5 per service
3. **Monitoring**: Add detailed performance monitoring
4. **Backup Strategy**: Increase retention to 30 days

This configuration provides a solid foundation for MVP deployment while maintaining cost efficiency and clear upgrade paths for future growth.