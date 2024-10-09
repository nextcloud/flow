#!/bin/sh

# Read environment variables
. /etc/environment

# Execute the custom scripts
/ex_app_scripts/init_pgsql.sh
/ex_app_scripts/set_workers_num.sh

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
