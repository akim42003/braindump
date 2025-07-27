const http = require('http');

// Dedicated keep-alive daemon to ensure server never times out
// This runs as a separate process and continuously pings the server

const BACKEND_URL = 'http://localhost:8001/health';
const PING_INTERVAL = 60000; // 60 seconds - less aggressive

console.log('Keep-alive daemon started');

function pingServer() {
  http.get(BACKEND_URL, (res) => {
    let data = '';
    res.on('data', chunk => data += chunk);
    res.on('end', () => {
      try {
        const health = JSON.parse(data);
        console.log(`[${new Date().toISOString()}] Server alive - DB: ${health.checks.database}`);
      } catch (e) {
        console.log(`[${new Date().toISOString()}] Server alive - Response: ${res.statusCode}`);
      }
    });
  }).on('error', (err) => {
    console.error(`[${new Date().toISOString()}] Ping failed:`, err.message);
  });
}

// Initial ping
pingServer();

// Set up continuous pinging
setInterval(pingServer, PING_INTERVAL);

// Handle graceful shutdown
process.on('SIGTERM', () => {
  console.log('Keep-alive daemon shutting down');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('Keep-alive daemon interrupted');
  process.exit(0);
});