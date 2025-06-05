# 🐘 PostgreSQL 17.5 with pg_cron & pg_partman

[![Docker Pulls](https://img.shields.io/docker/pulls/qonicsinc/postgres-pgcron)](https://hub.docker.com/r/qonicsinc/postgres-pgcron)
[![Docker Image Size](https://img.shields.io/docker/image-size/qonicsinc/postgres-pgcron/17.5)](https://hub.docker.com/r/qonicsinc/postgres-pgcron)
[![PostgreSQL Version](https://img.shields.io/badge/PostgreSQL-17.5-blue)](https://www.postgresql.org/)

A **production-ready** PostgreSQL 17.5 Docker image with essential extensions for modern applications:

- 🕐 **pg_cron** - Schedule SQL commands directly from PostgreSQL
- 📊 **pg_partman** - Automated table partitioning for large datasets
- 🔒 **Enhanced Security** - SCRAM-SHA-256 authentication by default
- ⚡ **Optimized Configuration** - Performance-tuned for containerized environments

## 🚀 Quick Start

### Using Docker

```bash
# Basic usage
docker run -d --name postgres-app \
  -e POSTGRES_PASSWORD=your_secure_password \
  -e POSTGRES_DB=your_database \
  -p 5432:5432 \
  qonicsinc/postgres-pgcron:17.5
```

### Using Docker Compose

```yaml
version: '3.8'
services:
  postgres:
    image: qonicsinc/postgres-pgcron:17.5
    environment:
      POSTGRES_DB: myapp
      POSTGRES_PASSWORD: secure_password
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 30s
      timeout: 10s
      retries: 3

volumes:
  postgres_data:
```

## 📋 Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `POSTGRES_DB` | `postgres` | Default database name |
| `POSTGRES_USER` | `postgres` | PostgreSQL superuser name |
| `POSTGRES_PASSWORD` | **Required** | PostgreSQL password |
| `POSTGRES_INITDB_ARGS` | `--auth-host=scram-sha-256` | Additional initdb arguments |

## 🔧 Pre-installed Extensions

### pg_cron (v1.6)
Schedule and run SQL commands on a recurring basis.

```sql
-- Schedule a daily cleanup job
SELECT cron.schedule(
    'daily-cleanup',
    '0 2 * * *',  -- Every day at 2 AM
    'DELETE FROM logs WHERE created_at < NOW() - INTERVAL ''30 days'';'
);

-- List all scheduled jobs
SELECT jobid, jobname, schedule, active FROM cron.job;

-- View job execution history
SELECT * FROM cron.job_run_details 
ORDER BY start_time DESC LIMIT 10;
```

### pg_partman (v5.2.4)
Automated table partitioning management for improved performance on large datasets.

```sql
-- Create a partitioned table
CREATE TABLE sales_data (
    id SERIAL,
    sale_date DATE NOT NULL,
    amount DECIMAL(10,2),
    customer_id INTEGER
) PARTITION BY RANGE (sale_date);

-- Set up automatic monthly partitioning
SELECT partman.create_parent(
    p_parent_table => 'public.sales_data',
    p_control => 'sale_date',
    p_interval => '1 month'
);

-- Schedule automatic partition maintenance
SELECT cron.schedule(
    'partition-maintenance',
    '0 1 * * *',  -- Daily at 1 AM
    'SELECT partman.run_maintenance_proc();'
);
```

## 💡 Real-World Examples

### E-commerce Analytics Pipeline

```sql
-- Create partitioned events table
CREATE TABLE user_events (
    id BIGSERIAL,
    user_id INTEGER NOT NULL,
    event_type VARCHAR(50) NOT NULL,
    event_data JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
) PARTITION BY RANGE (created_at);

-- Set up weekly partitions with 4-week retention
SELECT partman.create_parent(
    p_parent_table => 'public.user_events',
    p_control => 'created_at',
    p_interval => '1 week'
);

UPDATE partman.part_config 
SET retention = '4 weeks', 
    retention_keep_table = false
WHERE parent_table = 'public.user_events';

-- Daily aggregation job
SELECT cron.schedule(
    'daily-analytics',
    '0 6 * * *',
    'INSERT INTO daily_stats 
     SELECT DATE(created_at), event_type, COUNT(*) 
     FROM user_events 
     WHERE created_at >= CURRENT_DATE - INTERVAL ''1 day''
     GROUP BY DATE(created_at), event_type;'
);
```

### Financial Data with 6-Month Partitions

```sql
-- Account balances with 6-month partitions
CREATE TABLE account_balances (
    id SERIAL,
    account_id INTEGER NOT NULL,
    balance DECIMAL(19,4) NOT NULL,
    currency CHAR(3) NOT NULL,
    as_of_date DATE NOT NULL
) PARTITION BY RANGE (as_of_date);

-- 6-month partitions, keep 2 years of data
SELECT partman.create_parent(
    p_parent_table => 'public.account_balances',
    p_control => 'as_of_date',
    p_interval => '6 months'
);

UPDATE partman.part_config 
SET retention = '2 years',
    premake = 2  -- Keep 2 future partitions ready
WHERE parent_table = 'public.account_balances';
```

## 🔐 Security Features

- **SCRAM-SHA-256 Authentication**: Modern password authentication
- **Configurable pg_hba.conf**: Customize connection security
- **Non-root Execution**: PostgreSQL runs as dedicated `postgres` user
- **Secure Defaults**: Production-ready security configuration

## ⚡ Performance Optimizations

The image includes performance-tuned configuration:

```conf
# Memory settings optimized for containers
shared_buffers = 256MB
effective_cache_size = 1GB
work_mem = 4MB
maintenance_work_mem = 64MB

# Connection and concurrency
max_connections = 200
effective_io_concurrency = 200

# WAL and checkpoints
wal_level = replica
max_wal_size = 2GB
checkpoint_completion_target = 0.9

# Query optimization
random_page_cost = 1.1
```

## 📊 Monitoring & Management

### Health Checks

```bash
# Container health check
docker exec postgres-app pg_isready -U postgres

# Extension verification
docker exec postgres-app psql -U postgres -c "
  SELECT name, installed_version 
  FROM pg_available_extensions 
  WHERE installed_version IS NOT NULL 
  AND name IN ('pg_cron', 'pg_partman');"
```

### Job Monitoring

```sql
-- Monitor cron job performance
SELECT 
    jobname,
    schedule,
    COUNT(*) as executions,
    AVG(EXTRACT(EPOCH FROM (end_time - start_time))) as avg_duration_seconds,
    SUM(CASE WHEN succeeded THEN 1 ELSE 0 END) as successful_runs
FROM cron.job_run_details 
WHERE start_time >= NOW() - INTERVAL '7 days'
GROUP BY jobname, schedule;

-- Check partition sizes
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables 
WHERE tablename LIKE 'user_events_%'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

## 🐳 Production Deployment

### Kubernetes

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres-pgcron
spec:
  serviceName: postgres-pgcron
  replicas: 1
  selector:
    matchLabels:
      app: postgres-pgcron
  template:
    metadata:
      labels:
        app: postgres-pgcron
    spec:
      containers:
      - name: postgres
        image: qonicsinc/postgres-pgcron:17.5
        env:
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: password
        - name: POSTGRES_DB
          value: "production_db"
        ports:
        - containerPort: 5432
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
        livenessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - postgres
          initialDelaySeconds: 30
          periodSeconds: 10
  volumeClaimTemplates:
  - metadata:
      name: postgres-storage
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 100Gi
```

### Docker Swarm

```yaml
version: '3.8'
services:
  postgres:
    image: qonicsinc/postgres-pgcron:17.5
    environment:
      POSTGRES_PASSWORD_FILE: /run/secrets/postgres_password
      POSTGRES_DB: production_db
    secrets:
      - postgres_password
    volumes:
      - postgres_data:/var/lib/postgresql/data
    deploy:
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      restart_policy:
        condition: on-failure

secrets:
  postgres_password:
    external: true

volumes:
  postgres_data:
    driver: local
```

## 🔧 Customization

### Custom Configuration

```bash
# Mount custom postgresql.conf
docker run -d \
  -v ./my-postgresql.conf:/etc/postgresql/postgresql.conf:ro \
  qonicsinc/postgres-pgcron:17.5
```

### Custom Initialization Scripts

```bash
# Add custom SQL scripts
docker run -d \
  -v ./init-scripts:/docker-entrypoint-initdb.d:ro \
  qonicsinc/postgres-pgcron:17.5
```

## 🐛 Troubleshooting

### Common Issues

**Extensions not found:**
```sql
-- Check if extensions are available
SELECT * FROM pg_available_extensions 
WHERE name IN ('pg_cron', 'pg_partman');

-- Verify current database
SELECT current_database();
```

**pg_cron jobs not running:**
```sql
-- Check cron configuration
SHOW shared_preload_libraries;
SHOW cron.database_name;

-- Verify job status
SELECT * FROM cron.job WHERE active = true;
```

**Connection issues:**
```bash
# Check container logs
docker logs postgres-app

# Verify container health
docker exec postgres-app pg_isready -U postgres
```

## 📖 Documentation

- [PostgreSQL 17 Documentation](https://www.postgresql.org/docs/17/)
- [pg_cron Extension](https://github.com/citusdata/pg_cron)
- [pg_partman Extension](https://github.com/pgpartman/pg_partman)

## 🤝 Contributing

Issues and pull requests are welcome! Please visit our [GitHub repository](https://github.com/qonicsinc/postgres-pgcron) for more information.

## 📄 License

This image is based on the official PostgreSQL Docker image and includes additional open-source extensions. See individual component licenses for details.