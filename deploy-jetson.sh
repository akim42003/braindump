#!/usr/bin/env bash
set -euo pipefail

ENV_FILE=".env"
export $(grep -v '^#' "$ENV_FILE" | xargs)

COMPOSE="docker-compose -f docker-compose.prod.yml"

echo "Pulling images…"
docker pull akim42003/braindump-frontend:0.1.2 \
           akim42003/braindump-backend:0.1.0 \
           postgres:15-alpine

echo "Recreating stack…"
$COMPOSE down
$COMPOSE up -d postgres

echo "Waiting for Postgres…"
until $COMPOSE exec -T postgres pg_isready -U "$POSTGRES_USER" >/dev/null 2>&1; do
  sleep 1
done

$COMPOSE exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" <<'SQL'
CREATE TABLE IF NOT EXISTS blog_posts (
  id SERIAL PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  content TEXT NOT NULL,
  category VARCHAR(50) DEFAULT 'thought',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_blog_posts_category    ON blog_posts(category);
CREATE INDEX IF NOT EXISTS idx_blog_posts_created_at  ON blog_posts(created_at);
SQL

echo "Starting backend & frontend…"
$COMPOSE up -d backend frontend
$COMPOSE ps
