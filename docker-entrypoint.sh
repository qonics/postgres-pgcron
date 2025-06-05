#!/bin/bash
set -e

# Custom initialization function
custom_init() {
    echo "=== Custom PostgreSQL Initialization ==="
    # Ensure postgres command is available and executable before calling
    if command -v postgres >/dev/null 2>&1; then
        echo "PostgreSQL Version: $(postgres --version)"
    else
        echo "PostgreSQL command not found during custom_init."
    fi
    echo "Extensions: pg_cron, pg_partman"
    echo "Database: ${POSTGRES_DB:-app_database}"
    echo "========================================"
}

# Function to verify extensions after startup
verify_extensions() {
    local db_name="${POSTGRES_DB:-app_database}"
    echo "Verifying extensions installation..."

    # Wait for PostgreSQL to be ready
    until pg_isready -U "${POSTGRES_USER:-postgres}" -d "${db_name}"; do
        echo "Waiting for PostgreSQL to be ready..."
        sleep 2
    done

    # Check if extensions are available
    psql_output=$(psql -U "${POSTGRES_USER:-postgres}" -d "${db_name}" -c "
        SELECT
            name,
            installed_version,
            CASE WHEN installed_version IS NOT NULL THEN 'INSTALLED' ELSE 'AVAILABLE' END as status
        FROM pg_available_extensions
        WHERE name IN ('pg_cron', 'pg_partman')
        ORDER BY name;
    " 2>&1)

    if [ $? -ne 0 ]; then
        echo "Error checking extensions: $psql_output"
    else
        echo "$psql_output"
    fi
}

# This function sets up PostgreSQL directories and is called only when running as root.
_setup_pg_directories() {
    echo "Setting up PostgreSQL directories as root..."
    mkdir -p "$PGDATA"
    chown -R postgres:postgres "$PGDATA"
    chmod 700 "$PGDATA"

    mkdir -p /var/run/postgresql
    chown -R postgres:postgres /var/run/postgresql
    chmod 775 /var/run/postgresql # Common permission for this directory

    mkdir -p /var/log/postgresql
    chown -R postgres:postgres /var/log/postgresql
    chmod 700 /var/log/postgresql # Only postgres user needs access
    echo "PostgreSQL directory setup complete."
}

# Initialize database if needed (assumes running as postgres user)
init_database() {
    if [ ! -s "$PGDATA/PG_VERSION" ]; then
        echo "Initializing PostgreSQL database as user: $(id -un)..."

        # Create a temporary password file
        local pwfile=$(mktemp)
        echo "$POSTGRES_PASSWORD" > "$pwfile"
        
        initdb_args=(
            --username="$POSTGRES_USER"
            --pwfile="$pwfile"
            --auth-host=scram-sha-256
            --auth-local=trust
        )

        # Correctly process POSTGRES_INITDB_ARGS
        if [ -n "$POSTGRES_INITDB_ARGS" ]; then
            echo "Appending POSTGRES_INITDB_ARGS: $POSTGRES_INITDB_ARGS"
            # Safely read arguments into an array
            read -ra initdb_args_array <<<"$POSTGRES_INITDB_ARGS"
            # Append to existing initdb_args
            initdb_args+=("${initdb_args_array[@]}")
        fi # This 'fi' closes the if block

        echo "Running initdb with arguments..." # Avoid printing password file content directly
        # For debugging, you could print elements one by one, skipping sensitive ones:
        # for arg in "${initdb_args[@]}"; do if [[ "$arg" != "$pwfile" && "$arg" != *"$POSTGRES_PASSWORD"* ]]; then echo "Arg: $arg"; fi; done
        
        initdb "${initdb_args[@]}" # Single call to initdb
        
        # Remove the temporary password file immediately after initdb
        rm -f "$pwfile"

        # Copy the base postgresql.conf and customize it for this instance
        echo "Configuring PostgreSQL..."
        cp /etc/postgresql/postgresql.conf "$PGDATA/postgresql.conf"
        cp /etc/postgresql/pg_hba.conf "$PGDATA/pg_hba.conf"
        
        # Set cron.database_name to match POSTGRES_DB
        echo "# Dynamic pg_cron configuration" >> "$PGDATA/postgresql.conf"
        echo "cron.database_name = '${POSTGRES_DB}'" >> "$PGDATA/postgresql.conf"

        # Set up initial pg_hba.conf entries if not present
        # This should happen AFTER initdb has run and created the initial pg_hba.conf
        if ! grep -q "host.*all.*all.*127\\.0\\.0\\.1/32" "$PGDATA/pg_hba.conf"; then
            echo "host all all 127.0.0.1/32 scram-sha-256" >> "$PGDATA/pg_hba.conf"
        fi
        if ! grep -q "host.*all.*all.*::1/128" "$PGDATA/pg_hba.conf"; then
            echo "host all all ::1/128 scram-sha-256" >> "$PGDATA/pg_hba.conf"
        fi

        # Start temporary server for setup
        echo "Starting temporary PostgreSQL server for initialization..."
        pg_ctl -D "$PGDATA" -o "-c listen_addresses=''" -w start

        # Set the postgres user password properly for scram-sha-256
        echo "Setting postgres user password..."
        psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres <<-EOSQL
            ALTER USER "$POSTGRES_USER" WITH PASSWORD '$POSTGRES_PASSWORD';
EOSQL

        # Create database if specified
        if [ -n "$POSTGRES_DB" ] && [ "$POSTGRES_DB" != 'postgres' ]; then
            echo "Creating database '$POSTGRES_DB'..."
            psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres <<-EOSQL
                CREATE DATABASE "$POSTGRES_DB";
EOSQL
        fi

        # Process init scripts
        echo "Processing initialization scripts..."
        for f in /docker-entrypoint-initdb.d/*; do
            case "$f" in
                *.sh)
                    if [ -x "$f" ]; then
                        echo "Running init script: $f"
                        "$f"
                    fi
                    ;;
                *.sql)
                    echo "Running init SQL script: $f"
                    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "${POSTGRES_DB:-postgres}" -f "$f"
                    ;;
                *.sql.gz)
                    echo "Running init SQL script (gzipped): $f"
                    gunzip -c "$f" | psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "${POSTGRES_DB:-postgres}"
                    ;;
                *)
                    echo "Ignoring file in initdb.d: $f"
                    ;;
            esac
        done

        # Stop temporary server
        echo "Stopping temporary PostgreSQL server..."
        pg_ctl -D "$PGDATA" -m fast -w stop

        # Now update pg_hba.conf to use scram-sha-256 for local connections
        echo "Updating pg_hba.conf for scram-sha-256 authentication..."
        sed -i 's/^local.*all.*all.*trust$/local   all             all                                     scram-sha-256/' "$PGDATA/pg_hba.conf"

        echo "PostgreSQL init process complete; ready for start up."
    else
        echo "PostgreSQL database already initialized."
    fi
}

# Main execution logic
main() {
    custom_init # Call custom_init at the beginning

    # Set default environment variables
    export POSTGRES_USER="${POSTGRES_USER:-postgres}"
    export POSTGRES_DB="${POSTGRES_DB:-app_database}"
    export PGDATA="${PGDATA:-/var/lib/postgresql/data}"

    # $1 is the first argument passed to the script (e.g., "postgres" from CMD)
    if [ "$1" = 'postgres' ]; then
        if [ "$(id -u)" = '0' ]; then
            # Running as root: setup directories and re-execute as postgres user
            _setup_pg_directories
            echo "Switching to postgres user to run PostgreSQL server..."
            exec gosu postgres "$BASH_SOURCE" "$@" # Re-run this script with original args
        fi

        # If we are here, we are running as the postgres user
        echo "Running as user: $(id -un)"

        # Initialize database if PGDATA is empty
        if [ ! -s "$PGDATA/PG_VERSION" ]; then
            init_database # This function assumes it's run as postgres
        else
            echo "Skipping database initialization as PG_VERSION file exists."
        fi

        echo "Starting PostgreSQL server..."
        # The original arguments "$@" (e.g., "postgres" "-c" "config_file=...") are used to start the server.
        exec "$@" # This will execute `postgres -c config_file=/etc/postgresql/postgresql.conf ...`
    else
        # Not starting 'postgres' server, could be another utility or command.
        echo "Executing command: $@"
        if [ "$(id -u)" = '0' ]; then
            # Run the command as postgres user if we are currently root
            exec gosu postgres "$@"
        else
            # Already non-root, or command doesn't need specific user drop
            exec "$@"
        fi
    fi
}

# Run main function with all arguments passed to the script
main "$@"