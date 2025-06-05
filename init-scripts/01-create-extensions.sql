-- Create extensions in the main database
-- Note: This script is executed against the target database specified by POSTGRES_DB
-- No need to use \c command as we're already connected to the correct database

-- Create pg_cron extension
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Create pg_partman extension with explicit schema
CREATE SCHEMA IF NOT EXISTS partman;
CREATE EXTENSION IF NOT EXISTS pg_partman SCHEMA partman;

-- Grant necessary permissions for pg_cron
-- Grant usage on the schema to the postgres user (or a dedicated cron user)
GRANT USAGE ON SCHEMA cron TO postgres;

-- Grant specific privileges on cron.job table to allow scheduling and managing jobs
GRANT SELECT, INSERT, UPDATE, DELETE ON cron.job TO postgres;
-- Grant specific privileges on cron.job_run_details for viewing job history
GRANT SELECT, DELETE ON cron.job_run_details TO postgres;
-- Allow postgres user to execute functions in cron schema (like cron.schedule, cron.unschedule)
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA cron TO postgres;


-- Grant necessary permissions for pg_partman (typically managed by superuser or owner of partitioned tables)
-- pg_partman functions are usually executed by a superuser or the table owner.
-- If a less privileged user needs to run maintenance, grant EXECUTE on specific partman functions.
-- For example: GRANT EXECUTE ON FUNCTION partman.run_maintenance_proc() TO specific_user;

-- Verify extensions
SELECT
    extname as "Extension",
    extversion as "Version",
    nspname as "Schema"
FROM
    pg_extension e
    JOIN pg_namespace n ON e.extnamespace = n.oid
WHERE
    extname IN ('pg_cron', 'pg_partman')
ORDER BY
    extname;

-- Show all schemas to verify partman schema exists
SELECT 
    nspname as "Schema Name",
    nspowner as "Owner"
FROM pg_namespace 
WHERE nspname IN ('cron', 'partman', 'public')
ORDER BY nspname;

-- Show available cron functions
SELECT 
    n.nspname as schema,
    p.proname as function_name,
    pg_get_function_identity_arguments(p.oid) as arguments
FROM pg_proc p 
JOIN pg_namespace n ON p.pronamespace = n.oid 
WHERE n.nspname = 'cron'
ORDER BY p.proname;

-- Show available partman functions
SELECT 
    n.nspname as schema,
    p.proname as function_name,
    pg_get_function_identity_arguments(p.oid) as arguments
FROM pg_proc p 
JOIN pg_namespace n ON p.pronamespace = n.oid 
WHERE n.nspname = 'partman'
ORDER BY p.proname;

-- Display success message
DO $$ 
BEGIN 
    RAISE NOTICE 'Extensions pg_cron and pg_partman have been successfully installed!';
    RAISE NOTICE 'Database: %', current_database();
    RAISE NOTICE 'Time: %', now();
END 
$$;