#!/bin/bash

# Containerized Braindump Deployment Script
# Runs inside the deployer container

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
COMPOSE_FILE=${COMPOSE_FILE:-docker-compose.prod.yml}
ENV_FILE=${ENV_FILE:-backend/.env}
POSTGRES_TIMEOUT=60

# Helper functions
log_info() {
    echo -e "${BLUE}[DEPLOYER]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check Docker connection
check_docker() {
    if ! docker info &>/dev/null; then
        log_error "Cannot connect to Docker daemon"
        log_error "Make sure you mounted the Docker socket: -v /var/run/docker.sock:/var/run/docker.sock"
        exit 1
    fi
    log_info "Docker connection established"
}

# Load environment variables
load_env() {
    if [[ -f "$ENV_FILE" ]]; then
        log_info "Loading environment from $ENV_FILE"
        set -a
        source "$ENV_FILE"
        set +a
    else
        log_warning "Environment file $ENV_FILE not found, using defaults"
    fi
    
    export POSTGRES_USER=${POSTGRES_USER:-postgres}
    export POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-password}
    export POSTGRES_DB=${POSTGRES_DB:-braindump}
    
    log_info "Environment loaded: DB=$POSTGRES_DB, User=$POSTGRES_USER"
}

# Pull images with retry logic
pull_images() {
    log_info "Pulling Docker images..."
    
    local images=(
        "akim42003/braindump-frontend:0.1.2"
        "akim42003/braindump-backend:0.1.0"
        "postgres:15-alpine"
    )
    
    for image in "${images[@]}"; do
        log_info "Pulling $image..."
        local retries=3
        while [[ $retries -gt 0 ]]; do
            if docker pull "$image"; then
                log_success "Successfully pulled $image"
                break
            else
                retries=$((retries - 1))
                if [[ $retries -eq 0 ]]; then
                    log_error "Failed to pull $image after 3 attempts"
                    exit 1
                fi
                log_warning "Retrying in 5 seconds... ($retries attempts left)"
                sleep 5
            fi
        done
    done
}

# Clean up existing deployment
cleanup_existing() {
    log_info "Cleaning up existing deployment..."
    docker-compose -f "$COMPOSE_FILE" down --remove-orphans || true
    docker system prune -f || true
    log_success "Cleanup completed"
}

# Deploy services
deploy_services() {
    log_info "Starting PostgreSQL..."
    docker-compose -f "$COMPOSE_FILE" up -d postgres
    
    log_info "Waiting for PostgreSQL to be ready..."
    local count=0
    while ! docker-compose -f "$COMPOSE_FILE" exec -T postgres pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB" &>/dev/null; do
        if [[ $count -ge $POSTGRES_TIMEOUT ]]; then
            log_error "PostgreSQL failed to start within ${POSTGRES_TIMEOUT} seconds"
            docker-compose -f "$COMPOSE_FILE" logs postgres
            exit 1
        fi
        sleep 2
        ((count += 2))
        if [[ $((count % 10)) -eq 0 ]]; then
            log_info "Still waiting for PostgreSQL... (${count}s elapsed)"
        fi
    done
    
    log_success "PostgreSQL is ready"
    
    # Initialize database
    log_info "Initializing database..."
    docker-compose -f "$COMPOSE_FILE" exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" <<'EOF'
CREATE TABLE IF NOT EXISTS blog_posts (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    category VARCHAR(50) DEFAULT 'thought',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_blog_posts_category ON blog_posts(category);
CREATE INDEX IF NOT EXISTS idx_blog_posts_created_at ON blog_posts(created_at);

INSERT INTO blog_posts (title, content, category)
SELECT 'Jetson Deployment Success', 'Braindump successfully deployed via containerized deployer!', 'thought'
WHERE NOT EXISTS (SELECT 1 FROM blog_posts WHERE title = 'Jetson Deployment Success');
EOF
    
    log_success "Database initialized"
    
    # Start application services
    log_info "Starting application services..."
    docker-compose -f "$COMPOSE_FILE" up -d backend frontend
    
    log_success "All services started"
}

# Health check and status
check_deployment() {
    log_info "Checking deployment status..."
    
    # Wait for services to be ready
    sleep 10
    
    # Show container status
    log_info "Container status:"
    docker-compose -f "$COMPOSE_FILE" ps
    
    # Test connectivity
    log_info "Testing service connectivity..."
    
    # Check backend
    local backend_ready=false
    for i in {1..10}; do
        if curl -f http://localhost:3000 &>/dev/null; then
            backend_ready=true
            break
        fi
        sleep 2
    done
    
    if [[ "$backend_ready" == true ]]; then
        log_success "Backend is responding"
    else
        log_warning "Backend not responding yet"
    fi
    
    # Check frontend
    local frontend_ready=false
    for i in {1..10}; do
        if curl -f http://localhost:1000 &>/dev/null; then
            frontend_ready=true
            break
        fi
        sleep 2
    done
    
    if [[ "$frontend_ready" == true ]]; then
        log_success "Frontend is responding"
    else
        log_warning "Frontend not responding yet"
    fi
    
    # Show access information
    echo
    log_info "=== DEPLOYMENT COMPLETE ==="
    log_info "Frontend: http://localhost:1000"
    log_info "Backend API: http://localhost:3000"
    log_info "Database: localhost:5432"
    echo
    log_info "To view logs: docker-compose -f $COMPOSE_FILE logs -f"
    log_info "To stop: docker-compose -f $COMPOSE_FILE down"
}

# Main execution
main() {
    log_info "Starting containerized Braindump deployment..."
    log_info "Target: Jetson (ARM64) with Docker 20.10.7"
    
    check_docker
    load_env
    pull_images
    cleanup_existing
    deploy_services
    check_deployment
    
    log_success "Deployment completed successfully!"
    
    # Keep container running for monitoring
    log_info "Deployment container will keep running for monitoring..."
    log_info "Press Ctrl+C to stop the deployment"
    
    # Monitor and keep alive
    while true; do
        sleep 60
        if ! docker-compose -f "$COMPOSE_FILE" ps | grep -q "Up"; then
            log_warning "Some services may be down. Check with: docker-compose -f $COMPOSE_FILE ps"
        fi
    done
}

# Handle termination
cleanup_on_exit() {
    log_info "Shutting down deployment..."
    docker-compose -f "$COMPOSE_FILE" down
    log_info "Deployment stopped"
}

trap cleanup_on_exit EXIT

# Run main function
main "$@"