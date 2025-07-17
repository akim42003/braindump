#!/bin/bash

# Simple migration script that runs migration as a one-off container

set -euo pipefail

# Load environment variables
if [[ -f backend/.env ]]; then
    source backend/.env
else
    echo "Error: backend/.env file not found!"
    echo "Please create backend/.env with:"
    echo "SUPABASE_URL=your_supabase_url"
    echo "SUPABASE_ANON_KEY=your_supabase_anon_key"
    exit 1
fi

if [[ -z "${SUPABASE_URL:-}" ]] || [[ -z "${SUPABASE_ANON_KEY:-}" ]]; then
    echo "Error: SUPABASE_URL and SUPABASE_ANON_KEY must be set in backend/.env"
    exit 1
fi

echo "Running migration from Supabase..."
echo "URL: $SUPABASE_URL"

# Run migration using docker-compose run (creates a new container)
docker-compose -f docker-compose.jetson-simple.yml run --rm \
    -e SUPABASE_URL="$SUPABASE_URL" \
    -e SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
    backend node migrate.js

echo "Migration completed!"

# Show post count
docker-compose -f docker-compose.jetson-simple.yml exec -T postgres \
    psql -U postgres -d braindump -t -c "SELECT COUNT(*) FROM blog_posts;" || echo "Could not verify post count"