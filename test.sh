#!/bin/bash

set -e

IMAGE_NAME="qonicsinc/postgres-pgcron:17.5"
CONTAINER_NAME="postgres-test"
TEST_DB="test_database"

echo "🧪 Testing PostgreSQL with pg_cron and pg_partman"
echo "================================================"

# Cleanup any existing test container
echo "🧹 Cleaning up existing test containers..."
docker stop ${CONTAINER_NAME} 2>/dev/null || true
docker rm ${CONTAINER_NAME} 2>/dev/null || true

# Start test container
echo "🚀 Starting test container..."
docker run -d \
    --name ${CONTAINER_NAME} \
    -e POSTGRES_DB=${TEST_DB} \
    -e POSTGRES_USER=postgres \
    -e POSTGRES_PASSWORD=test123 \
    -p 5433:5432 \
    ${IMAGE_NAME}

# Wait for PostgreSQL to be ready
echo "⏳ Waiting for PostgreSQL to be ready..."
for i in {1..30}; do
    if docker exec ${CONTAINER_NAME} pg_isready -U postgres -d ${TEST_DB} >/dev/null 2>&1; then
        break
    fi
    echo "  Attempt $i/30..."
    sleep 2
done

# Test extensions
echo "🔍 Testing extensions..."
docker exec ${CONTAINER_NAME} psql -U postgres -d ${TEST_DB} -c "
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_partman;

SELECT 
    '✅ ' || extname as extension,
    extversion as version
FROM pg_extension 
WHERE extname IN ('pg_cron', 'pg_partman')
ORDER BY extname;
"

# Test pg_cron functionality
echo "⏰ Testing pg_cron functionality..."
docker exec ${CONTAINER_NAME} psql -U postgres -d ${TEST_DB} -c "
-- Schedule a test job
SELECT cron.schedule('test-job', '*/5 * * * *', 'SELECT now();');

-- List jobs
SELECT jobid, jobname, schedule, active FROM cron.job;
"

# Test pg_partman functionality
echo "🔧 Testing pg_partman functionality..."
docker exec ${CONTAINER_NAME} psql -U postgres -d ${TEST_DB} -c "
-- Create test table
CREATE TABLE test_events (
    id SERIAL,
    event_date DATE NOT NULL DEFAULT CURRENT_DATE,
    data TEXT
) PARTITION BY RANGE (event_date);

-- Setup partitioning with correct parameters
SELECT partman.create_parent(
    p_parent_table => 'public.test_events',
    p_control => 'event_date',
    p_interval => '1 month'
);

-- Verify partition was created
SELECT 
    parent_table,
    control,
    partition_interval,
    partition_type,
    premake
FROM partman.part_config 
WHERE parent_table = 'public.test_events';

-- Count created partitions
SELECT COUNT(*) as partition_count 
FROM pg_tables 
WHERE tablename LIKE 'test_events%';
"

echo "✅ All tests passed!"
echo ""
echo "🔗 Connection details:"
echo "  Host: localhost"
echo "  Port: 5433"
echo "  Database: ${TEST_DB}"
echo "  User: postgres"
echo "  Password: test123"
echo ""
echo "🧹 Cleanup:"
echo "  docker stop ${CONTAINER_NAME} && docker rm ${CONTAINER_NAME}"
