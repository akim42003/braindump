#!/usr/bin/env bash
set -euo pipefail
COMPOSE="docker-compose -f docker-compose.prod.yml"

echo "Pulling images…"
docker pull akim42003/braindump-frontend:0.1.2
docker pull akim42003/braindump-backend:0.1.0
docker pull postgres:15-alpine

echo "Tearing down old stack…"
$COMPOSE down

echo "Starting only Postgres…"
$COMPOSE up -d db          # or postgres

# Wait for Postgres to accept connections
until $COMPOSE exec -T db pg_isready -U postgres > /dev/null 2>&1; do
  sleep 1
done

echo "Applying schema…"
# run with method A or B from above
docker run --rm -i --network "$($COMPOSE ps -q | xargs docker inspect -f '{{range $k,$v := .NetworkSettings.Networks}}{{$k}}{{end}}' | head -n1)" \
       postgres:15-alpine psql -h db -U postgres -d braindump -f /schema.sql

echo "Starting the rest of the stack…"
$COMPOSE up -d frontend backend
