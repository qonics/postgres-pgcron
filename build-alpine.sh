#!/bin/bash

# Build script for PostgreSQL with pg_cron and pg_partman (Alpine version)

set -e

# Configuration
IMAGE_NAME="qonicsinc/postgres-pgcron"
VERSION="17.5"
ALPINE_TAG="${VERSION}-alpine"
LATEST_ALPINE_TAG="alpine"

echo "🏔️  Building PostgreSQL ${VERSION} Alpine with pg_cron and pg_partman"
echo "=================================================================="

# Build Alpine image
echo "🔨 Building Alpine image..."
docker build \
    -f Dockerfile.alpine \
    -t "${IMAGE_NAME}:${ALPINE_TAG}" \
    -t "${IMAGE_NAME}:${LATEST_ALPINE_TAG}" \
    --build-arg BUILDKIT_INLINE_CACHE=1 \
    .

echo "✅ Alpine build completed successfully!"

# Verify the image
echo "🔍 Verifying Alpine image..."
docker run --rm "${IMAGE_NAME}:${ALPINE_TAG}" postgres --version
docker run --rm "${IMAGE_NAME}:${ALPINE_TAG}" sh -c "ls -la /usr/local/share/postgresql/extension/ | grep -E '(pg_cron|partman)'"

echo "📦 Alpine image details:"
docker images "${IMAGE_NAME}" | grep alpine

echo ""
echo "🎉 Alpine build completed successfully!"
echo ""
echo "🏷️  Available tags:"
echo "   - ${IMAGE_NAME}:${ALPINE_TAG}"
echo "   - ${IMAGE_NAME}:${LATEST_ALPINE_TAG}"
echo ""
echo "📏 Image size comparison:"
docker images "${IMAGE_NAME}" --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}" | head -5
echo ""
echo "🚢 To push to registry:"
echo "   docker push ${IMAGE_NAME}:${ALPINE_TAG}"
echo "   docker push ${IMAGE_NAME}:${LATEST_ALPINE_TAG}"
