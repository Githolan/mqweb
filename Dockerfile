FROM node:20-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies (use npm install since we use pnpm locally)
RUN npm install --omit=dev

# Copy application files
COPY Examples/ ./Examples/

# Environment variables
ENV NODE_ENV=production
ENV SERVER_MODE=api
ENV HTTP_PORT=3030
ENV TCP_PORT=8080

# Expose HTTP port (API mode only needs 3030)
# TCP port (8080) optional for TCP mode
EXPOSE 3030 8080

# Health check (uses HTTP port)
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3030/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})" || exit 1

# Start script - selects server based on SERVER_MODE
COPY start-server.sh /start-server.sh
RUN chmod +x /start-server.sh
CMD ["/start-server.sh"]
