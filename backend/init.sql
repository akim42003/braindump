-- Create database if it doesn't exist
CREATE DATABASE braindump;

-- Connect to braindump database
\c braindump;

-- Create blog_posts table
CREATE TABLE IF NOT EXISTS blog_posts (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    category VARCHAR(50) DEFAULT 'thought',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_blog_posts_category ON blog_posts(category);
CREATE INDEX IF NOT EXISTS idx_blog_posts_created_at ON blog_posts(created_at);

-- Insert sample data (optional)
INSERT INTO blog_posts (title, content, category) VALUES
('Welcome to Local Backend', 'This is the first post from our local backend!', 'thought'),
('Migration Complete', 'Successfully migrated from Supabase to local PostgreSQL', 'answer');