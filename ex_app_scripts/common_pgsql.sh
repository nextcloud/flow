#!/bin/bash
# SPDX-FileCopyrightText: 2024 Nextcloud GmbH and Nextcloud contributors
# SPDX-License-Identifier: MIT

# Common environment variables
PG_VERSION=15
PG_BIN="/usr/lib/postgresql/${PG_VERSION}/bin"
PG_SQL="/usr/lib/postgresql/${PG_VERSION}/bin/psql"
BASE_DIR="${APP_PERSISTENT_STORAGE:-/nc_app_${APP_ID:-flow}_data}"
DATA_DIR="${BASE_DIR}/pgsql"

# Function to ensure PostgreSQL is installed
ensure_postgres_installed() {
    # Check if PostgreSQL is installed by checking for the existence of binary files
    if [ -d "$PG_BIN" ]; then
        echo "PostgreSQL binaries found."
    else
        echo "PostgreSQL binaries not found."
        echo "Adding the PostgreSQL APT repository..."
        apt-get update && apt-get install -y gnupg
        wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
        echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list
        echo "Installing PostgreSQL..."
        apt-get update && apt-get install -y postgresql-$PG_VERSION
    fi
}

# Function to initialize the database (if needed) and start PostgreSQL
init_and_start_postgres() {
    # Ensure the directory exists and has the correct permissions
    mkdir -p "$DATA_DIR"
    chown -R postgres:postgres "$DATA_DIR"

    if [ ! -d "$DATA_DIR/base" ]; then
        echo "Initializing the PostgreSQL database..."
        sudo -u postgres ${PG_BIN}/initdb -D "$DATA_DIR"
        PG_CONF="${DATA_DIR}/postgresql.conf"
        if ! grep -q "^listen_addresses\s*=\s*''" "$PG_CONF"; then
            echo "Updating PostgreSQL configuration to disable TCP/IP connections..."
            echo "listen_addresses = ''" >> "$PG_CONF"
        fi
    fi

    echo "Starting PostgreSQL..."
    sudo -u postgres ${PG_BIN}/pg_ctl -D "$DATA_DIR" -l "${DATA_DIR}/logfile" start

    echo "Waiting for PostgreSQL to start..."
    until sudo -u postgres ${PG_SQL} -c "SELECT 1" > /dev/null 2>&1; do
        sleep 1
        echo -n "."
    done
    echo "PostgreSQL is up and running."
}
