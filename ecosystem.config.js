module.exports = {
  apps: [{
    name: 'braindump-backend',
    script: './backend/server.js',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '500M',
    restart_delay: 5000,
    min_uptime: '10s',
    max_restarts: 10,
    env: {
      NODE_ENV: 'production',
      PORT: 8001
    },
    error_file: './logs/backend-error.log',
    out_file: './logs/backend-out.log',
    log_date_format: 'YYYY-MM-DD HH:mm:ss',
    
    // Exponential backoff restart delay
    exp_backoff_restart_delay: 100,
    
    // Health check
    health_check: {
      interval: 30,
      url: 'http://localhost:8001/health',
      max_consecutive_failures: 3
    }
  }, {
    name: 'braindump-keepalive',
    script: './keep-alive-daemon.js',
    instances: 1,
    autorestart: true,
    watch: false,
    error_file: './logs/keepalive-error.log',
    out_file: './logs/keepalive-out.log',
    log_date_format: 'YYYY-MM-DD HH:mm:ss'
  }]
};