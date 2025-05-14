#!/bin/bash
# SPDX-FileCopyrightText: 2024 Nextcloud GmbH and Nextcloud contributors
# SPDX-License-Identifier: MIT

# Environment variables
DB_NAME=${APP_ID:-windmill}
DB_USER=${APP_ID:-windmilluser}
DB_PASS=${APP_ID:-windmillpass}

# Check if EXTERNAL_DATABASE is set
if [ -n "${EXTERNAL_DATABASE}" ]; then
    DATABASE_URL="${EXTERNAL_DATABASE}"
    echo "Using external database. DATABASE_URL is set to: $DATABASE_URL"

    # Check if DATABASE_URL is already in /etc/environment, if not, add it
    if ! grep -q "^export DATABASE_URL=" /etc/environment; then
        echo "export DATABASE_URL=\"$EXTERNAL_DATABASE\"" >> /etc/environment
    fi

    # Reload environment variables
    . /etc/environment
    exit 0
fi

source /ex_app_scripts/common_pgsql.sh

ensure_postgres_installed
init_and_start_postgres

# Check if the user exists and create if not
sudo -u postgres $PG_SQL -c "SELECT 1 FROM pg_user WHERE usename = '$DB_USER'" | grep -q 1 || \
sudo -u postgres $PG_SQL -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';" && \
sudo -u postgres $PG_SQL -c "ALTER USER $DB_USER WITH SUPERUSER;"

# Check if the database exists and create if not
sudo -u postgres $PG_SQL -c "SELECT 1 FROM pg_database WHERE datname = '$DB_NAME'" | grep -q 1 || \
sudo -u postgres $PG_SQL -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;"

if [ -z "${DATABASE_URL}" ]; then
    # Set DATABASE_URL environment variable
    DATABASE_URL="postgresql://$DB_USER:$DB_PASS@%2Fvar%2Frun%2Fpostgresql/$DB_NAME?sslmode=disable"

    # Check if DATABASE_URL is already in /etc/environment, if not, add it
    if ! grep -q "^export DATABASE_URL=" /etc/environment; then
        echo "export DATABASE_URL=\"postgresql://$DB_USER:$DB_PASS@%2Fvar%2Frun%2Fpostgresql/$DB_NAME?sslmode=disable\"" >> /etc/environment
    fi

    echo "DATABASE_URL was not set. It is now set to: $DATABASE_URL"
else
    echo "DATABASE_URL is already set to: $DATABASE_URL"
fi
