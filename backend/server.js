const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 8001;

app.use(cors());
app.use(express.json());

const pool = new Pool({
  user: process.env.DB_USER || 'postgres',
  host: process.env.DB_HOST || 'localhost',
  database: process.env.DB_NAME || 'braindump',
  password: process.env.DB_PASSWORD || 'password',
  port: process.env.DB_PORT || 5432,
  max: 20,
  idleTimeoutMillis: 0, // 0 = connections never timeout
  connectionTimeoutMillis: 5000, // 5 seconds
  keepAlive: true,
  keepAliveInitialDelayMillis: 10000,
  allowExitOnIdle: false // Prevent pool from allowing process to exit
});

// Connection retry configuration
let dbConnected = false;
let retryCount = 0;
const maxRetries = 10;
const baseDelay = 1000; // 1 second

// Enhanced connection validation
pool.on('error', (err) => {
  console.error('Unexpected pool error:', err);
  dbConnected = false;
  attemptReconnection();
});

// Connection validation function
async function validateConnection() {
  try {
    const result = await pool.query('SELECT 1');
    dbConnected = true;
    retryCount = 0;
    return true;
  } catch (error) {
    dbConnected = false;
    return false;
  }
}

// Reconnection with exponential backoff
async function attemptReconnection() {
  if (retryCount >= maxRetries) {
    console.error('Max reconnection attempts reached');
    return;
  }
  
  const delay = Math.min(baseDelay * Math.pow(2, retryCount), 60000); // Max 60s delay
  retryCount++;
  
  console.log(`Attempting database reconnection ${retryCount}/${maxRetries} in ${delay}ms...`);
  
  setTimeout(async () => {
    const connected = await validateConnection();
    if (connected) {
      console.log('Database reconnection successful');
    } else {
      attemptReconnection();
    }
  }, delay);
}

// Test database connection with retry
async function initializeDatabase() {
  const connected = await validateConnection();
  if (connected) {
    console.log('Database connected successfully');
  } else {
    console.error('Initial database connection failed');
    attemptReconnection();
  }
}

initializeDatabase();

// GET /api/posts - Get posts with pagination and filtering
app.get('/api/posts', async (req, res) => {
  try {
    const { page = 0, limit = 10, category, ascending = 'false' } = req.query;
    const offset = page * limit;
    const order = ascending === 'true' ? 'ASC' : 'DESC';
    
    let query = `
      SELECT id, title, content, category, created_at 
      FROM blog_posts 
    `;
    let params = [];
    
    if (category) {
      query += ` WHERE category = $1`;
      params.push(category);
    }
    
    query += ` ORDER BY created_at ${order} LIMIT $${params.length + 1} OFFSET $${params.length + 2}`;
    params.push(limit, offset);
    
    // Validate connection before query
    if (!dbConnected) {
      const connected = await validateConnection();
      if (!connected) {
        return res.status(503).json({ error: 'Database temporarily unavailable' });
      }
    }
    
    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching posts:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /api/posts - Create new post
app.post('/api/posts', async (req, res) => {
  try {
    const { title, content, category } = req.body;
    
    if (!title || !content) {
      return res.status(400).json({ error: 'Title and content are required' });
    }
    
    const query = `
      INSERT INTO blog_posts (title, content, category, created_at)
      VALUES ($1, $2, $3, NOW())
      RETURNING id, title, content, category, created_at
    `;
    
    // Validate connection before query
    if (!dbConnected) {
      const connected = await validateConnection();
      if (!connected) {
        return res.status(503).json({ error: 'Database temporarily unavailable' });
      }
    }
    
    const result = await pool.query(query, [title, content, category || 'thought']);
    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('Error creating post:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Enhanced health check endpoint
app.get('/health', async (req, res) => {
  const health = {
    status: 'OK',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    checks: {
      database: 'unknown',
      memory: 'unknown',
      connections: 'unknown'
    }
  };
  
  // Check database
  try {
    const dbCheck = await pool.query('SELECT 1');
    health.checks.database = 'healthy';
  } catch (error) {
    health.checks.database = 'unhealthy';
    health.status = 'DEGRADED';
    console.error('Health check database error:', error.message);
  }
  
  // Check memory usage
  const memUsage = process.memoryUsage();
  const heapUsedMB = memUsage.heapUsed / 1024 / 1024;
  if (heapUsedMB > 500) { // Alert if using more than 500MB
    health.checks.memory = 'warning';
    health.memoryUsageMB = Math.round(heapUsedMB);
  } else {
    health.checks.memory = 'healthy';
  }
  
  // Check pool status
  health.checks.connections = {
    total: pool.totalCount,
    idle: pool.idleCount,
    waiting: pool.waitingCount
  };
  
  // Return appropriate status code
  const statusCode = health.status === 'OK' ? 200 : 503;
  res.status(statusCode).json(health);
});

// Enhanced keep-alive system
let consecutiveFailures = 0;
const maxConsecutiveFailures = 3;

// Keep-alive: Ping database every 10 seconds for aggressive keep-alive
setInterval(async () => {
  try {
    // Validate connection before queries
    if (!dbConnected) {
      await validateConnection();
    }
    
    await pool.query('SELECT 1');
    consecutiveFailures = 0;
    console.log(`Keep-alive: Database ping successful (${new Date().toISOString()})`);
  } catch (error) {
    consecutiveFailures++;
    console.error(`Keep-alive: Database ping failed (${consecutiveFailures}/${maxConsecutiveFailures}):`, error.message);
    
    if (consecutiveFailures >= maxConsecutiveFailures) {
      console.error('Multiple keep-alive failures detected, attempting reconnection...');
      dbConnected = false;
      attemptReconnection();
    }
  }
}, 10000); // Every 10 seconds to ensure connection never drops

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM received, closing connections...');
  await pool.end();
  process.exit(0);
});

process.on('SIGINT', async () => {
  console.log('SIGINT received, closing connections...');
  await pool.end();
  process.exit(0);
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});