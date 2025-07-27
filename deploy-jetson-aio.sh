#!/bin/bash

# Deploy all-in-one container on Jetson Nano

set -euo pipefail

IMAGE="akim42003/braindump-all-in-one:latest"

echo "Deploying Braindump on Jetson Nano..."

# Stop and remove existing container
docker stop braindump 2>/dev/null || true
docker rm braindump 2>/dev/null || true

# Pull latest image
echo "Pulling image..."
docker pull "$IMAGE"

# Run container
echo "Starting container..."
docker run -d\
  -p 1000:80 \
  -p 8001:8001 \
  --name braindump \
  --restart unless-stopped \
  -v braindump_data:/var/lib/postgresql/data \
  "$IMAGE"

echo "Waiting for services to start..."
sleep 20

# Check if running
if docker ps | grep -q braindump; then
    echo "Braindump is running!"

    # Check for Supabase migration
    echo ""
    echo "Checking for Supabase data migration..."

    # Check if .env file exists with Supabase credentials
    if [ -f ".env" ]; then
        source .env
        if [ -n "${SUPABASE_URL}" ] && [ -n "${SUPABASE_ANON_KEY}" ]; then
            echo "Supabase credentials found, running migration..."

            # Wait a bit more for backend to be fully ready
            sleep 10

            # Run migration inside the container
            if docker exec braindump sh -c "cd /app/backend && SUPABASE_URL='${SUPABASE_URL}' SUPABASE_ANON_KEY='${SUPABASE_ANON_KEY}' node migrate.js"; then
                echo "Supabase migration completed successfully!"
            else
                echo "Migration failed, attempting to restore from latest backup..."
                
                # Find the latest backup
                BACKUP_DIR="/home/alex/braindump-backups"
                LATEST_BACKUP=$(ls -t "$BACKUP_DIR"/db_backup_*.sql 2>/dev/null | head -1)
                
                if [ -n "$LATEST_BACKUP" ] && [ -f "$LATEST_BACKUP" ]; then
                    echo "Found backup: $LATEST_BACKUP"
                    echo "Restoring database from backup..."
                    
                    # Stop container, restore volume from backup, restart
                    docker stop braindump
                    
                    # Find latest volume backup
                    LATEST_VOLUME_BACKUP=$(ls -t "$BACKUP_DIR"/volume_backup_*.tar.gz 2>/dev/null | head -1)
                    
                    if [ -n "$LATEST_VOLUME_BACKUP" ] && [ -f "$LATEST_VOLUME_BACKUP" ]; then
                        echo "Restoring volume from: $LATEST_VOLUME_BACKUP"
                        docker run --rm -v braindump_data:/data -v "$BACKUP_DIR":/backup alpine \
                            sh -c "rm -rf /data/* && tar xzf /backup/$(basename "$LATEST_VOLUME_BACKUP") -C /data"
                        
                        # Restart container
                        docker start braindump
                        sleep 20
                        
                        echo "Database restored from backup successfully!"
                    else
                        echo "No volume backup found, starting with empty database"
                        docker start braindump
                    fi
                else
                    echo "No database backup found, continuing with migration failure"
                fi
            fi
        else
            echo "No Supabase credentials found in .env file"
            read -p "Do you want to migrate data from Supabase? (y/N): " SUPABASE_MIGRATE
            if [ "$SUPABASE_MIGRATE" = "y" ] || [ "$SUPABASE_MIGRATE" = "Y" ]; then
                echo "To migrate data, create .env file with:"
                echo "SUPABASE_URL=your_supabase_url"
                echo "SUPABASE_ANON_KEY=your_supabase_anon_key"
            fi
        fi
    else
        echo "No .env file found for Supabase migration"
        read -p "Do you want to migrate data from Supabase? (y/N): " SUPABASE_MIGRATE
        if [ "$SUPABASE_MIGRATE" = "y" ] || [ "$SUPABASE_MIGRATE" = "Y" ]; then
            echo "To migrate data, create .env file with:"
            echo "SUPABASE_URL=your_supabase_url"
            echo "SUPABASE_ANON_KEY=your_supabase_anon_key"
        fi
    fi

    echo ""
    echo "Access your blog at:"
    echo "  http://$(hostname -I | awk '{print $1}'):1000"
    echo "  http://localhost:1000"
    echo ""
    echo "API endpoint: http://localhost:8001"
else
    echo " Failed to start Braindump"
    docker logs braindump
fi
