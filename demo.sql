-- =====================================================
-- PostgreSQL with pg_cron and pg_partman Demo
-- =====================================================

-- This demo script showcases the capabilities of this Docker image
-- Run this after connecting to your database

\echo '🐘 PostgreSQL with pg_cron and pg_partman Demo'
\echo '=============================================='

-- Check PostgreSQL version and extensions
SELECT 
    'PostgreSQL Version: ' || version() as info
UNION ALL
SELECT 
    'Extensions loaded: ' || string_agg(extname, ', ' ORDER BY extname) 
FROM pg_extension 
WHERE extname IN ('pg_cron', 'pg_partman');

\echo ''
\echo '📊 Creating a sample e-commerce analytics table...'

-- Create a partitioned table for e-commerce events
CREATE TABLE IF NOT EXISTS user_events (
    id BIGSERIAL,
    user_id INTEGER NOT NULL,
    event_type VARCHAR(50) NOT NULL,
    product_id INTEGER,
    session_id UUID,
    event_data JSONB,
    revenue DECIMAL(10,2),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Indexes for common queries
    INDEX (user_id),
    INDEX (event_type),
    INDEX (created_at),
    INDEX USING GIN (event_data)
) PARTITION BY RANGE (created_at);

\echo '✅ Table created successfully!'

\echo ''
\echo '🔧 Setting up automatic monthly partitioning...'

-- Set up monthly partitioning
SELECT partman.create_parent(
    p_parent_table => 'public.user_events',
    p_control => 'created_at',
    p_interval => '1 month',
    p_premake => 2  -- Create 2 future partitions
);

-- Configure retention: keep 6 months of data
UPDATE partman.part_config 
SET 
    retention = '6 months',
    retention_keep_table = false,  -- Actually drop old partitions
    automatic_maintenance = 'on'
WHERE parent_table = 'public.user_events';

\echo '✅ Partitioning configured successfully!'

\echo ''
\echo '⏰ Setting up automated maintenance jobs...'

-- Job 1: Daily partition maintenance
SELECT cron.schedule(
    'partition-maintenance',
    '0 2 * * *',  -- Daily at 2 AM
    'SELECT partman.run_maintenance_proc();'
);

-- Job 2: Weekly analytics aggregation
SELECT cron.schedule(
    'weekly-analytics',
    '0 6 * * 1',  -- Monday at 6 AM
    $$
    INSERT INTO weekly_analytics (week_start, event_type, total_events, total_revenue)
    SELECT 
        DATE_TRUNC('week', created_at) as week_start,
        event_type,
        COUNT(*) as total_events,
        COALESCE(SUM(revenue), 0) as total_revenue
    FROM user_events 
    WHERE created_at >= NOW() - INTERVAL '1 week'
    GROUP BY DATE_TRUNC('week', created_at), event_type
    ON CONFLICT (week_start, event_type) 
    DO UPDATE SET 
        total_events = EXCLUDED.total_events,
        total_revenue = EXCLUDED.total_revenue;
    $$
);

-- Job 3: Daily cleanup of temporary data
SELECT cron.schedule(
    'cleanup-temp-data',
    '0 4 * * *',  -- Daily at 4 AM
    'DELETE FROM temporary_sessions WHERE created_at < NOW() - INTERVAL ''24 hours'';'
);

\echo '✅ Scheduled jobs created successfully!'

\echo ''
\echo '📊 Creating supporting tables...'

-- Create analytics summary table
CREATE TABLE IF NOT EXISTS weekly_analytics (
    id SERIAL PRIMARY KEY,
    week_start DATE NOT NULL,
    event_type VARCHAR(50) NOT NULL,
    total_events BIGINT NOT NULL,
    total_revenue DECIMAL(12,2) NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE (week_start, event_type)
);

-- Create temporary sessions table for cleanup demo
CREATE TABLE IF NOT EXISTS temporary_sessions (
    session_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id INTEGER,
    data JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

\echo '✅ Supporting tables created!'

\echo ''
\echo '🧪 Inserting sample data...'

-- Insert sample e-commerce events
INSERT INTO user_events (user_id, event_type, product_id, session_id, event_data, revenue, created_at)
VALUES 
    -- Recent events (current month)
    (1001, 'page_view', 101, gen_random_uuid(), '{"page": "/product/101", "referrer": "google"}', NULL, NOW()),
    (1001, 'add_to_cart', 101, gen_random_uuid(), '{"quantity": 2}', NULL, NOW() - INTERVAL '1 hour'),
    (1001, 'purchase', 101, gen_random_uuid(), '{"quantity": 2, "payment_method": "card"}', 199.98, NOW() - INTERVAL '30 minutes'),
    
    (1002, 'page_view', 102, gen_random_uuid(), '{"page": "/product/102"}', NULL, NOW() - INTERVAL '2 hours'),
    (1002, 'purchase', 102, gen_random_uuid(), '{"quantity": 1, "payment_method": "paypal"}', 49.99, NOW() - INTERVAL '1 hour'),
    
    -- Historical events (previous months) - these will go to different partitions
    (1003, 'page_view', 103, gen_random_uuid(), '{"page": "/product/103"}', NULL, NOW() - INTERVAL '1 month'),
    (1003, 'purchase', 103, gen_random_uuid(), '{"quantity": 3, "payment_method": "card"}', 149.97, NOW() - INTERVAL '1 month' + INTERVAL '1 hour'),
    
    (1004, 'page_view', 104, gen_random_uuid(), '{"page": "/category/electronics"}', NULL, NOW() - INTERVAL '2 months'),
    (1004, 'add_to_cart', 104, gen_random_uuid(), '{"quantity": 1}', NULL, NOW() - INTERVAL '2 months' + INTERVAL '30 minutes'),
    (1004, 'purchase', 104, gen_random_uuid(), '{"quantity": 1, "payment_method": "card"}', 299.99, NOW() - INTERVAL '2 months' + INTERVAL '1 hour');

-- Insert some temporary session data for cleanup demo
INSERT INTO temporary_sessions (user_id, data)
VALUES 
    (1001, '{"cart_items": [101, 102], "total": 249.97}'),
    (1002, '{"search_terms": ["electronics", "laptop"]}'),
    (1003, '{"wishlist": [201, 202, 203]}');

\echo '✅ Sample data inserted!'

\echo ''
\echo '📈 Verification and Statistics'
\echo '=============================='

-- Show partition information
\echo 'Created partitions:'
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables 
WHERE tablename LIKE 'user_events_%'
ORDER BY tablename;

-- Show data distribution across partitions
\echo ''
\echo 'Data distribution across partitions:'
SELECT 
    tableoid::regclass as partition_name,
    COUNT(*) as event_count,
    MIN(created_at) as earliest_event,
    MAX(created_at) as latest_event
FROM user_events
GROUP BY tableoid::regclass
ORDER BY earliest_event;

-- Show scheduled jobs
\echo ''
\echo 'Scheduled jobs:'
SELECT 
    jobid,
    jobname,
    schedule,
    active,
    database
FROM cron.job
ORDER BY jobname;

-- Show partition configuration
\echo ''
\echo 'Partition configuration:'
SELECT 
    parent_table,
    control,
    partition_interval,
    partition_type,
    premake,
    retention,
    automatic_maintenance
FROM partman.part_config;

-- Performance test: Query with partition pruning
\echo ''
\echo 'Query performance test (with partition pruning):'
EXPLAIN (ANALYZE, BUFFERS) 
SELECT 
    event_type,
    COUNT(*) as event_count,
    SUM(revenue) as total_revenue
FROM user_events 
WHERE created_at >= NOW() - INTERVAL '1 month'
GROUP BY event_type;

\echo ''
\echo '🎉 Demo completed successfully!'
\echo ''
\echo '📋 What you can do next:'
\echo '• Monitor job execution: SELECT * FROM cron.job_run_details ORDER BY start_time DESC LIMIT 10;'
\echo '• Check partition sizes: SELECT pg_size_pretty(pg_database_size(current_database()));'
\echo '• Add more partitions: SELECT partman.create_partition_time(''public.user_events'', ARRAY[NOW() + INTERVAL ''1 month'']);'
\echo '• Test partition pruning: Run queries with WHERE clauses on created_at'
\echo ''
\echo '🔗 Useful queries:'
\echo '• Show all partitions: \\dt user_events*'
\echo '• Job history: SELECT * FROM cron.job_run_details;'
\echo '• Manual maintenance: SELECT partman.run_maintenance_proc();'
