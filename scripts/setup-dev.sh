#!/bin/bash

# Diagnyx Development Environment Setup Script
# This script sets up the complete development environment

set -e

echo "🚀 Diagnyx Development Environment Setup"
echo "========================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    echo "Checking prerequisites..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker Desktop."
        exit 1
    fi
    print_status "Docker found"
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is not installed."
        exit 1
    fi
    print_status "Docker Compose found"
    
    # Check Node.js
    if ! command -v node &> /dev/null; then
        print_warning "Node.js is not installed. Some services may not work."
    else
        print_status "Node.js found ($(node --version))"
    fi
    
    # Check Python
    if ! command -v python3 &> /dev/null; then
        print_warning "Python 3 is not installed. Some services may not work."
    else
        print_status "Python found ($(python3 --version))"
    fi
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_warning "kubectl is not installed. Kubernetes operations will not work."
    else
        print_status "kubectl found"
    fi
    
    echo ""
}

# Setup environment files
setup_env_files() {
    echo "Setting up environment files..."
    
    # Create .env file from .env.example if it doesn't exist
    if [ ! -f "../docker/.env" ]; then
        cp ../docker/.env.example ../docker/.env
        print_status "Created .env file from template"
        print_warning "Please update .env file with your API keys and configurations"
    else
        print_status ".env file already exists"
    fi
    
    echo ""
}

# Start infrastructure services
start_infrastructure() {
    echo "Starting infrastructure services..."
    
    cd ../docker
    
    # Start core services first
    docker-compose up -d postgres redis
    print_status "Started PostgreSQL and Redis"
    
    # Wait for PostgreSQL to be ready
    echo "Waiting for PostgreSQL to be ready..."
    sleep 10
    
    # Start Kafka and Zookeeper
    docker-compose up -d zookeeper kafka
    print_status "Started Kafka and Zookeeper"
    
    # Start Elasticsearch
    docker-compose up -d elasticsearch
    print_status "Started Elasticsearch"
    
    # Start monitoring stack
    docker-compose up -d prometheus grafana
    print_status "Started Prometheus and Grafana"
    
    echo ""
}

# Initialize databases
init_databases() {
    echo "Initializing databases..."
    
    # Create databases
    docker exec -it diagnyx-postgres psql -U diagnyx -c "CREATE DATABASE IF NOT EXISTS diagnyx_auth;" 2>/dev/null || true
    docker exec -it diagnyx-postgres psql -U diagnyx -c "CREATE DATABASE IF NOT EXISTS diagnyx_traces;" 2>/dev/null || true
    docker exec -it diagnyx-postgres psql -U diagnyx -c "CREATE DATABASE IF NOT EXISTS diagnyx_analytics;" 2>/dev/null || true
    
    print_status "Created databases"
    echo ""
}

# Start application services
start_services() {
    echo "Starting application services..."
    
    cd ../docker
    
    # Build and start auth service
    docker-compose up -d auth-service
    print_status "Started Auth Service (http://localhost:3001)"
    
    # Build and start ingestion service
    docker-compose up -d ingestion-service
    print_status "Started Ingestion Service (http://localhost:8080)"
    
    # Build and start dashboard
    docker-compose up -d dashboard
    print_status "Started Dashboard (http://localhost:3000)"
    
    echo ""
}

# Setup local development
setup_local_dev() {
    echo "Setting up local development environment..."
    
    # Install dependencies for each service if running locally
    if [ -d "../../diagnyx-dashboard" ]; then
        echo "Installing Dashboard dependencies..."
        cd ../../diagnyx-dashboard
        npm install
        print_status "Dashboard dependencies installed"
    fi
    
    if [ -d "../../diagnyx-auth" ]; then
        echo "Installing Auth Service dependencies..."
        cd ../../diagnyx-auth
        npm install
        print_status "Auth Service dependencies installed"
    fi
    
    if [ -d "../../diagnyx-python-sdk" ]; then
        echo "Installing Python SDK..."
        cd ../../diagnyx-python-sdk
        pip3 install -e . 2>/dev/null || true
        print_status "Python SDK installed"
    fi
    
    echo ""
}

# Display service URLs
display_urls() {
    echo "========================================"
    echo "🎉 Development environment is ready!"
    echo "========================================"
    echo ""
    echo "Service URLs:"
    echo "  Dashboard:        http://localhost:3000"
    echo "  Auth Service:     http://localhost:3001"
    echo "  Ingestion API:    http://localhost:8080"
    echo "  Prometheus:       http://localhost:9090"
    echo "  Grafana:          http://localhost:3005 (admin/admin)"
    echo ""
    echo "Database connections:"
    echo "  PostgreSQL:       localhost:5432 (diagnyx/diagnyx123)"
    echo "  Redis:            localhost:6379"
    echo "  Kafka:            localhost:9092"
    echo "  Elasticsearch:    localhost:9200"
    echo ""
    echo "To stop all services: docker-compose down"
    echo "To view logs: docker-compose logs -f [service-name]"
    echo ""
}

# Main execution
main() {
    check_prerequisites
    setup_env_files
    start_infrastructure
    init_databases
    start_services
    setup_local_dev
    display_urls
}

# Run main function
main