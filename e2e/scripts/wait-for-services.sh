#!/bin/bash

# Wait for services to be ready for E2E testing
set -e

echo "🔄 Waiting for services to be ready..."

# Function to wait for HTTP service
wait_for_http() {
    local url=$1
    local service_name=$2
    local max_attempts=60
    local attempt=1
    
    echo "⏳ Waiting for $service_name at $url..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -f -s "$url" > /dev/null 2>&1; then
            echo "✅ $service_name is ready!"
            return 0
        fi
        
        echo "🔄 Attempt $attempt/$max_attempts - $service_name not ready yet..."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    echo "❌ $service_name failed to start within $(($max_attempts * 2)) seconds"
    return 1
}

# Function to wait for PostgreSQL
wait_for_postgres() {
    local host=$1
    local port=$2
    local user=$3
    local max_attempts=30
    local attempt=1
    
    echo "⏳ Waiting for PostgreSQL at $host:$port..."
    
    while [ $attempt -le $max_attempts ]; do
        if nc -z "$host" "$port" > /dev/null 2>&1; then
            echo "✅ PostgreSQL is ready!"
            return 0
        fi
        
        echo "🔄 Attempt $attempt/$max_attempts - PostgreSQL not ready yet..."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    echo "❌ PostgreSQL failed to start within $(($max_attempts * 2)) seconds"
    return 1
}

# Wait for PostgreSQL
wait_for_postgres "postgres-e2e" "5432" "diagnyx_test"

# Wait for User Service
wait_for_http "http://user-service-e2e:8080/health" "User Service"

# Wait for API Gateway
wait_for_http "http://api-gateway-e2e:8443/health" "API Gateway"

# Wait for UI
wait_for_http "http://ui-e2e:3000" "UI Service"

# Additional wait to ensure all services are fully initialized
echo "⏳ Waiting additional 10 seconds for full service initialization..."
sleep 10

echo "🎉 All services are ready! Starting E2E tests..."

# Run the E2E tests
exec "$@"