#!/bin/bash

# Environment variables
DB_NAME=${APP_ID:-windmill}
DB_USER=${APP_ID:-windmilluser}
DB_PASS=${APP_ID:-windmillpass}
BASE_DIR="${APP_PERSISTENT_STORAGE:-/nc_app_flow_data}"

# PostgreSQL version to use
PG_VERSION=15
PG_BIN="/usr/lib/postgresql/${PG_VERSION}/bin"
PG_SQL="/usr/lib/postgresql/${PG_VERSION}/bin/psql"

# Define the PostgreSQL data directory
DATA_DIR="${BASE_DIR}/pgsql"

# Check if DATABASE_URI is set for external database usage
if [ -n "${DATABASE_URI}" ]; then
    # Use external database by setting DATABASE_URL to DATABASE_URI
    DATABASE_URL="${DATABASE_URI}"
    echo "Using external database. DATABASE_URL is set to: $DATABASE_URL"

    # Check if DATABASE_URL is already in /etc/environment, if not, add it
    if ! grep -q "^export DATABASE_URL=" /etc/environment; then
        echo "export DATABASE_URL=\"$DATABASE_URI\"" >> /etc/environment
    fi

    # Reload environment variables
    . /etc/environment

else
    # Check if PostgreSQL is installed by checking for the existence of binary files
    if [ -d "$PG_BIN" ]; then
        echo "PostgreSQL binaries found."
    else
        echo "PostgreSQL binaries not found."
        echo "Adding the PostgreSQL APT repository..."
        wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
        echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list
        echo "Installing PostgreSQL..."
        apt-get update && apt-get install -y postgresql-$PG_VERSION
    fi

    # Ensure the directory exists and has the correct permissions
    mkdir -p "$DATA_DIR"
    chown -R postgres:postgres "$DATA_DIR"

    if [ ! -d "$DATA_DIR/base" ]; then
        echo "Initializing the PostgreSQL database..."
        sudo -u postgres ${PG_BIN}/initdb -D "$DATA_DIR"
    fi

    echo "Starting PostgreSQL..."
    sudo -u postgres ${PG_BIN}/pg_ctl -D "$DATA_DIR" -l "${DATA_DIR}/logfile" start

    echo "Waiting for PostgreSQL to start..."
    until sudo -u postgres ${PG_SQL} -c "SELECT 1" > /dev/null 2>&1; do
        sleep 1
        echo -n "."
    done
    echo "PostgreSQL is up and running."

    # Check if the user exists and create if not
    sudo -u postgres $PG_SQL -c "SELECT 1 FROM pg_user WHERE usename = '$DB_USER'" | grep -q 1 || \
    sudo -u postgres $PG_SQL -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';" && \
    sudo -u postgres $PG_SQL -c "ALTER USER $DB_USER WITH SUPERUSER;"

    # Check if the database exists and create if not
    sudo -u postgres $PG_SQL -c "SELECT 1 FROM pg_database WHERE datname = '$DB_NAME'" | grep -q 1 || \
    sudo -u postgres $PG_SQL -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;"

    if [ -z "${DATABASE_URL}" ]; then
        # Set DATABASE_URL environment variable
        DATABASE_URL="postgres://$DB_USER:$DB_PASS@localhost:5432/$DB_NAME"

        # Check if DATABASE_URL is already in /etc/environment, if not, add it
        if ! grep -q "^export DATABASE_URL=" /etc/environment; then
            echo "export DATABASE_URL=\"postgres://$DB_USER:$DB_PASS@localhost:5432/$DB_NAME\"" >> /etc/environment
        fi

        echo "DATABASE_URL was not set. It is now set to: $DATABASE_URL"
    else
        echo "DATABASE_URL is already set to: $DATABASE_URL"
    fi
fi
