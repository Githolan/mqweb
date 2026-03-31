FROM node:20-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies (use npm install since we use pnpm locally)
RUN npm install --omit=dev

# Copy application files
COPY Examples/ ./Examples/

# Environment variables
ENV TCP_PORT=8080
ENV HTTP_PORT=3030
ENV NODE_ENV=production

# Expose ports
# 8080 - TCP server for MT4 connection
# 3030 - HTTP dashboard
EXPOSE 8080 3030

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3030/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})" || exit 1

# Start server
CMD ["node", "Examples/tcp-server.js"]
