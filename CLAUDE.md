# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

The Diagnyx Infrastructure repository contains all infrastructure-as-code, deployment configurations, and orchestration scripts for the simplified Diagnyx platform. This repository manages a streamlined 6-service architecture optimized for cost-effectiveness (~$180/month total production cost).

## High-Level Architecture

### Core Services (6 Total)
1. **PostgreSQL Database** - Single database for all services (user_db, observability_db unified)
2. **User Service** (Java/Spring Boot) - Consolidated authentication, user management, RBAC
3. **API Gateway** (Node.js/Express) - Unified entry point with rate limiting, JWT validation
4. **UI Service** (Next.js) - Marketing website and application dashboard
5. **Prometheus** - Metrics collection (simplified monitoring)
6. **Grafana** - Dashboards and alerting

### Cost Optimization Decisions
- Removed Redis/ElastiCache (using in-memory caching)
- Consolidated from 15+ services to 6 core services
- Single RDS instance instead of multiple databases
- ECS on EC2 instead of Fargate for cost savings
- No Kubernetes in production (simplified to ECS)

## Critical Git Workflow

**NEVER commit directly to `main` or `develop` branches**

```bash
# Always start from develop
git checkout develop && git pull origin develop

# Create feature branch
git checkout -b feature/your-feature-name

# After changes
git add . && git commit -m "feat: description"
git push -u origin feature/your-feature-name

# Create PR
gh pr create --base develop --title "Feature: Description" --body "Changes made"
```

Commit prefixes: `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`

## Common Development Commands

### Local Development (Docker Compose)
```bash
# Start all 6 services locally
cd docker
docker-compose up -d

# Service health checks
curl http://localhost:8080/health      # User service
curl -k https://localhost:8443/health  # API gateway (HTTPS)
curl http://localhost:3002/            # UI service
curl http://localhost:9090/-/healthy   # Prometheus
curl http://localhost:3005/api/health  # Grafana

# View specific service logs
docker-compose logs -f user-service
docker-compose logs -f diagnyx-api-gateway
docker-compose logs -f diagnyx-ui

# Rebuild after code changes
docker-compose build --no-cache [service-name]
docker-compose up -d [service-name]
```

### Terraform Infrastructure Management

#### Bootstrap (One-time setup, $12/month)
```bash
# Initialize AWS Organization and accounts
cd terraform/bootstrap/01-organizations
terraform init -backend-config=backend-config.hcl
terraform apply

# Bootstrap each account
cd ../02-account-bootstrap
terraform init -backend-config=backend-config.hcl
terraform apply

# Shared services (ECR, Parameter Store)
cd ../03-shared-services
terraform init -backend-config=backend-config.hcl
terraform apply

# Cost management
cd ../04-cost-management
terraform init -backend-config=backend-config.hcl
terraform apply

# GitHub OIDC for CI/CD
cd ../05-iam-github-oidc
terraform init -backend-config=backend-config.hcl
terraform apply
```

#### Environment Deployment
```bash
cd terraform

# Development environment
terraform workspace select dev
terraform plan -var-file=environments/dev.tfvars
terraform apply -var-file=environments/dev.tfvars

# Production environment
terraform workspace select prod
terraform plan -var-file=environments/production.tfvars
terraform apply -var-file=environments/production.tfvars
```

### AWS Secrets Management
```bash
# Populate secrets for an environment
./scripts/populate-secrets.sh dev us-east-1

# The script manages these secrets:
# - database/password (PostgreSQL)
# - jwt/secret (Authentication)
# - user-service/api-key
# - api-gateway/rate-limit-key
# - external/openai-api-key (optional)
# - external/anthropic-api-key (optional)
```

### Testing

#### E2E Tests (Playwright)
```bash
cd e2e
npm install
npx playwright install

# Run with Docker environment
npm run docker:up
npm run docker:test
npm run docker:down

# Run against staging
npm run test:staging
```

#### Lambda Function Testing
```bash
cd lambda-testing
npm install

# Unit tests
npm test

# Integration tests with mock API
npm run test:integration

# Start mock server for manual testing
npm run start:mock-server
npm run test:lambda -- post-confirmation
```

### Kubernetes Operations (Development Only)
```bash
# Apply all manifests
kubectl apply -f kubernetes/ -n diagnyx

# Port forwarding for debugging
kubectl port-forward -n diagnyx svc/user-service 8080:8080
kubectl port-forward -n diagnyx svc/api-gateway 8443:8443

# Check deployments
kubectl get pods -n diagnyx
kubectl logs -n diagnyx -f deployment/user-service
```

## Infrastructure State Management

### Terraform Backend Configuration
Each bootstrap module uses S3 backend with state locking:
- Bucket: `diagnyx-terraform-state-{account-id}`
- DynamoDB Table: `diagnyx-terraform-locks`
- Key pattern: `bootstrap/{module-name}/terraform.tfstate`

### Environment-Specific Resources
```bash
# List resources in an environment
terraform state list | grep -E "(ecs|ecr|rds)"

# Show specific resource
terraform state show aws_ecs_cluster.main

# Import existing resources
terraform import aws_ecs_cluster.main diagnyx-cluster-prod
```

## Service Port Mapping

| Service | Local Port | Container Port | Health Check Path |
|---------|------------|---------------|------------------|
| PostgreSQL | 5432 | 5432 | N/A (pg_isready) |
| User Service | 8080 | 8080 | /health |
| API Gateway | 8443 | 8443 | /health |
| UI Service | 3002 | 3000 | / |
| Prometheus | 9090 | 9090 | /-/healthy |
| Grafana | 3005 | 3000 | /api/health |

## Multi-Account Structure

- **Master Account**: Organization root, billing, CloudTrail
- **Development**: All dev environments, CI/CD testing
- **Staging**: Pre-production testing
- **UAT**: User acceptance testing
- **Production**: Production workloads only
- **Shared Services**: ECR, ML models, cross-account resources

Cross-account access uses assume-role pattern with OIDC for GitHub Actions.

## Cost Monitoring

### Budget Alerts
- Development: $50/month limit
- Staging: $50/month limit
- Production: $200/month limit
- Total organization: $300/month limit

### Cost Optimization Checks
```bash
# Check current month spend
aws ce get-cost-and-usage \
  --time-period Start=$(date -u +%Y-%m-01),End=$(date -u +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics "UnblendedCost" \
  --group-by Type=DIMENSION,Key=SERVICE

# Review unused resources
aws ec2 describe-volumes --filters Name=status,Values=available
aws rds describe-db-instances --query 'DBInstances[?DBInstanceStatus==`stopped`]'
```

## Database Migrations

The user-db repository handles all database migrations. From this infrastructure repo:

```bash
# Run migrations in Docker environment
docker exec -it diagnyx-postgres psql -U diagnyx -d user_db -f /migrations/latest.sql

# Connect to database for debugging
docker exec -it diagnyx-postgres psql -U diagnyx -d diagnyx
```

## Monitoring and Observability

### Prometheus Targets
- User Service: `user-service:8080/metrics`
- API Gateway: `diagnyx-api-gateway:8443/metrics`
- PostgreSQL Exporter: `postgres-exporter:9187/metrics`

### Grafana Dashboards
Pre-configured dashboards in `docker/grafana/dashboards/`:
- Service Health Overview
- API Gateway Performance
- Database Metrics
- Cost Tracking Dashboard

Access Grafana: http://localhost:3005 (admin/admin)

## Troubleshooting

### Container Issues
```bash
# Check container health
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Inspect container networking
docker network inspect diagnyx-network

# Clean restart
docker-compose down -v
docker system prune -a
docker-compose up -d
```

### Terraform State Issues
```bash
# Unlock state if locked
terraform force-unlock <lock-id>

# Refresh state
terraform refresh -var-file=environments/dev.tfvars

# Recreate resource
terraform taint aws_ecs_service.user_service
terraform apply -var-file=environments/dev.tfvars
```

### Service Discovery
Services communicate using Docker service names in local development:
- `postgres:5432` (not localhost)
- `user-service:8080`
- `diagnyx-api-gateway:8443`

In ECS, use service discovery:
- `user-service.diagnyx.local:8080`
- `api-gateway.diagnyx.local:8443`