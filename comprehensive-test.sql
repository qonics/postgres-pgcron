-- Comprehensive test for pg_cron and pg_partman extensions

-- Check extensions are installed
\echo 'Testing installed extensions:'
SELECT 
    extname AS extension, 
    extversion AS version,
    extnamespace::regnamespace AS schema
FROM pg_extension 
WHERE extname IN ('pg_cron', 'pg_partman') 
ORDER BY extname;

\echo ''
\echo 'Testing pg_cron functionality:'

-- Test pg_cron job scheduling
SELECT cron.schedule('test-job', '*/5 * * * *', 'SELECT now();');

-- List scheduled jobs  
SELECT jobid, jobname, schedule, active FROM cron.job;

\echo ''
\echo 'Testing pg_partman functionality:'

-- Create test table for partitioning
CREATE TABLE test_events (
    id SERIAL,
    event_date DATE NOT NULL DEFAULT CURRENT_DATE,
    data TEXT
) PARTITION BY RANGE (event_date);

-- Setup partitioning
SELECT partman.create_parent(
    p_parent_table => 'public.test_events',
    p_control => 'event_date',
    p_interval => '1 month'
);

-- Verify partition configuration
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

\echo ''
\echo 'All tests completed successfully!'
