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
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
  keepAlive: true,
  keepAliveInitialDelayMillis: 10000
});

// Test database connection
pool.query('SELECT NOW()', (err, res) => {
  if (err) {
    console.error('Database connection error:', err);
  } else {
    console.log('Database connected successfully');
  }
});

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
    
    const result = await pool.query(query, [title, content, category || 'thought']);
    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('Error creating post:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Health check endpoint that also pings database
app.get('/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ status: 'OK', timestamp: new Date().toISOString(), database: 'connected' });
  } catch (error) {
    console.error('Health check database error:', error);
    res.json({ status: 'OK', timestamp: new Date().toISOString(), database: 'error' });
  }
});

// Keep-alive: Ping database every 30 seconds
setInterval(async () => {
  try {
    await pool.query('SELECT 1');
    console.log('Keep-alive: Database ping successful');
  } catch (error) {
    console.error('Keep-alive: Database ping failed:', error);
  }
}, 30000);

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});