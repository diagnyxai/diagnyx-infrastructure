# Diagnyx Infrastructure (diagnyx-infra)

Complete infrastructure code for the Diagnyx LLM Observability Platform, optimized for cost-effective deployment with simplified architecture.

## 🏗️ Simplified Infrastructure Architecture

### Bootstrap Foundation (~$12/month until deployment)
- **Multi-account AWS Organization** with environment isolation
- **Shared services** for ECR repositories and configuration
- **Cost management** with budgets and anomaly detection
- **Security controls** via SCPs and cross-account roles

### Simplified Service Architecture
- **6 core services** (down from 15+ for 80% cost reduction)
- **No Redis/ElastiCache** - in-memory caching only
- **Single database** (PostgreSQL) for all data
- **Streamlined monitoring** with Prometheus + Grafana

### Core Services
1. **PostgreSQL Database** - Primary data store
2. **User Service** (Java/Spring Boot) - Authentication & user management
3. **API Gateway** (Node.js) - Unified API entry point
4. **UI Service** (Next.js) - Marketing website & application
5. **Prometheus** - Metrics collection
6. **Grafana** - Monitoring dashboards

## 💰 Updated Cost Breakdown (80% Reduction)

| Environment | Bootstrap Only | Simplified Deployment |
|-------------|---------------|----------------------|
| Development | $12/month | $25/month |
| Staging | Shared | $35/month |
| UAT | Shared | $35/month |
| Production | Shared | $85/month |
| **Total** | **$12/month** | **~$180/month** |

## 📁 Repository Structure

```
diagnyx-infra/
├── terraform/
│   ├── bootstrap/                    # Pre-deployment foundation
│   │   ├── 01-organizations/        # AWS Org, accounts, SSO
│   │   ├── 02-account-bootstrap/    # Per-account resources
│   │   ├── 03-shared-services/      # ECR, ML storage, configs
│   │   └── 04-cost-management/      # Budgets, alerts
│   ├── environments/                 # Environment configs
│   │   ├── dev.tfvars
│   │   ├── staging.tfvars
│   │   ├── uat.tfvars
│   │   └── production.tfvars
│   ├── modules/                      # Reusable modules
│   │   ├── ecs-cluster/
│   │   ├── ecs-services/
│   │   └── networking/
│   └── backend-configs/              # Terraform state configs
├── docker/                           # Docker Compose for local dev
│   ├── docker-compose.yml
│   └── .env.example
├── scripts/                          # Deployment automation
│   ├── bootstrap.sh                  # One-time setup
│   ├── deploy-ecs.sh                # ECS deployment
│   └── setup-dev.sh                 # Local development
├── .github/
│   └── workflows/
│       └── ecs-deploy.yml           # CI/CD for ECS
└── docs/
    ├── BOOTSTRAP_GUIDE.md
    ├── ECS_MIGRATION_GUIDE.md
    └── MULTI_ACCOUNT_DEPLOYMENT_GUIDE.md
```

## 🚀 Quick Start

### Phase 1: Bootstrap Setup (One-time, ~$12/month)

```bash
# 1. Configure AWS credentials for master account
export AWS_PROFILE=diagnyx-master

# 2. Create organization and accounts
cd terraform/bootstrap/01-organizations
terraform init
terraform apply

# 3. Bootstrap each account
cd ../02-account-bootstrap
for env in dev staging uat prod shared; do
  terraform workspace new $env
  terraform apply -var="environment=$env"
done

# 4. Setup shared services
cd ../03-shared-services
terraform apply

# 5. Configure cost management
cd ../04-cost-management
terraform apply
```

### Phase 2: Local Development

```bash
# Start all services locally
cd docker
cp .env.example .env
# Edit .env with your values
docker-compose up -d

# Services available at:
# - Dashboard: http://localhost:3000
# - API Gateway: http://localhost:8080
# - Grafana: http://localhost:3005
```

### Phase 3: Deploy to AWS ECS

```bash
# Deploy to development
cd terraform
terraform init -backend-config=backend-configs/dev.hcl
terraform apply -var-file=environments/dev.tfvars

# Deploy to production
terraform init -backend-config=backend-configs/production.hcl -reconfigure
terraform apply -var-file=environments/production.tfvars
```

## 🔧 Configuration

### Required AWS Permissions

For bootstrap:
- Organizations management
- Account creation
- IAM role creation
- SSO configuration

For deployment:
- ECS cluster management
- VPC and networking
- RDS and ElastiCache
- S3 and ECR access

### Environment Variables

```bash
# Bootstrap variables
export ORGANIZATION_EMAIL=aws@diagnyx.ai
export BUDGET_ALERT_EMAIL=finance@diagnyx.ai

# Deployment variables
export AWS_REGION=us-east-1
export DOMAIN_NAME=diagnyx.ai  # Using Cloudflare
```

### Secrets Management

All secrets are pre-created in AWS Secrets Manager during bootstrap:
- Database passwords
- JWT secrets
- API keys
- Service credentials

Values are populated during deployment.

## 🚢 Deployment Workflows

### GitHub Actions CI/CD

```yaml
# Automatic deployment on push
main branch    → Production
staging branch → Staging
develop branch → Development

# Manual deployment
Actions → Run workflow → Select environment
```

### Service Updates

```bash
# Update specific service
aws ecs update-service \
  --cluster diagnyx-production \
  --service user-service \
  --force-new-deployment

# Scale service
aws ecs update-service \
  --cluster diagnyx-production \
  --service observability-service \
  --desired-count 5
```

## 📊 Monitoring & Observability

### CloudWatch Dashboards
- Service metrics
- Cost analysis
- Error rates
- Performance metrics

### Log Groups (Pre-created)
- `/ecs/diagnyx/[env]/services`
- `/application/diagnyx/[env]/traces`
- `/application/diagnyx/[env]/metrics`
- `/application/diagnyx/[env]/evaluations`

### Cost Monitoring
- Budget alerts at 50%, 80%, 100%
- Daily spike detection
- Cost anomaly detection
- Service-specific budgets

## 🔒 Security

### Network Security
- Private subnets for services
- VPC endpoints to reduce costs
- Security groups with minimal access
- Using Cloudflare WAF (not AWS WAF)

### Access Control
- AWS SSO for human access
- Cross-account IAM roles
- Service-specific roles
- MFA required for production

### Data Protection
- Encryption at rest (KMS)
- Encryption in transit (TLS)
- Secrets in AWS Secrets Manager
- Automated backups

## 🛠️ Maintenance

### Scheduled Scaling (Non-Production)
- **Active**: 11 AM - 7 PM UTC (weekdays)
- **Scaled Down**: Nights and weekends
- **Savings**: 66% on compute costs

### Backup Strategy
```bash
# RDS automated backups
# 7-day retention (dev/staging)
# 30-day retention (production)

# Manual backup
aws rds create-db-snapshot \
  --db-instance-identifier diagnyx-production \
  --db-snapshot-identifier diagnyx-production-$(date +%Y%m%d)
```

### Cost Optimization
- 70% Spot / 30% On-demand instances
- ARM/Graviton instances (20% cheaper)
- Scheduled scaling for non-production
- VPC endpoints to reduce NAT costs
- Cloudflare CDN instead of CloudFront

## 📖 Documentation

- [Bootstrap Setup Guide](docs/BOOTSTRAP_GUIDE.md)
- [ECS Migration Guide](docs/ECS_MIGRATION_GUIDE.md)
- [Multi-Account Deployment](docs/MULTI_ACCOUNT_DEPLOYMENT_GUIDE.md)
- [Cost Optimization](docs/COST_OPTIMIZATION.md)

## 🤝 Contributing

1. Create feature branch from `develop`
2. Make changes and test locally
3. Submit PR with description
4. Automated tests will run
5. Merge after review

## 📄 License

MIT License - See [LICENSE](LICENSE) file for details

## 🆘 Support

- Slack: #infrastructure
- Email: infrastructure@diagnyx.ai
- On-call: PagerDuty rotation

---

**Note**: This infrastructure is optimized for MVP/startup stage with ~$800/month total cost for all environments. As you scale, consider migrating to EKS for more advanced orchestration needs.