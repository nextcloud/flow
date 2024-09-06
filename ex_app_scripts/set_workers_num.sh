#!/bin/bash

if [ -z "$NUM_WORKERS" ]; then
     NUM_WORKERS=$(nproc)
     NUM_WORKERS=$((NUM_WORKERS * 2))

    # Export the NUM_WORKERS variable so it becomes an environment variable
    echo "export NUM_WORKERS=\"$NUM_WORKERS\"" >> /etc/environment
    echo "NUM_WORKERS was not set. It is now set to: $NUM_WORKERS"
else
    echo "NUM_WORKERS is already set to: $NUM_WORKERS"
fi
