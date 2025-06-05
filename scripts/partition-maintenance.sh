#!/bin/bash

# Script for manual partition maintenance
set -e

echo "=== Running Partition Maintenance ==="

# Configuration
DB_NAME="${POSTGRES_DB:-app_database}"
DB_USER="${POSTGRES_USER:-postgres}"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

echo "Database: $DB_NAME"
echo "User: $DB_USER"
echo "Time: $TIMESTAMP"
echo ""

# Check if PostgreSQL is ready
if ! pg_isready -U "$DB_USER" -d "$DB_NAME"; then
    echo "❌ PostgreSQL is not ready"
    exit 1
fi

# Check if pg_partman is installed
PARTMAN_INSTALLED=$(psql -U "$DB_USER" -d "$DB_NAME" -t -c "
SELECT COUNT(*) FROM pg_extension WHERE extname = 'pg_partman';
" 2>/dev/null || echo "0")

if [ "$PARTMAN_INSTALLED" -eq 0 ]; then
    echo "❌ pg_partman extension is not installed"
    exit 1
fi

echo "✅ pg_partman is installed"

# Check for partitioned tables
PARTITIONED_TABLES=$(psql -U "$DB_USER" -d "$DB_NAME" -t -c "
SELECT COUNT(*) FROM partman.part_config;
" 2>/dev/null || echo "0")

echo "📊 Found $PARTITIONED_TABLES partitioned table(s)"

if [ "$PARTITIONED_TABLES" -eq 0 ]; then
    echo "ℹ️  No partitioned tables found. Nothing to maintain."
    echo ""
    echo "To create a partitioned table, use:"
    echo "  SELECT partman.create_parent('schema.table', 'column', 'range', 'interval');"
    exit 0
fi

echo ""

# Show current partition configuration
echo "🔧 Current partition configuration:"
psql -U "$DB_USER" -d "$DB_NAME" -c "
SELECT 
    parent_table,
    partition_interval,
    retention,
    premake as future_partitions,
    CASE WHEN infinite_time_partitions THEN 'Yes' ELSE 'No' END as infinite_time
FROM partman.part_config
ORDER BY parent_table;
"

echo ""

# Show partition statistics before maintenance
echo "📊 Partition statistics (before maintenance):"
psql -U "$DB_USER" -d "$DB_NAME" -c "
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size,
    CASE 
        WHEN tablename ~ '_p[0-9]{4}_[0-9]{2}_[0-9]{2}$' THEN 
            SUBSTRING(tablename FROM '_p([0-9]{4}_[0-9]{2}_[0-9]{2})$')
        ELSE 'Unknown'
    END as partition_date
FROM pg_partitions 
WHERE partitionlevel = 0
ORDER BY schemaname, tablename;
" 2>/dev/null || echo "No partition statistics available"

echo ""

# Run pg_partman maintenance
echo "🔄 Running pg_partman maintenance..."

# Run maintenance and capture output
MAINTENANCE_OUTPUT=$(psql -U "$DB_USER" -d "$DB_NAME" -c "
SELECT partman.run_maintenance_proc();
" 2>&1)

# Check if maintenance was successful
if [ $? -eq 0 ]; then
    echo "✅ Partition maintenance completed successfully"
    echo ""
    
    # Show what was done (if any output)
    if [[ "$MAINTENANCE_OUTPUT" != *"(1 row)"* ]] && [[ -n "$MAINTENANCE_OUTPUT" ]]; then
        echo "📝 Maintenance output:"
        echo "$MAINTENANCE_OUTPUT"
    fi
else
    echo "❌ Partition maintenance failed"
    echo "Error output:"
    echo "$MAINTENANCE_OUTPUT"
    exit 1
fi

# Show partition statistics after maintenance
echo "📊 Partition statistics (after maintenance):"
psql -U "$DB_USER" -d "$DB_NAME" -c "
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size,
    CASE 
        WHEN tablename ~ '_p[0-9]{4}_[0-9]{2}_[0-9]{2}$' THEN 
            SUBSTRING(tablename FROM '_p([0-9]{4}_[0-9]{2}_[0-9]{2})$')
        ELSE 'Unknown'
    END as partition_date
FROM pg_partitions 
WHERE partitionlevel = 0
ORDER BY schemaname, tablename;
" 2>/dev/null || echo "No partition statistics available"

echo ""

# Check for any issues or warnings
echo "🔍 Checking for maintenance issues..."

# Check for tables that might need attention
TABLES_NEEDING_ATTENTION=$(psql -U "$DB_USER" -d "$DB_NAME" -t -c "
SELECT COUNT(*) 
FROM partman.part_config pc
WHERE pc.premake = 0 
   OR pc.retention IS NULL;
" 2>/dev/null || echo "0")

if [ "$TABLES_NEEDING_ATTENTION" -gt 0 ]; then
    echo "⚠️  Found $TABLES_NEEDING_ATTENTION table(s) that might need attention:"
    psql -U "$DB_USER" -d "$DB_NAME" -c "
    SELECT 
        parent_table,
        CASE WHEN premake = 0 THEN 'No future partitions configured' END,
        CASE WHEN retention IS NULL THEN 'No retention policy set' END
    FROM partman.part_config 
    WHERE premake = 0 OR retention IS NULL;
    "
else
    echo "✅ All partitioned tables are properly configured"
fi

echo ""

# Show next scheduled maintenance (if using pg_cron)
echo "📅 Next scheduled maintenance:"
CRON_JOBS=$(psql -U "$DB_USER" -d "$DB_NAME" -t -c "
SELECT COUNT(*) FROM cron.job WHERE command LIKE '%partman.run_maintenance_proc%';
" 2>/dev/null || echo "0")

if [ "$CRON_JOBS" -gt 0 ]; then
    psql -U "$DB_USER" -d "$DB_NAME" -c "
    SELECT 
        jobname,
        schedule,
        CASE WHEN active THEN 'Active' ELSE 'Inactive' END as status
    FROM cron.job 
    WHERE command LIKE '%partman.run_maintenance_proc%';
    "
else
    echo "ℹ️  No scheduled maintenance jobs found"
    echo "   Consider scheduling with: SELECT cron.schedule('partition-maintenance', '0 2 * * *', 'SELECT partman.run_maintenance_proc();');"
fi

echo ""

# Update table statistics
echo "📈 Updating table statistics..."
psql -U "$DB_USER" -d "$DB_NAME" -c "
DO \$\$
DECLARE
    parent_table_name TEXT;
BEGIN
    FOR parent_table_name IN 
        SELECT parent_table FROM partman.part_config
    LOOP
        EXECUTE 'ANALYZE ' || parent_table_name;
        RAISE NOTICE 'Updated statistics for %', parent_table_name;
    END LOOP;
END \$\$;
" 2>/dev/null || echo "Could not update statistics"

echo ""
echo "=== Maintenance complete ==="

# Summary
echo "📋 Maintenance Summary:"
echo "  Timestamp: $TIMESTAMP"
echo "  Partitioned tables: $PARTITIONED_TABLES"
echo "  Scheduled jobs: $CRON_JOBS"
echo "  Tables needing attention: $TABLES_NEEDING_ATTENTION"
echo ""
echo "💡 Tips:"
echo "  - Run this script regularly or schedule with pg_cron"
echo "  - Monitor partition sizes and adjust retention policies as needed"
echo "  - Check logs for any partition-related warnings"