#!/bin/bash

# Deployment script for Jetson
echo "Deploying Braindump to Jetson..."

# Pull latest images
echo "Pulling latest images..."
docker pull akim42003/braindump-frontend:0.1.2
docker pull akim42003/braindump-backend:0.1.0
docker pull postgres:15-alpine

# Stop existing containers
echo "Stopping existing containers..."
docker-compose -f docker-compose.prod.yml down

# Start services
echo "Starting services..."
docker-compose -f docker-compose.prod.yml up -d

# Wait for services to be ready
echo "Waiting for services to start..."
sleep 20

# Initialize database schema
echo "Initializing database..."
docker-compose -f docker-compose.prod.yml exec -T postgres psql -U postgres -d braindump <<EOF
CREATE TABLE IF NOT EXISTS blog_posts (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    category VARCHAR(50) DEFAULT 'thought',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_blog_posts_category ON blog_posts(category);
CREATE INDEX IF NOT EXISTS idx_blog_posts_created_at ON blog_posts(created_at);
EOF

# Check container status
echo "Container status..."
docker-compose -f docker-compose.prod.yml ps

# Check health with more verbose output
echo "Health check..."
echo "Testing backend..."
curl -f http://localhost:3000/health && echo "Backend OK" || echo "Backend failed"
echo "Testing frontend..."
curl -f http://localhost:1000 && echo "Frontend OK" || echo "Frontend failed"

# Show logs if health checks fail
echo "Recent logs:"
docker-compose -f docker-compose.prod.yml logs --tail=20

echo "Deployment complete!"
echo "Frontend: http://localhost:1000"
echo "Backend API: http://localhost:3000/api"
echo "Database: localhost:5432"
