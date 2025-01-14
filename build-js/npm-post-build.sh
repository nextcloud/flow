#!/bin/sh

# SPDX-FileCopyrightText: 2024 Nextcloud GmbH and Nextcloud contributors
# SPDX-License-Identifier: AGPL-3.0-or-later

set -e

# Directories to process (space-separated)
directories="js ex_app/js"

found_any_directory=false

for dir in $directories; do
	if [ -d "$dir" ]; then
		found_any_directory=true
		# Process all .js files in this directory
		for f in "$dir"/*.js; do
			# If license file and source map exists copy license for the source map
			if [ -f "$f.license" ] && [ -f "$f.map" ]; then
				# Remove existing link
				[ -e "$f.map.license" ] || [ -L "$f.map.license" ] && rm "$f.map.license"
				# Create a new link
				ln -s "$(basename "$f.license")" "$f.map.license"
			fi
		done
	fi
done

if [ "$found_any_directory" = false ]; then
	echo "This script needs to be executed from the root of the repository"
	exit 1
fi

echo "Copying licenses for sourcemaps done"
