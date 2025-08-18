# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Git Workflow - IMPORTANT

**CRITICAL: Follow these branching rules for ALL changes:**

1. **NEVER commit directly to `main` or `develop` branches**
2. **ALWAYS create a feature branch for any changes**
3. **ALWAYS create a Pull Request at the end of each task**

### Workflow Steps:
```bash
# 1. Start from develop branch
git checkout develop
git pull origin develop

# 2. Create feature branch
git checkout -b feature/your-feature-name

# 3. Make changes and commit
git add .
git commit -m "feat: descriptive message"

# 4. Push and create PR
git push -u origin feature/your-feature-name
gh pr create --base develop --title "Feature: Description" --body "Changes made"
```

### Commit Message Convention:
- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation
- `refactor:` Code refactoring
- `test:` Test updates
- `chore:` Maintenance

## Repository Overview

The Diagnyx Infrastructure repository contains all infrastructure-as-code, deployment configurations, and orchestration scripts for the Diagnyx platform.

## Repository Structure

```
diagnyx-infra/
├── docker/                  # Docker Compose configurations
│   ├── docker-compose.yml   # Main compose file
│   └── .env.example        # Environment variables template
├── kubernetes/             # Kubernetes manifests
│   ├── base/              # Base configurations
│   ├── overlays/          # Environment-specific configs
│   └── kustomization.yaml
├── terraform/              # Infrastructure as Code
│   ├── modules/           # Reusable Terraform modules
│   ├── environments/      # Environment-specific configs
│   └── providers.tf       # Provider configurations
├── monitoring/            # Monitoring stack configs
│   ├── prometheus/       # Prometheus configuration
│   ├── grafana/         # Grafana dashboards
│   └── alerts/          # Alert rules
├── scripts/              # Utility scripts
│   ├── deploy.sh        # Deployment script
│   ├── setup-dev.sh     # Development setup
│   └── port-forwards.sh # K8s port forwarding
└── docs/                # Infrastructure documentation
```

## Key Components

### Docker Compose
- Local development environment
- All services orchestration
- Volume management
- Network configuration

### Kubernetes
- Production deployments
- Service mesh configuration
- Ingress controllers
- Auto-scaling policies

### Terraform
- Cloud resource provisioning
- Network infrastructure
- Database instances
- Security groups

## Common Commands

### Docker Operations
```bash
# Start all services
docker-compose up -d

# Stop all services
docker-compose down

# View logs
docker-compose logs -f [service-name]

# Rebuild services
docker-compose build --no-cache
```

### Kubernetes Operations
```bash
# Apply configurations
kubectl apply -k kubernetes/overlays/production

# Check deployments
kubectl get deployments -n diagnyx

# Port forward for debugging
kubectl port-forward -n diagnyx svc/api-gateway 8080:8080
```

### Terraform Operations
```bash
# Initialize Terraform
terraform init

# Plan changes
terraform plan -var-file=environments/production.tfvars

# Apply changes
terraform apply -var-file=environments/production.tfvars

# Destroy resources
terraform destroy -var-file=environments/production.tfvars
```