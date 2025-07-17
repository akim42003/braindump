const { Pool } = require('pg');
require('dotenv').config();

// You'll need to set these environment variables with your Supabase credentials
const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY;

const pool = new Pool({
  user: process.env.DB_USER || 'postgres',
  host: process.env.DB_HOST || 'localhost',
  database: process.env.DB_NAME || 'braindump',
  password: process.env.DB_PASSWORD || 'password',
  port: process.env.DB_PORT || 5432,
});

async function migrateData() {
  if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
    console.error('Please set SUPABASE_URL and SUPABASE_ANON_KEY environment variables');
    process.exit(1);
  }

  try {
    console.log('Starting data migration from Supabase...');
    
    // Fetch all posts from Supabase
    const response = await fetch(`${SUPABASE_URL}/rest/v1/Blog%20Posts?select=*`, {
      headers: {
        'apikey': SUPABASE_ANON_KEY,
        'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
        'Content-Type': 'application/json'
      }
    });

    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }

    const posts = await response.json();
    console.log(`Found ${posts.length} posts to migrate`);

    // Clear existing data (optional)
    await pool.query('DELETE FROM blog_posts');
    console.log('Cleared existing posts');

    // Insert posts into local database
    for (const post of posts) {
      const query = `
        INSERT INTO blog_posts (title, content, category, created_at)
        VALUES ($1, $2, $3, $4)
      `;
      
      await pool.query(query, [
        post.title,
        post.content,
        post.category || 'thought',
        post.created_at ? new Date(post.created_at) : new Date()
      ]);
      
      console.log(`Migrated: ${post.title}`);
    }

    console.log('Migration completed successfully!');
    
  } catch (error) {
    console.error('Migration failed:', error);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

migrateData();