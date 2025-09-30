# ====================================================================
# Multi-stage Dockerfile for Google Cloud Run
# Optimized for production deployment
# ====================================================================

# Stage 1: Dependencies
FROM node:20-alpine AS dependencies

WORKDIR /usr/src/app

# Copy package files
COPY package*.json ./

# Install production dependencies only
RUN npm ci --only=production --ignore-scripts && \
    npm cache clean --force

# ====================================================================
# Stage 2: Production
FROM node:20-alpine AS production

# Install dumb-init for proper signal handling
RUN apk add --no-cache dumb-init

# Create app directory
WORKDIR /usr/src/app

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Copy dependencies from previous stage
COPY --from=dependencies --chown=nodejs:nodejs /usr/src/app/node_modules ./node_modules

# Copy application source
COPY --chown=nodejs:nodejs package*.json ./
COPY --chown=nodejs:nodejs src ./src
COPY --chown=nodejs:nodejs public ./public

# Create logs directory
RUN mkdir -p logs && chown nodejs:nodejs logs

# Switch to non-root user
USER nodejs

# Cloud Run sets PORT environment variable
# Default to 8080 if not set (Cloud Run default)
ENV PORT=8080
ENV NODE_ENV=production

# Expose port (dynamic from Cloud Run)
EXPOSE ${PORT}

# Health check (optional, Cloud Run has its own)
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD node -e "require('http').get('http://localhost:${PORT}/api/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Use dumb-init to handle signals properly
ENTRYPOINT ["dumb-init", "--"]

# Start the application
CMD ["node", "src/index.js"]