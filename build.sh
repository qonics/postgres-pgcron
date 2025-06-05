#!/bin/bash

set -e

# Configuration
IMAGE_NAME="postgres-pgcron"
IMAGE_TAG="17.5"
FULL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"

echo "🐳 Building PostgreSQL 17.5 with pg_cron and pg_partman"
echo "Image: ${FULL_IMAGE_NAME}"
echo "================================================"

# Create necessary directories
mkdir -p logs
mkdir -p init-scripts
mkdir -p scripts

# Set proper permissions for scripts
chmod +x docker-entrypoint.sh
chmod +x scripts/*.sh

# Build the Docker image
echo "📦 Building Docker image..."
docker build \
    --no-cache \
    --tag ${FULL_IMAGE_NAME} \
    --tag ${IMAGE_NAME}:latest \
    .

# Verify the build
if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    echo "📋 Image details:"
    docker images ${IMAGE_NAME}
    
    echo ""
    echo "🚀 Quick start commands:"
    echo "  docker run -d --name postgres-test -p 5432:5432 -e POSTGRES_PASSWORD=test123 ${FULL_IMAGE_NAME}"
    echo "  docker-compose up -d"
    echo ""
    echo "🔍 Verify installation:"
    echo "  docker exec -it postgres-test psql -U postgres -c \"SELECT extname FROM pg_extension WHERE extname IN ('pg_cron', 'pg_partman');\""
else
    echo "❌ Build failed!"
    exit 1
fi
