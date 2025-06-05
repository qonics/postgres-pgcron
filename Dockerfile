# PostgreSQL 17.5 with pg_cron and pg_partman
FROM postgres:17.5 AS builder

# Build arguments for versions
ARG PG_CRON_VERSION=v1.6.4
ARG PG_PARTMAN_VERSION=v5.2.4

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    postgresql-server-dev-17 \
    libssl-dev \
    libkrb5-dev \
    && rm -rf /var/lib/apt/lists/*

# Build pg_cron
WORKDIR /tmp
RUN git clone https://github.com/citusdata/pg_cron.git && \
    cd pg_cron && \
    git checkout ${PG_CRON_VERSION} && \
    make && \
    make install

# Build pg_partman
RUN git clone https://github.com/pgpartman/pg_partman.git && \
    cd pg_partman && \
    git checkout ${PG_PARTMAN_VERSION} && \
    make && \
    make install

# Final image
FROM postgres:17.5

# Re-declare build arguments for use in this stage
ARG PG_CRON_VERSION=v1.6.4
ARG PG_PARTMAN_VERSION=v5.2.4

# Metadata
LABEL maintainer="Qonics inc <support@qonics.com>" \
    description="PostgreSQL 17.5 with pg_cron ${PG_CRON_VERSION} and pg_partman ${PG_PARTMAN_VERSION} extensions" \
      version="17.5-pgcron-partman"

# Environment variables with defaults
ENV POSTGRES_DB=leazi \
    POSTGRES_USER=postgres
# POSTGRES_PASSWORD should be provided at runtime via docker run -e or docker-compose

# Copy extensions from builder
COPY --from=builder /usr/share/postgresql/17/extension/* /usr/share/postgresql/17/extension/
COPY --from=builder /usr/lib/postgresql/17/lib/* /usr/lib/postgresql/17/lib/

# Install runtime dependencies only
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create configuration directory
RUN mkdir -p /etc/postgresql/conf.d /usr/local/bin/postgres-scripts

# Copy all configuration and scripts
COPY postgresql.conf pg_hba.conf /etc/postgresql/
COPY init-scripts/ /docker-entrypoint-initdb.d/
COPY scripts/ /usr/local/bin/postgres-scripts/
COPY docker-entrypoint.sh /usr/local/bin/

# Set permissions in one layer
RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/postgres-scripts/*.sh && \
    chown -R postgres:postgres /etc/postgresql/ /usr/local/bin/postgres-scripts/

# Expose PostgreSQL port
EXPOSE 5432

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB} || exit 1

# Set custom entrypoint and command
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["postgres"]
