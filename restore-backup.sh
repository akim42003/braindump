#!/bin/bash

# Restore Braindump from backup

set -euo pipefail

BACKUP_DIR="/home/alex/braindump-backups"
CONTAINER_NAME="braindump"

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Check if backup directory exists
if [ ! -d "$BACKUP_DIR" ]; then
    echo "ERROR: Backup directory $BACKUP_DIR not found"
    exit 1
fi

# List available backups
echo "Available database backups:"
ls -la "$BACKUP_DIR"/db_backup_*.sql 2>/dev/null | tail -10 || echo "No database backups found"

echo ""
echo "Available volume backups:"
ls -la "$BACKUP_DIR"/volume_backup_*.tar.gz 2>/dev/null | tail -10 || echo "No volume backups found"

echo ""
read -p "Enter the backup date to restore (YYYYMMDD_HHMMSS): " BACKUP_DATE

DB_BACKUP="$BACKUP_DIR/db_backup_$BACKUP_DATE.sql"
VOLUME_BACKUP="$BACKUP_DIR/volume_backup_$BACKUP_DATE.tar.gz"

# Check if backup files exist
if [ ! -f "$DB_BACKUP" ]; then
    echo "ERROR: Database backup not found: $DB_BACKUP"
    exit 1
fi

if [ ! -f "$VOLUME_BACKUP" ]; then
    echo "ERROR: Volume backup not found: $VOLUME_BACKUP"
    exit 1
fi

echo ""
echo "WARNING: This will replace all current data!"
read -p "Are you sure you want to restore from backup $BACKUP_DATE? (y/N): " CONFIRM

if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "Restore cancelled"
    exit 0
fi

log "Starting restore process..."

# Stop container
log "Stopping container..."
docker stop "$CONTAINER_NAME" || true

# Restore volume
log "Restoring volume data..."
docker run --rm -v braindump_data:/data -v "$BACKUP_DIR":/backup alpine \
    sh -c "rm -rf /data/* && tar xzf /backup/volume_backup_$BACKUP_DATE.tar.gz -C /data"

# Start container
log "Starting container..."
docker start "$CONTAINER_NAME"

# Wait for PostgreSQL to be ready
log "Waiting for PostgreSQL to start..."
sleep 30

# Restore database
log "Restoring database..."
docker exec -i "$CONTAINER_NAME" psql -U postgres -d braindump < "$DB_BACKUP"

log "Restore completed successfully!"
log "Please verify your data at http://localhost:1000"