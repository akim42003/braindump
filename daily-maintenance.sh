#!/bin/bash

# Daily maintenance script for Braindump
# Run as cron job: 0 3 * * * /path/to/daily-maintenance.sh

set -euo pipefail

BACKUP_DIR="/home/alex/braindump-backups"
DATE=$(date +%Y%m%d_%H%M%S)
CONTAINER_NAME="braindump"
VOLUME_NAME="braindump_data"
LOG_FILE="/var/log/braindump-maintenance.log"

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

log "Starting daily maintenance..."

# 1. Create database backup
log "Creating database backup..."
if docker exec "$CONTAINER_NAME" pg_dump -U postgres braindump > "$BACKUP_DIR/db_backup_$DATE.sql"; then
    log "Database backup created: db_backup_$DATE.sql"
else
    log "ERROR: Database backup failed"
    exit 1
fi

# 2. Create volume backup
log "Creating volume backup..."
if docker run --rm -v "$VOLUME_NAME":/data -v "$BACKUP_DIR":/backup alpine \
    tar czf "/backup/volume_backup_$DATE.tar.gz" -C /data .; then
    log "Volume backup created: volume_backup_$DATE.tar.gz"
else
    log "ERROR: Volume backup failed"
    exit 1
fi

# 3. Log current resource usage before restart
MEMORY_USAGE=$(docker stats --no-stream --format "{{.MemUsage}}" "$CONTAINER_NAME" || echo "N/A")
log "Pre-restart memory usage: $MEMORY_USAGE"

# 4. Graceful container restart
log "Restarting container for daily maintenance..."
if docker restart "$CONTAINER_NAME"; then
    log "Container restarted successfully"
else
    log "ERROR: Container restart failed"
    exit 1
fi

# 5. Wait for services to be ready
log "Waiting for services to start..."
sleep 30

# 6. Health check
for i in {1..12}; do
    if curl -f -s http://localhost:1000/health > /dev/null 2>&1; then
        log "Health check passed - services are ready"
        break
    elif [ $i -eq 12 ]; then
        log "ERROR: Health check failed after restart"
        exit 1
    else
        log "Health check attempt $i/12 failed, retrying..."
        sleep 10
    fi
done

# 7. Log post-restart resource usage
sleep 10
MEMORY_USAGE_AFTER=$(docker stats --no-stream --format "{{.MemUsage}}" "$CONTAINER_NAME" || echo "N/A")
log "Post-restart memory usage: $MEMORY_USAGE_AFTER"

# 8. Cleanup old backups (keep last 7 days)
log "Cleaning up old backups..."
find "$BACKUP_DIR" -name "db_backup_*.sql" -mtime +7 -delete 2>/dev/null || true
find "$BACKUP_DIR" -name "volume_backup_*.tar.gz" -mtime +7 -delete 2>/dev/null || true

BACKUP_COUNT=$(ls -1 "$BACKUP_DIR"/db_backup_*.sql 2>/dev/null | wc -l)
log "Maintenance complete. Keeping $BACKUP_COUNT database backups."

# 9. Optional: Send status notification (uncomment if needed)
# curl -X POST "https://api.pushover.net/1/messages.json" \
#     -d "token=YOUR_TOKEN" \
#     -d "user=YOUR_USER" \
#     -d "message=Braindump daily maintenance completed successfully"