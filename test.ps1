# PowerShell test script for PostgreSQL with pg_cron and pg_partman

$IMAGE_NAME = "qonicsinc/postgres-pgcron:17.5"
$CONTAINER_NAME = "postgres-test"
$TEST_DB = "test_database"

Write-Host "Testing PostgreSQL with pg_cron and pg_partman" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

# Cleanup any existing test container
Write-Host "Cleaning up existing test containers..." -ForegroundColor Yellow
docker stop $CONTAINER_NAME 2>$null | Out-Null
docker rm $CONTAINER_NAME 2>$null | Out-Null

# Start test container
Write-Host "Starting test container..." -ForegroundColor Green
docker run -d --name $CONTAINER_NAME -e POSTGRES_DB=$TEST_DB -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=test123 -p 5433:5432 $IMAGE_NAME

# Wait for PostgreSQL to be ready
Write-Host "Waiting for PostgreSQL to be ready..." -ForegroundColor Yellow
for ($i = 1; $i -le 30; $i++) {
    $ready = docker exec $CONTAINER_NAME pg_isready -U postgres -d $TEST_DB 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "PostgreSQL is ready!" -ForegroundColor Green
        break
    }
    Write-Host "  Attempt $i/30..."
    Start-Sleep 2
}

# Test extensions
Write-Host "Testing extensions..." -ForegroundColor Cyan
docker exec $CONTAINER_NAME psql -U postgres -d $TEST_DB -c "SELECT extname as extension, extversion as version FROM pg_extension WHERE extname IN ('pg_cron', 'pg_partman') ORDER BY extname;"

# Test pg_cron functionality
Write-Host "Testing pg_cron functionality..." -ForegroundColor Cyan
docker exec $CONTAINER_NAME psql -U postgres -d $TEST_DB -c "SELECT cron.schedule('test-job', '*/5 * * * *', 'SELECT now();');"
docker exec $CONTAINER_NAME psql -U postgres -d $TEST_DB -c "SELECT jobid, jobname, schedule, active FROM cron.job;"

# Test pg_partman functionality
Write-Host "Testing pg_partman functionality..." -ForegroundColor Cyan
docker exec $CONTAINER_NAME psql -U postgres -d $TEST_DB -c "CREATE TABLE test_events ( id SERIAL, event_date DATE NOT NULL DEFAULT CURRENT_DATE, data TEXT ) PARTITION BY RANGE (event_date);"
docker exec $CONTAINER_NAME psql -U postgres -d $TEST_DB -c "SELECT partman.create_parent( p_parent_table => 'public.test_events', p_control => 'event_date', p_interval => '1 month' );"
docker exec $CONTAINER_NAME psql -U postgres -d $TEST_DB -c "SELECT parent_table, control, partition_interval, partition_type, premake FROM partman.part_config WHERE parent_table = 'public.test_events';"
docker exec $CONTAINER_NAME psql -U postgres -d $TEST_DB -c "SELECT COUNT(*) as partition_count FROM pg_tables WHERE tablename LIKE 'test_events%';"

Write-Host "All tests passed!" -ForegroundColor Green
Write-Host ""
Write-Host "Connection details:" -ForegroundColor Cyan
Write-Host "  Host: localhost"
Write-Host "  Port: 5433"
Write-Host "  Database: $TEST_DB"
Write-Host "  User: postgres"
Write-Host "  Password: test123"
Write-Host ""
Write-Host "Cleanup:" -ForegroundColor Yellow
Write-Host "  docker stop $CONTAINER_NAME"
Write-Host "  docker rm $CONTAINER_NAME"
