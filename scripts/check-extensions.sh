#!/bin/bash

# Script to verify extensions are properly installed
echo "=== PostgreSQL Extensions Check ==="

# Configuration
DB_NAME="${POSTGRES_DB:-app_database}"
DB_USER="${POSTGRES_USER:-postgres}"

# Check if PostgreSQL is running
if ! pg_isready -U "$DB_USER" -d "$DB_NAME"; then
    echo "❌ PostgreSQL is not ready"
    exit 1
fi

echo "✅ PostgreSQL is ready"
echo ""

# Check PostgreSQL version
echo "🐘 PostgreSQL Version:"
psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT version();" | head -1
echo ""

# Check extensions
echo "📦 Checking installed extensions..."
psql -U "$DB_USER" -d "$DB_NAME" -c "
SELECT 
    '✅ ' || extname as extension,
    extversion as version,
    nspname as schema
FROM pg_extension e
JOIN pg_namespace n ON e.extnamespace = n.oid
WHERE extname IN ('pg_cron', 'pg_partman')
ORDER BY extname;
" -t

# Check if extensions are available but not installed
echo ""
echo "📋 Available extensions status:"
psql -U "$DB_USER" -d "$DB_NAME" -c "
SELECT 
    name,
    CASE 
        WHEN installed_version IS NOT NULL THEN '✅ INSTALLED (' || installed_version || ')'
        ELSE '⚠️  AVAILABLE (' || default_version || ')'
    END as status
FROM pg_available_extensions 
WHERE name IN ('pg_cron', 'pg_partman')
ORDER BY name;
"

echo ""

# Check pg_cron specific configuration
echo "⏰ Checking pg_cron configuration..."
psql -U "$DB_USER" -d "$DB_NAME" -c "
SELECT 
    name,
    setting
FROM pg_settings 
WHERE name IN ('shared_preload_libraries', 'cron.database_name', 'cron.max_running_jobs')
ORDER BY name;
"

echo ""

# Check pg_cron jobs
echo "📅 Checking pg_cron jobs..."
JOB_COUNT=$(psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM cron.job;" 2>/dev/null || echo "0")

if [ "$JOB_COUNT" -gt 0 ]; then
    echo "Found $JOB_COUNT scheduled job(s):"
    psql -U "$DB_USER" -d "$DB_NAME" -c "
    SELECT 
        jobid,
        jobname,
        schedule,
        CASE WHEN active THEN '✅ Active' ELSE '❌ Inactive' END as status
    FROM cron.job
    ORDER BY jobid;
    "
else
    echo "ℹ️  No scheduled jobs found"
fi

echo ""

# Check recent job executions
echo "📊 Recent job executions (last 5):"
EXEC_COUNT=$(psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM cron.job_run_details;" 2>/dev/null || echo "0")

if [ "$EXEC_COUNT" -gt 0 ]; then
    psql -U "$DB_USER" -d "$DB_NAME" -c "
    SELECT 
        job_name,
        start_time,
        CASE WHEN succeeded THEN '✅ Success' ELSE '❌ Failed' END as result,
        CASE WHEN return_message IS NOT NULL THEN SUBSTRING(return_message, 1, 50) ELSE 'No message' END as message
    FROM cron.job_run_details 
    ORDER BY start_time DESC 
    LIMIT 5;
    "
else
    echo "ℹ️  No job execution history found"
fi

echo ""

# Check partman configuration
echo "🔧 Checking pg_partman configuration..."
PARTMAN_COUNT=$(psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM partman.part_config;" 2>/dev/null || echo "0")

if [ "$PARTMAN_COUNT" -gt 0 ]; then
    echo "Found $PARTMAN_COUNT partitioned table(s):"
    psql -U "$DB_USER" -d "$DB_NAME" -c "
    SELECT 
        parent_table,
        partition_interval,
        retention,
        CASE WHEN infinite_time_partitions THEN 'Infinite' ELSE 'Limited' END as time_partitions
    FROM partman.part_config
    ORDER BY parent_table;
    "
else
    echo "ℹ️  No partitioned tables configured"
fi

echo ""

# Test pg_cron functionality
echo "🧪 Testing pg_cron functionality..."
TEST_JOB_NAME="extension-test-$(date +%s)"

# Schedule a test job
psql -U "$DB_USER" -d "$DB_NAME" -c "
SELECT cron.schedule('$TEST_JOB_NAME', '* * * * *', 'SELECT ''pg_cron test job executed at '' || now();');
" > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "✅ Successfully scheduled test job"
    
    # Wait a moment then check if job was created
    sleep 1
    
    # Remove the test job
    psql -U "$DB_USER" -d "$DB_NAME" -c "
    SELECT cron.unschedule('$TEST_JOB_NAME');
    " > /dev/null 2>&1
    
    echo "✅ Successfully removed test job"
else
    echo "❌ Failed to schedule test job"
fi

echo ""
echo "=== Extensions check complete ==="

# Summary
echo ""
echo "📋 Summary:"
echo "  Database: $DB_NAME"
echo "  User: $DB_USER"
echo "  pg_cron jobs: $JOB_COUNT"
echo "  pg_partman tables: $PARTMAN_COUNT"
echo "  Job executions: $EXEC_COUNT"