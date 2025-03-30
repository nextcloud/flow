#!/bin/sh
# SPDX-FileCopyrightText: 2024 Nextcloud GmbH and Nextcloud contributors
# SPDX-License-Identifier: MIT

set -e

# Only create a config file if HP_SHARED_KEY is set.
if [ -n "$HP_SHARED_KEY" ]; then
    echo "HP_SHARED_KEY is set, creating /frpc.toml configuration file..."
    if [ -d "/certs/frp" ]; then
        echo "Found /certs/frp directory. Creating configuration with TLS certificates."
        cat <<EOF > /frpc.toml
serverAddr = "$HP_FRP_ADDRESS"
serverPort = $HP_FRP_PORT

transport.tls.enable = true
transport.tls.certFile = "/certs/frp/client.crt"
transport.tls.keyFile = "/certs/frp/client.key"
transport.tls.trustedCaFile = "/certs/frp/ca.crt"
transport.tls.serverName = "harp.nc"

metadatas.token = "$HP_SHARED_KEY"

[[proxies]]
remotePort = $APP_PORT
type = "tcp"
name = "$APP_ID"
[proxies.plugin]
type = "unix_domain_socket"
unixPath = "/tmp/exapp.sock"
EOF
    else
        echo "Directory /certs/frp not found. Creating configuration without TLS certificates."
        cat <<EOF > /frpc.toml
serverAddr = "$HP_FRP_ADDRESS"
serverPort = $HP_FRP_PORT

transport.tls.enable = false

metadatas.token = "$HP_SHARED_KEY"

[[proxies]]
remotePort = $APP_PORT
type = "tcp"
name = "$APP_ID"
[proxies.plugin]
type = "unix_domain_socket"
unixPath = "/tmp/exapp.sock"
EOF
    fi
else
    echo "HP_SHARED_KEY is not set. Skipping FRP configuration."
fi

# If we have a configuration file and the shared key is present, start the FRP client
if [ -f /frpc.toml ] && [ -n "$HP_SHARED_KEY" ]; then
    echo "Starting frpc in the background..."
    frpc -c /frpc.toml &
fi

# Read environment variables
. /etc/environment

# Ensure hostname is in /etc/hosts
HOSTNAME=$(cat /etc/hostname)
if ! grep -q "$HOSTNAME" /etc/hosts; then
    echo "127.0.0.1   $HOSTNAME" >> /etc/hosts
    echo "Added $HOSTNAME to /etc/hosts"
else
    echo "$HOSTNAME is already in /etc/hosts"
fi

# Execute the custom scripts
/ex_app_scripts/init_pgsql.sh
/ex_app_scripts/set_workers_num.sh

# Reloading environment variables to reflect changes if were
. /etc/environment

# Run all arguments after "first" in the background
main_command=$1
shift  # Remove the first argument, which is "the name of main binary"

for arg in "$@"; do
    echo "Starting $arg in background..."
    if [ "$arg" = "caddy" ]; then
        caddy run --config /etc/caddy/Caddyfile &
    elif [ "${arg##*.}" = "py" ]; then
        python3 "$arg" &
	elif echo "$arg" | grep -q '^sleep'; then
        sleep_duration=$(echo "$arg" | grep -o '[0-9]*')
        echo "Sleeping for $sleep_duration seconds..."
        sleep "$sleep_duration"
    else
        eval "$arg" &
    fi
done

# Check if the main command is a Python script
if [ "${main_command##*.}" = "py" ]; then
    echo "Starting main command as a Python script: $main_command"
    exec python3 "$main_command"
else
    echo "Starting main command: $main_command"
    exec "$main_command"
fi
