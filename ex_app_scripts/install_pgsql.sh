#!/bin/bash
# SPDX-FileCopyrightText: 2024 Nextcloud GmbH and Nextcloud contributors
# SPDX-License-Identifier: MIT

source /ex_app_scripts/common_pgsql.sh

ensure_postgres_installed
init_and_start_postgres
