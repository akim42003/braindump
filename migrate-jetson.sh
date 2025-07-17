#!/bin/bash

# Standalone migration script for Jetson Nano deployment

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

COMPOSE_FILE="docker-compose.jetson-simple.yml"

log_info() {
    echo -e "${BLUE}[MIGRATE]${NC} $1"
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

# Check if services are running
check_services() {
    log_info "Checking if services are running..."
    
    if ! docker-compose -f "$COMPOSE_FILE" ps | grep -q "backend.*Up"; then
        log_error "Backend service is not running!"
        log_info "Please start services first with: docker-compose -f $COMPOSE_FILE up -d"
        exit 1
    fi
    
    log_success "Services are running"
}

# Run migration
run_migration() {
    log_info "Starting database migration from Supabase..."
    
    # Check for .env file
    if [[ ! -f backend/.env ]]; then
        log_error "backend/.env file not found!"
        log_info "Please create backend/.env with:"
        echo "SUPABASE_URL=your_supabase_url"
        echo "SUPABASE_ANON_KEY=your_supabase_anon_key"
        exit 1
    fi
    
    # Load environment variables
    source backend/.env
    
    if [[ -z "${SUPABASE_URL:-}" ]] || [[ -z "${SUPABASE_ANON_KEY:-}" ]]; then
        log_error "SUPABASE_URL and SUPABASE_ANON_KEY must be set in backend/.env"
        exit 1
    fi
    
    log_info "Supabase URL: ${SUPABASE_URL}"
    
    # Run migration with environment variables
    log_info "Executing migration script..."
    if docker-compose -f "$COMPOSE_FILE" exec -T \
        -e SUPABASE_URL="${SUPABASE_URL}" \
        -e SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY}" \
        backend node migrate.js; then
        log_success "Migration completed successfully!"
    else
        log_error "Migration failed!"
        log_info "Check the logs with: docker-compose -f $COMPOSE_FILE logs backend"
        exit 1
    fi
}

# Verify migration
verify_migration() {
    log_info "Verifying migration..."
    
    # Count posts in database
    POST_COUNT=$(docker-compose -f "$COMPOSE_FILE" exec -T postgres psql -U postgres -d braindump -t -c "SELECT COUNT(*) FROM blog_posts;" | tr -d ' ')
    
    log_success "Found $POST_COUNT posts in the database"
    
    # Show recent posts
    log_info "Recent posts:"
    docker-compose -f "$COMPOSE_FILE" exec -T postgres psql -U postgres -d braindump -c "SELECT id, title, category, created_at FROM blog_posts ORDER BY created_at DESC LIMIT 5;"
}

# Main execution
main() {
    log_info "Jetson Nano Database Migration Tool"
    log_info "===================================="
    
    check_services
    run_migration
    verify_migration
    
    echo
    log_success "Migration process completed!"
    log_info "Your blog data has been migrated from Supabase to local PostgreSQL"
}

main "$@"