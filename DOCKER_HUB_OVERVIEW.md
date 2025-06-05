# Quick Reference

- **Maintained by**: QonicsInc
- **Where to get help**: [GitHub Issues](https://github.com/qonicsinc/postgres-pgcron/issues)
- **Where to file issues**: [GitHub Issues](https://github.com/qonicsinc/postgres-pgcron/issues)
- **Supported architectures**: `amd64`, `arm64`

## Supported tags and respective `Dockerfile` links

- `17.5`, `latest` - PostgreSQL 17.5 with pg_cron 1.6 and pg_partman 5.2.4

## Quick reference (cont.)

- **Where to file issues**: [GitHub Issues](https://github.com/qonicsinc/postgres-pgcron/issues)
- **Supported Docker versions**: 20.10.0+

## What is PostgreSQL with pg_cron and pg_partman?

This image extends the official PostgreSQL 17.5 image with two essential extensions:

- **pg_cron**: Run scheduled SQL commands directly from PostgreSQL
- **pg_partman**: Automated table partitioning for better performance on large datasets

Perfect for applications that need automated database maintenance, data lifecycle management, and improved query performance on time-series data.

## How to use this image

### Start a PostgreSQL instance

```bash
docker run --name my-postgres -e POSTGRES_PASSWORD=mysecretpassword -d qonicsinc/postgres-pgcron:17.5
```

### Connect from your application

```bash
docker run -it --rm --network host qonicsinc/postgres-pgcron:17.5 psql -h localhost -U postgres
```

### Use with Docker Compose

```yaml
version: '3.8'
services:
  db:
    image: qonicsinc/postgres-pgcron:17.5
    environment:
      POSTGRES_PASSWORD: example
    ports:
      - 5432:5432
```

## Environment Variables

- `POSTGRES_PASSWORD` - **Required** - PostgreSQL superuser password
- `POSTGRES_DB` - Optional - Name of the default database (default: `postgres`)
- `POSTGRES_USER` - Optional - PostgreSQL superuser name (default: `postgres`)

## Key Features

✅ **Production Ready** - Optimized configuration and security settings  
✅ **Automated Jobs** - Schedule SQL commands with pg_cron  
✅ **Table Partitioning** - Automatic partition management with pg_partman  
✅ **Performance Optimized** - Tuned for containerized environments  
✅ **Secure by Default** - SCRAM-SHA-256 authentication enabled  

## Example Use Cases

- **Data Archival**: Automatically partition and clean up old data
- **ETL Pipelines**: Schedule data transformation jobs
- **Analytics**: Partition large fact tables for better query performance
- **Log Management**: Automated log rotation and cleanup
- **Financial Data**: Time-based partitioning for trading and transaction data

## Extensions Included

| Extension | Version | Purpose |
|-----------|---------|---------|
| pg_cron | 1.6 | PostgreSQL job scheduler |
| pg_partman | 5.2.4 | Automated table partitioning |

## License

This image is based on the official PostgreSQL Docker image and includes additional open-source extensions under their respective licenses.
