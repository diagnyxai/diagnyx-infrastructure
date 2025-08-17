# Diagnyx Infrastructure

Complete infrastructure code for the Diagnyx LLM Observability Platform.

## 🏗️ Infrastructure Components

### Kubernetes Manifests
- Complete service deployments
- ConfigMaps and Secrets
- Ingress configuration
- Horizontal Pod Autoscaling
- Persistent volumes

### Docker Compose
- Local development environment
- All required services
- Monitoring stack included

### Terraform
- AWS infrastructure
- EKS cluster setup
- RDS, ElastiCache, S3
- VPC and networking
- IAM roles and policies

### CI/CD Pipelines
- GitHub Actions workflows
- Automated testing
- Multi-environment deployments
- Security scanning

## 🚀 Quick Start

### Local Development

```bash
# Setup complete dev environment
cd scripts
chmod +x setup-dev.sh
./setup-dev.sh

# Services will be available at:
# - Dashboard: http://localhost:3000
# - API: http://localhost:8080
# - Auth: http://localhost:3001
```

### Production Deployment

```bash
# Deploy to AWS EKS
cd scripts
chmod +x deploy.sh
./deploy.sh

# Deploy with Terraform
cd terraform
terraform init
terraform plan -var="environment=production"
terraform apply
```

## 📁 Directory Structure

```
.
├── kubernetes/        # K8s manifests
├── docker/           # Docker Compose setup
├── terraform/        # Infrastructure as Code
├── scripts/          # Deployment scripts
├── monitoring/       # Prometheus/Grafana configs
└── .github/          # CI/CD workflows
```

## 🔧 Configuration

### Environment Variables

Create `.env` file:
```bash
cp docker/.env.example docker/.env
# Edit with your values
```

### Terraform Variables

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Edit with your AWS configuration
```

## 🚢 Deployment

### Development
```bash
docker-compose up -d
```

### Staging
```bash
kubectl apply -f kubernetes/ -n diagnyx-staging
```

### Production
```bash
./scripts/deploy.sh
```

## 📊 Monitoring

- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3005 (admin/admin)
- **Metrics**: All services export Prometheus metrics

## 🔒 Security

- All secrets managed via Kubernetes Secrets
- Network policies enforced
- RBAC configured
- TLS/SSL on all endpoints
- VPC with private subnets

## 🛠️ Maintenance

### Scaling
```bash
kubectl scale deployment ingestion-service --replicas=5 -n diagnyx
```

### Updates
```bash
kubectl set image deployment/dashboard dashboard=diagnyx/dashboard:v2.0 -n diagnyx
```

### Backup
```bash
kubectl exec -it postgres-0 -n diagnyx -- pg_dump -U diagnyx diagnyx > backup.sql
```

## 📖 Documentation

For detailed documentation, visit [docs.diagnyx.ai](https://docs.diagnyx.ai)

## 📄 License

MIT License - See LICENSE file for details