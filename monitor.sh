#!/bin/bash

# Braindump Health Monitor Script
# Run this as a cron job every 5 minutes: */5 * * * * /path/to/monitor.sh

HEALTH_URL="http://localhost:8001/health"
LOG_FILE="/var/log/braindump-monitor.log"
MAX_RETRIES=3
RETRY_DELAY=10

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Function to restart services
restart_services() {
    log "ALERT: Restarting services due to health check failure"
    
    # Try PM2 first if available
    if command -v pm2 &> /dev/null; then
        pm2 restart braindump-backend
    # Fall back to systemctl
    elif command -v systemctl &> /dev/null; then
        sudo systemctl restart braindump
    # Last resort: direct restart
    else
        pkill -f "node.*server.js"
        sleep 2
        cd /home/alex/braindump && nohup node backend/server.js > /dev/null 2>&1 &
    fi
    
    # Restart nginx if needed
    if command -v nginx &> /dev/null; then
        sudo nginx -s reload
    fi
}

# Main health check loop
success=false
for i in $(seq 1 $MAX_RETRIES); do
    if curl -f -s --connect-timeout 10 --max-time 20 "$HEALTH_URL" > /dev/null; then
        success=true
        break
    else
        log "WARNING: Health check failed (attempt $i/$MAX_RETRIES)"
        if [ $i -lt $MAX_RETRIES ]; then
            sleep $RETRY_DELAY
        fi
    fi
done

if [ "$success" = true ]; then
    # Check response content
    HEALTH_RESPONSE=$(curl -s "$HEALTH_URL")
    DB_STATUS=$(echo "$HEALTH_RESPONSE" | grep -o '"database":"[^"]*"' | cut -d'"' -f4)
    
    if [ "$DB_STATUS" = "unhealthy" ]; then
        log "ERROR: Database is unhealthy"
        restart_services
    else
        log "INFO: Health check passed"
    fi
else
    log "ERROR: Health check failed after $MAX_RETRIES attempts"
    restart_services
fi

# Check disk space
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 90 ]; then
    log "WARNING: Disk usage is at ${DISK_USAGE}%"
fi

# Check memory usage
MEM_USAGE=$(free | awk 'NR==2 {printf "%.0f", $3/$2 * 100}')
if [ "$MEM_USAGE" -gt 85 ]; then
    log "WARNING: Memory usage is at ${MEM_USAGE}%"
fi