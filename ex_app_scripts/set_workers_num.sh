#!/bin/bash

if [ -z "$NUM_WORKERS" ]; then
     NUM_WORKERS=$(nproc)
     NUM_WORKERS=$((NUM_WORKERS * 2))

    # Check if NUM_WORKERS is already in /etc/environment, if not, add it
    if ! grep -q "^export NUM_WORKERS=" /etc/environment; then
        echo "export NUM_WORKERS=\"$NUM_WORKERS\"" >> /etc/environment
    fi

    echo "NUM_WORKERS was not set. It is now set to: $NUM_WORKERS"

    # Reload environment variables
    . /etc/environment
else
    echo "NUM_WORKERS is already set to: $NUM_WORKERS"
fi
