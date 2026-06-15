# Stage 1: Build the Astro client frontend
FROM node:20-alpine AS client-builder
WORKDIR /app/client

# Copy package configurations and install dependencies
COPY src/client/package*.json ./
RUN npm ci

# Copy client source code and build production assets
COPY src/client/ ./
RUN npm run build

# Stage 2: Build the backend and run the application
FROM node:20-alpine
WORKDIR /app/server

# Install build dependencies for sqlite3 compilation on Alpine (ARM64/x86_64)
RUN apk add --no-cache python3 make g++

# Copy backend package configurations and install production dependencies
COPY src/server/package*.json ./
RUN npm ci --only=production

# Copy backend source code
COPY src/server/ ./

# Copy built Astro frontend static assets to the backend's public directory
COPY --from=client-builder /app/client/dist ./public

# Expose server port
EXPOSE 3001

# Production configurations
ENV NODE_ENV=production
ENV PORT=3001
ENV DATABASE_PATH=/data/flowcado.db

# Create persistent storage folder and switch to a non-root user for security
RUN mkdir -p /data && chown -R node:node /data /app/server
USER node

# Start the server
CMD ["node", "server.js"]
