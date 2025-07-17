# Multi-platform build supporting ARM64 for Jetson Nano
FROM node:18-alpine

# Install build dependencies for ARM64 (if needed for npm packages)
RUN apk add --no-cache python3 make g++ gcc

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies using npm install instead of ci for better ARM64 compatibility
RUN npm install --production --no-audit --no-fund && npm cache clean --force

# Copy application code
COPY . .

# Create non-root user for security
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Change ownership of app directory
RUN chown -R nodejs:nodejs /app

USER nodejs

EXPOSE 3000

# Health check using wget (included in alpine by default)
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

CMD ["npm", "start"]