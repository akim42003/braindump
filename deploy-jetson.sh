#!/usr/bin/env bash

# Braindump Jetson Deployment Script
# Optimized for Ubuntu 18.04 and Docker 20.10.7

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
COMPOSE_FILE="docker-compose.prod.yml"
ENV_FILE="backend/.env"
POSTGRES_TIMEOUT=30

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
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

# Check if running on Jetson/ARM64
check_architecture() {
    local arch=$(uname -m)
    if [[ "$arch" != "aarch64" && "$arch" != "arm64" ]]; then
        log_warning "Not running on ARM64 architecture (detected: $arch)"
        log_warning "This script is optimized for Jetson devices"
    else
        log_info "Running on ARM64 architecture: $arch"
    fi
}

# Check Docker and Docker Compose versions
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        exit 1
    fi
    
    local docker_version=$(docker --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
    log_info "Docker version: $docker_version"
    
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose is not installed"
        exit 1
    fi
    
    local compose_version=$(docker-compose --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
    log_info "Docker Compose version: $compose_version"
}

# Load environment variables
load_env() {
    if [[ -f "$ENV_FILE" ]]; then
        log_info "Loading environment variables from $ENV_FILE"
        set -a
        source "$ENV_FILE"
        set +a
    else
        log_warning "Environment file $ENV_FILE not found, using defaults"
    fi
    
    # Set default values
    export POSTGRES_USER=${POSTGRES_USER:-postgres}
    export POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-password}
    export POSTGRES_DB=${POSTGRES_DB:-braindump}
}

# Check if compose file exists
check_compose_file() {
    if [[ ! -f "$COMPOSE_FILE" ]]; then
        log_error "Docker Compose file $COMPOSE_FILE not found"
        exit 1
    fi
    log_info "Using Docker Compose file: $COMPOSE_FILE"
}

# Pull Docker images with ARM64 support check
pull_images() {
    log_info "Pulling Docker images..."
    
    # Check if images support ARM64
    local images=(
        "akim42003/braindump-frontend:0.1.2"
        "akim42003/braindump-backend:0.1.0"
        "postgres:15-alpine"
    )
    
    for image in "${images[@]}"; do
        log_info "Pulling $image..."
        if ! docker pull "$image"; then
            log_error "Failed to pull $image"
            log_error "This image may not support ARM64 architecture"
            exit 1
        fi
    done
    
    log_success "All images pulled successfully"
}

# Stop existing containers
stop_containers() {
    log_info "Stopping existing containers..."
    docker-compose -f "$COMPOSE_FILE" down --remove-orphans || true
    log_success "Containers stopped"
}

# Start PostgreSQL and wait for it to be ready
start_postgres() {
    log_info "Starting PostgreSQL..."
    docker-compose -f "$COMPOSE_FILE" up -d postgres
    
    log_info "Waiting for PostgreSQL to be ready (timeout: ${POSTGRES_TIMEOUT}s)..."
    local count=0
    while ! docker-compose -f "$COMPOSE_FILE" exec -T postgres pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB" &>/dev/null; do
        if [[ $count -ge $POSTGRES_TIMEOUT ]]; then
            log_error "PostgreSQL failed to start within ${POSTGRES_TIMEOUT} seconds"
            docker-compose -f "$COMPOSE_FILE" logs postgres
            exit 1
        fi
        sleep 1
        ((count++))
    done
    
    log_success "PostgreSQL is ready"
}

# Initialize database schema
init_database() {
    log_info "Initializing database schema..."
    
    # Create database and tables
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

-- Insert sample data if table is empty
INSERT INTO blog_posts (title, content, category)
SELECT 'Welcome to Jetson Deployment', 'Successfully deployed braindump on Jetson device!', 'thought'
WHERE NOT EXISTS (SELECT 1 FROM blog_posts LIMIT 1);
EOF
    
    log_success "Database schema initialized"
}

# Start all services
start_services() {
    log_info "Starting backend and frontend services..."
    docker-compose -f "$COMPOSE_FILE" up -d backend frontend
    
    # Wait a moment for services to start
    sleep 3
    
    log_success "All services started"
}

# Display service status
show_status() {
    log_info "Service status:"
    docker-compose -f "$COMPOSE_FILE" ps
    
    echo
    log_info "Application URLs:"
    echo "Frontend: http://localhost:1000"
    echo "Backend API: http://localhost:3000"
    echo "PostgreSQL: localhost:5432"
}

# Health check
health_check() {
    log_info "Performing health check..."
    
    # Check if frontend is responding
    if curl -f http://localhost:1000 &>/dev/null; then
        log_success "Frontend is healthy"
    else
        log_warning "Frontend may not be ready yet"
    fi
    
    # Check if backend is responding
    if curl -f http://localhost:3000 &>/dev/null; then
        log_success "Backend is healthy"
    else
        log_warning "Backend may not be ready yet"
    fi
}

# Cleanup function
cleanup() {
    log_info "Cleaning up..."
    docker system prune -f
    log_success "Cleanup completed"
}

# Main deployment function
main() {
    log_info "Starting Braindump deployment on Jetson..."
    
    check_architecture
    check_docker
    check_compose_file
    load_env
    
    pull_images
    stop_containers
    start_postgres
    init_database
    start_services
    
    show_status
    health_check
    
    log_success "Deployment completed successfully!"
    log_info "Run 'docker-compose -f $COMPOSE_FILE logs -f' to view logs"
}

# Handle script termination
trap cleanup EXIT

# Run main function
main "$@"