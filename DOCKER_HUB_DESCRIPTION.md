# Docker Hub Description Summary

## Short Description (for Docker Hub)
PostgreSQL 17.5 with pg_cron scheduler and pg_partman auto-partitioning. Production-ready with optimized configuration.

## Full Description (for Docker Hub Overview)

🐘 **PostgreSQL 17.5 with pg_cron & pg_partman**

Production-ready PostgreSQL image with essential extensions for modern applications:

✅ **pg_cron 1.6** - Schedule SQL commands directly from PostgreSQL  
✅ **pg_partman 5.2.4** - Automated table partitioning for large datasets  
✅ **Enhanced Security** - SCRAM-SHA-256 authentication by default  
✅ **Performance Optimized** - Tuned for containerized environments  

## Quick Start
```bash
docker run -d --name postgres-app \
  -e POSTGRES_PASSWORD=your_secure_password \
  -e POSTGRES_DB=your_database \
  -p 5432:5432 \
  qonicsinc/postgres-pgcron:17.5
```

## Perfect For
- **Data Archival**: Automatic partition and cleanup of old data
- **ETL Pipelines**: Schedule data transformation jobs  
- **Analytics**: Partition large fact tables for better performance
- **Log Management**: Automated log rotation and cleanup
- **Time-series Data**: Efficient storage and querying of temporal data

## Key Features
- Production-ready security configuration
- Optimized PostgreSQL settings for containers
- Health checks and comprehensive logging
- Easy integration with existing applications
- Full compatibility with official PostgreSQL image

## Extensions Included
| Extension | Version | Purpose |
|-----------|---------|---------|
| pg_cron | 1.6 | PostgreSQL job scheduler |
| pg_partman | 5.2.4 | Automated table partitioning |

See the README for detailed examples, Kubernetes deployments, and production configurations.

## Tags
- `17.5`, `latest` - PostgreSQL 17.5 with pg_cron 1.6 and pg_partman 5.2.4
