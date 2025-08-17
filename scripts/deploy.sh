#!/bin/bash

# Diagnyx Production Deployment Script
# Deploys all services to Kubernetes cluster

set -e

# Configuration
NAMESPACE="${NAMESPACE:-diagnyx}"
ENVIRONMENT="${ENVIRONMENT:-production}"
AWS_REGION="${AWS_REGION:-us-east-1}"
CLUSTER_NAME="diagnyx-${ENVIRONMENT}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    echo "Checking prerequisites..."
    
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed"
        exit 1
    fi
    
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed"
        exit 1
    fi
    
    if ! command -v helm &> /dev/null; then
        print_error "Helm is not installed"
        exit 1
    fi
    
    print_status "All prerequisites met"
    echo ""
}

# Configure kubectl
configure_kubectl() {
    echo "Configuring kubectl..."
    aws eks update-kubeconfig --name $CLUSTER_NAME --region $AWS_REGION
    print_status "kubectl configured for cluster: $CLUSTER_NAME"
    echo ""
}

# Create namespace
create_namespace() {
    echo "Creating namespace..."
    kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    print_status "Namespace $NAMESPACE ready"
    echo ""
}

# Deploy secrets
deploy_secrets() {
    echo "Deploying secrets..."
    
    # Create secrets from environment variables
    kubectl create secret generic diagnyx-secrets \
        --from-literal=database-url="$DATABASE_URL" \
        --from-literal=jwt-secret="$JWT_SECRET" \
        --from-literal=openai-api-key="$OPENAI_API_KEY" \
        --from-literal=anthropic-api-key="$ANTHROPIC_API_KEY" \
        --namespace=$NAMESPACE \
        --dry-run=client -o yaml | kubectl apply -f -
    
    print_status "Secrets deployed"
    echo ""
}

# Deploy infrastructure
deploy_infrastructure() {
    echo "Deploying infrastructure components..."
    
    # Deploy PostgreSQL
    kubectl apply -f ../kubernetes/postgres.yaml -n $NAMESPACE
    print_status "PostgreSQL deployed"
    
    # Deploy Redis
    helm upgrade --install redis bitnami/redis \
        --namespace $NAMESPACE \
        --set auth.enabled=false \
        --set replica.replicaCount=3 \
        --wait
    print_status "Redis deployed"
    
    # Deploy Kafka
    helm upgrade --install kafka bitnami/kafka \
        --namespace $NAMESPACE \
        --set replicaCount=3 \
        --set zookeeper.replicaCount=3 \
        --wait
    print_status "Kafka deployed"
    
    echo ""
}

# Deploy services
deploy_services() {
    echo "Deploying application services..."
    
    # Apply ConfigMap
    kubectl apply -f ../kubernetes/configmap.yaml -n $NAMESPACE
    
    # Deploy services
    services=("auth-service" "ingestion-service" "dashboard")
    
    for service in "${services[@]}"; do
        kubectl apply -f ../kubernetes/$service.yaml -n $NAMESPACE
        print_status "$service deployed"
    done
    
    echo ""
}

# Deploy ingress
deploy_ingress() {
    echo "Deploying ingress..."
    
    # Install nginx ingress controller
    helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
        --namespace ingress-nginx \
        --create-namespace \
        --set controller.service.type=LoadBalancer \
        --wait
    
    # Deploy ingress rules
    kubectl apply -f ../kubernetes/ingress.yaml -n $NAMESPACE
    print_status "Ingress deployed"
    
    echo ""
}

# Deploy monitoring
deploy_monitoring() {
    echo "Deploying monitoring stack..."
    
    # Create monitoring namespace
    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
    
    # Install Prometheus
    helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
        --set grafana.adminPassword=admin \
        --wait
    
    print_status "Monitoring stack deployed"
    echo ""
}

# Wait for deployments
wait_for_deployments() {
    echo "Waiting for deployments to be ready..."
    
    kubectl wait --for=condition=available --timeout=300s \
        deployment/auth-service \
        deployment/ingestion-service \
        deployment/dashboard \
        -n $NAMESPACE
    
    print_status "All deployments ready"
    echo ""
}

# Run health checks
run_health_checks() {
    echo "Running health checks..."
    
    services=("auth-service:3001" "ingestion-service:8080")
    
    for service in "${services[@]}"; do
        IFS=':' read -r name port <<< "$service"
        kubectl run health-check-$name --image=curlimages/curl:latest --rm -i --restart=Never -- \
            curl -f http://$name.$NAMESPACE.svc.cluster.local:$port/health || true
    done
    
    print_status "Health checks complete"
    echo ""
}

# Get load balancer URL
get_load_balancer_url() {
    echo "Getting load balancer URL..."
    
    LB_URL=$(kubectl get service ingress-nginx-controller \
        -n ingress-nginx \
        -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    
    if [ -z "$LB_URL" ]; then
        LB_URL=$(kubectl get service ingress-nginx-controller \
            -n ingress-nginx \
            -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    fi
    
    echo ""
    echo "========================================"
    echo "🎉 Deployment Complete!"
    echo "========================================"
    echo ""
    echo "Load Balancer URL: http://$LB_URL"
    echo ""
    echo "Services:"
    echo "  Dashboard:     http://$LB_URL"
    echo "  API:           http://$LB_URL/api"
    echo "  Auth:          http://$LB_URL/auth"
    echo ""
    echo "Monitoring:"
    echo "  Prometheus:    http://$LB_URL:9090"
    echo "  Grafana:       http://$LB_URL:3000 (admin/admin)"
    echo ""
    echo "To check deployment status:"
    echo "  kubectl get pods -n $NAMESPACE"
    echo ""
}

# Rollback function
rollback() {
    print_error "Deployment failed! Rolling back..."
    kubectl rollout undo deployment --all -n $NAMESPACE
    exit 1
}

# Set error trap
trap rollback ERR

# Main execution
main() {
    echo "🚀 Diagnyx Production Deployment"
    echo "================================="
    echo "Environment: $ENVIRONMENT"
    echo "Namespace: $NAMESPACE"
    echo "Cluster: $CLUSTER_NAME"
    echo ""
    
    check_prerequisites
    configure_kubectl
    create_namespace
    deploy_secrets
    deploy_infrastructure
    deploy_services
    deploy_ingress
    deploy_monitoring
    wait_for_deployments
    run_health_checks
    get_load_balancer_url
}

# Run main function
main