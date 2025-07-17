#!/bin/bash

# Jetson Nano Deployment Script for Braindump
# Optimized for ARM64 architecture and limited resources

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
COMPOSE_FILE="docker-compose.jetson-simple.yml"
JETPACK_VERSION=$(cat /etc/nv_tegra_release 2>/dev/null | grep -o "R[0-9]*" || echo "Unknown")

log_info() {
    echo -e "${BLUE}[JETSON]${NC} $1"
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

# Check system requirements
check_system() {
    log_info "Checking Jetson Nano system requirements..."
    
    # Check architecture
    ARCH=$(uname -m)
    if [[ "$ARCH" != "aarch64" ]]; then
        log_error "This script is for ARM64 architecture, detected: $ARCH"
        exit 1
    fi
    
    # Check available memory
    TOTAL_MEM=$(free -m | awk 'NR==2{printf "%.0f", $2}')
    if [[ $TOTAL_MEM -lt 3500 ]]; then
        log_warning "Low memory detected: ${TOTAL_MEM}MB (recommended: >3.5GB)"
        log_warning "Consider enabling swap or reducing other processes"
    else
        log_success "Memory check passed: ${TOTAL_MEM}MB available"
    fi
    
    # Check available disk space
    DISK_AVAIL=$(df / | awk 'NR==2 {print $4}')
    DISK_AVAIL_GB=$((DISK_AVAIL / 1024 / 1024))
    if [[ $DISK_AVAIL_GB -lt 5 ]]; then
        log_error "Insufficient disk space: ${DISK_AVAIL_GB}GB (required: >5GB)"
        exit 1
    else
        log_success "Disk space check passed: ${DISK_AVAIL_GB}GB available"
    fi
    
    log_info "JetPack version: $JETPACK_VERSION"
    log_success "System requirements check completed"
}

# Check Docker setup
check_docker() {
    log_info "Verifying Docker setup..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker not found. Please install Docker first."
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose not found. Please install Docker Compose first."
        exit 1
    fi
    
    # Check Docker version
    DOCKER_VERSION=$(docker --version | grep -o '[0-9]*\.[0-9]*\.[0-9]*' | head -1)
    log_info "Docker version: $DOCKER_VERSION"
    
    # Check if user is in docker group
    if ! groups | grep -q docker; then
        log_warning "User not in docker group. You may need to use sudo."
    fi
    
    # Test Docker daemon
    if ! docker info &>/dev/null; then
        log_error "Cannot connect to Docker daemon. Is Docker running?"
        exit 1
    fi
    
    log_success "Docker setup verified"
}

# Optimize system for deployment
optimize_system() {
    log_info "Checking system optimization..."
    
    # Check swap space
    SWAP_SIZE=$(free -m | awk 'NR==3{print $2}')
    if [[ $SWAP_SIZE -lt 2048 ]]; then
        log_warning "Swap space is low (${SWAP_SIZE}MB), consider adding more swap"
        log_info "To add swap: sudo fallocate -l 2G /swapfile && sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile"
    else
        log_success "Swap space is adequate: ${SWAP_SIZE}MB"
    fi
    
    # Docker is already configured, no need to modify daemon.json
    log_success "System check completed"
}

# Build images locally to ensure ARM64 compatibility
build_images() {
    log_info "Building ARM64-compatible images locally..."
    
    # Build frontend
    log_info "Building frontend image..."
    docker build -t braindump-frontend:jetson .
    
    # Build backend
    log_info "Building backend image..."
    docker build -t braindump-backend:jetson ./backend
    
    log_success "Images built successfully"
}

# Clean up existing deployment
cleanup_existing() {
    log_info "Cleaning up existing deployment..."
    
    docker-compose -f "$COMPOSE_FILE" down --remove-orphans 2>/dev/null || true
    
    # Remove unused containers and images to free space
    docker system prune -f
    
    log_success "Cleanup completed"
}

# Deploy services with health checks
deploy_services() {
    log_info "Deploying services..."
    
    # Update compose file to use local images
    sed -i.bak 's/akim42003\/braindump-frontend:0.1.2/braindump-frontend:jetson/g' "$COMPOSE_FILE"
    sed -i.bak 's/akim42003\/braindump-backend:0.1.0/braindump-backend:jetson/g' "$COMPOSE_FILE"
    
    # Start PostgreSQL first
    log_info "Starting PostgreSQL..."
    docker-compose -f "$COMPOSE_FILE" up -d postgres
    
    # Wait for PostgreSQL with timeout
    log_info "Waiting for PostgreSQL to be ready..."
    local count=0
    while ! docker-compose -f "$COMPOSE_FILE" exec -T postgres pg_isready -U postgres -h localhost -d braindump &>/dev/null; do
        if [[ $count -ge 60 ]]; then
            log_error "PostgreSQL failed to start within 60 seconds"
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
    
    # Start backend
    log_info "Starting backend..."
    docker-compose -f "$COMPOSE_FILE" up -d backend
    
    # Wait for backend health check
    log_info "Waiting for backend to be healthy..."
    local backend_count=0
    while ! curl -f http://localhost:3000/health &>/dev/null; do
        if [[ $backend_count -ge 60 ]]; then
            log_warning "Backend not responding after 60 seconds, checking logs..."
            docker-compose -f "$COMPOSE_FILE" logs backend
            break
        fi
        sleep 2
        ((backend_count += 2))
    done
    
    # Start frontend
    log_info "Starting frontend..."
    docker-compose -f "$COMPOSE_FILE" up -d frontend
    
    log_success "All services deployed"
}

# Run database migration
run_migration() {
    log_info "Checking for database migration..."
    
    # Check if migration environment variables are set
    if [[ -f backend/.env ]]; then
        source backend/.env
    fi
    
    if [[ -n "${SUPABASE_URL}" ]] && [[ -n "${SUPABASE_ANON_KEY}" ]]; then
        log_info "Supabase credentials found, running migration..."
        
        # Wait a bit more to ensure backend is fully ready
        sleep 5
        
        # Run migration inside the backend container
        if docker-compose -f "$COMPOSE_FILE" exec -T backend node migrate.js; then
            log_success "Database migration completed successfully"
        else
            log_warning "Database migration failed, but deployment will continue"
            log_info "You can run migration manually later with:"
            log_info "  docker-compose -f $COMPOSE_FILE exec backend node migrate.js"
        fi
    else
        log_info "No Supabase credentials found, skipping migration"
        log_info "To migrate data from Supabase, create backend/.env with:"
        log_info "  SUPABASE_URL=your_supabase_url"
        log_info "  SUPABASE_ANON_KEY=your_supabase_anon_key"
    fi
}

# Verify deployment
verify_deployment() {
    log_info "Verifying deployment..."
    
    sleep 10
    
    # Show container status
    log_info "Container status:"
    docker-compose -f "$COMPOSE_FILE" ps
    
    # Check service accessibility
    local services_ok=true
    
    if curl -f http://localhost:1000 &>/dev/null; then
        log_success "Frontend accessible at http://localhost:1000"
    else
        log_error "Frontend not accessible"
        services_ok=false
    fi
    
    if curl -f http://localhost:3000/health &>/dev/null; then
        log_success "Backend API accessible at http://localhost:3000"
    else
        log_error "Backend API not accessible"
        services_ok=false
    fi
    
    # Check database connection
    if docker-compose -f "$COMPOSE_FILE" exec -T postgres pg_isready -U postgres -h localhost -d braindump &>/dev/null; then
        log_success "Database accessible"
    else
        log_error "Database not accessible"
        services_ok=false
    fi
    
    if [[ "$services_ok" == true ]]; then
        log_success "All services are running correctly!"
    else
        log_warning "Some services may not be working correctly"
    fi
    
    # Show system resource usage
    log_info "System resource usage:"
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"
}

# Main execution
main() {
    log_info "Starting Jetson Nano deployment for Braindump..."
    log_info "====================================================="
    
    check_system
    check_docker
    optimize_system
    build_images
    cleanup_existing
    deploy_services
    run_migration
    verify_deployment
    
    echo
    log_success "🚀 Deployment completed successfully!"
    echo
    log_info "Access your blog at:"
    log_info "  Frontend: http://localhost:1000"
    log_info "  Backend API: http://localhost:3000"
    log_info "  Database: localhost:5432"
    echo
    log_info "Useful commands:"
    log_info "  View logs: docker-compose -f $COMPOSE_FILE logs -f"
    log_info "  Stop services: docker-compose -f $COMPOSE_FILE down"
    log_info "  Monitor resources: docker stats"
    echo
    log_info "For external access, configure your Jetson's firewall/port forwarding"
}

# Cleanup on exit
cleanup_on_exit() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_error "Deployment failed with exit code $exit_code"
        log_info "Showing recent logs..."
        docker-compose -f "$COMPOSE_FILE" logs --tail=20 2>/dev/null || true
    fi
}

trap cleanup_on_exit EXIT

# Run main function
main "$@"