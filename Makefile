# SPDX-FileCopyrightText: 2024 Nextcloud GmbH and Nextcloud contributors
# SPDX-License-Identifier: MIT
.DEFAULT_GOAL := help

APP_ID := flow
APP_NAME := Flow
APP_VERSION := $$(xmlstarlet sel -t -v "//version" appinfo/info.xml)
JSON_INFO := "{\"id\":\"$(APP_ID)\",\"name\":\"$(APP_NAME)\",\"daemon_config_name\":\"manual_install\",\"version\":\"$(APP_VERSION)\",\"secret\":\"12345\",\"port\":24000, \"routes\": [{\"url\":\"^api\\\/w\\\/nextcloud\\\/jobs\\\/.*\", \"verb\":\"GET, POST, PUT, DELETE\", \"access_level\":0, \"headers_to_exclude\":[], \"bruteforce_protection\":[401]}, {\"url\":\"^api\\\/w\\\/nextcloud\\\/jobs_u\\\/.*\", \"verb\":\"GET, POST, PUT, DELETE\", \"access_level\":0, \"headers_to_exclude\":[], \"bruteforce_protection\":[401]}, {\"url\":\".*\", \"verb\":\"GET, POST, PUT, DELETE\", \"access_level\":2, \"headers_to_exclude\":[]}]}"


.PHONY: help
help:
	@echo "  Welcome to $(APP_NAME) $(APP_VERSION)!"
	@echo " "
	@echo "  Please use \`make <target>\` where <target> is one of"
	@echo " "
	@echo "  init              clones Windmill repo to 'windmill_src' folder and copy ExApp inside it"
	@echo "  static_frontend   builds Windmill's 'static_frontend' folder for 'manual_install'"
	@echo "  build-push        builds app docker image and uploads it to ghcr.io"
	@echo " "
	@echo "  > Next commands are only for the dev environment with nextcloud-docker-dev!"
	@echo "  > They should run from the host you are developing on(with activated venv) and not in the container with Nextcloud!"
	@echo " "
	@echo "  run30             installs $(APP_NAME) for Nextcloud 30"
	@echo "  run               installs $(APP_NAME) for Nextcloud Latest"
	@echo " "
	@echo "  > Commands for manual registration of ExApp($(APP_NAME) should be running!):"
	@echo " "
	@echo "  register30        performs registration of running $(APP_NAME) into the 'manual_install' deploy daemon."
	@echo "  register          performs registration of running $(APP_NAME) into the 'manual_install' deploy daemon."


.PHONY: init
init:
	rm -rf windmill_src
	git -c advice.detachedHead=False clone -b v1.394.4 https://github.com/windmill-labs/windmill.git windmill_src
	cp Dockerfile requirements.txt windmill_src/

	cp -r ex_app windmill_src/
	cp -r ex_app_scripts windmill_src/

.PHONY: static_frontend
static_frontend:
	rm -rf static_frontend
	pushd windmill_src && \
	DOCKER_BUILDKIT=1 docker buildx build \
		--build-arg VITE_BASE_URL=/index.php/apps/app_api/proxy/flow \
		--platform linux/amd64 \
		--target export_frontend \
		--output type=local,dest=../static_frontend . && \
	popd

.PHONY: build-push
build-push:
	docker login ghcr.io
	docker buildx build --push \
		--build-arg VITE_BASE_URL=/index.php/apps/app_api/proxy/flow \
		--platform linux/arm64/v8,linux/amd64 \
		--tag ghcr.io/nextcloud/$(APP_ID):$(APP_VERSION) \
		--file windmill_src/Dockerfile \
		windmill_src

.PHONY: run30
run30:
	docker exec master-stable30-1 sudo -u www-data php occ app_api:app:unregister $(APP_ID) --silent --force || true
	docker exec master-stable30-1 sudo -u www-data php occ app_api:app:register $(APP_ID) \
		--info-xml https://raw.githubusercontent.com/nextcloud/$(APP_ID)/main/appinfo/info.xml

.PHONY: run
run:
	docker exec master-nextcloud-1 sudo -u www-data php occ app_api:app:unregister $(APP_ID) --silent --force || true
	docker exec master-nextcloud-1 sudo -u www-data php occ app_api:app:register $(APP_ID) \
		--info-xml https://raw.githubusercontent.com/nextcloud/$(APP_ID)/main/appinfo/info.xml

.PHONY: register30
register30:
	docker exec master-stable30-1 sudo -u www-data php occ app_api:app:unregister $(APP_ID) --silent --force || true
	docker exec master-stable30-1 sudo -u www-data php occ app_api:app:register $(APP_ID) manual_install --json-info $(JSON_INFO) --wait-finish

.PHONY: register
register:
	docker exec master-nextcloud-1 sudo -u www-data php occ app_api:app:unregister $(APP_ID) --silent --force || true
	docker exec master-nextcloud-1 sudo -u www-data php occ app_api:app:register $(APP_ID) manual_install --json-info $(JSON_INFO) --wait-finish
