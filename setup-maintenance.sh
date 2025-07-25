#!/bin/bash

# Setup script for daily maintenance on Jetson

echo "Setting up daily maintenance for Braindump..."

# Make maintenance script executable
chmod +x daily-maintenance.sh

# Create backup directory
sudo mkdir -p /home/alex/braindump-backups
sudo chown alex:alex /home/alex/braindump-backups

# Create log directory
sudo touch /var/log/braindump-maintenance.log
sudo chown alex:alex /var/log/braindump-maintenance.log

# Install cron job for daily restart at 3 AM
CRON_JOB="0 3 * * * /home/alex/braindump/daily-maintenance.sh"

# Check if cron job already exists
if crontab -l 2>/dev/null | grep -q "daily-maintenance.sh"; then
    echo "Cron job already exists"
else
    # Add to crontab
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
    echo "Added daily maintenance cron job (3 AM daily)"
fi

# Test backup system
echo "Testing backup system..."
if docker ps | grep -q braindump; then
    echo "Creating test backup..."
    ./daily-maintenance.sh
    echo "Test completed! Check /home/alex/braindump-backups for backup files"
else
    echo "Braindump container not running - deploy first, then run this setup script"
fi

echo "Setup complete!"
echo ""
echo "Daily maintenance will:"
echo "  - Backup database and volume data"
echo "  - Restart container to clear memory"
echo "  - Verify health after restart"
echo "  - Keep 7 days of backups"
echo ""
echo "To check maintenance logs:"
echo "  tail -f /var/log/braindump-maintenance.log"