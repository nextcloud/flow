.DEFAULT_GOAL := help

.PHONY: help
help:
	@echo "Welcome to WorkflowEngine project. Please use \`make <target>\` where <target> is one of"
	@echo " "
	@echo "  Next commands are only for dev environment with nextcloud-docker-dev!"
	@echo "  They should run from the host you are developing on(with activated venv) and not in the container with Nextcloud!"
	@echo "  "
	@echo "  init        	   clone Windmill repository to the 'windmill_src' folder and copy ExApp files inside it"
	@echo "  build-push        build image and upload to ghcr.io"
	@echo "  "
	@echo "  run30             install Flow for Nextcloud 30"
	@echo "  run               install Flow for Nextcloud Last"

.PHONY: init
init:
	git -c advice.detachedHead=False clone -b v1.394.4 https://github.com/windmill-labs/windmill.git windmill_src
	cp Dockerfile requirements.txt windmill_src/

	cp -r ex_app windmill_src/
	cp -r ex_app_scripts windmill_src/

.PHONY: build-push
build-push:
	docker login ghcr.io
	VERSION=$$(xmlstarlet sel -t -v "//image-tag" appinfo/info.xml) && \
	pushd windmill_src && \
	docker buildx build --push --build-arg VITE_BASE_URL=/index.php/apps/app_api/proxy/flow --platform linux/arm64/v8,linux/amd64 --tag ghcr.io/cloud-py-api/flow:$$VERSION . && \
	popd

.PHONY: run30
run30:
	docker exec master-stable30-1 sudo -u www-data php occ app_api:app:unregister flow --silent --force || true
	docker exec master-stable30-1 sudo -u www-data php occ app_api:app:register flow \
		--info-xml https://raw.githubusercontent.com/cloud-py-api/flow/main/appinfo/info.xml

.PHONY: run
run:
	docker exec master-nextcloud-1 sudo -u www-data php occ app_api:app:unregister flow --silent --force || true
	docker exec master-nextcloud-1 sudo -u www-data php occ app_api:app:register flow \
		--info-xml https://raw.githubusercontent.com/cloud-py-api/flow/main/appinfo/info.xml

.PHONY: register30
register30:
	docker exec master-stable30-1 sudo -u www-data php occ app_api:app:unregister flow --silent --force || true
	docker exec master-stable30-1 sudo -u www-data php occ app_api:app:register flow manual_install --json-info \
  "{\"id\":\"flow\",\"name\":\"Flow\",\"daemon_config_name\":\"manual_install\",\"version\":\"1.0.0\",\"secret\":\"12345\",\"port\":23000}" \
  --wait-finish

.PHONY: register
register:
	docker exec master-nextcloud-1 sudo -u www-data php occ app_api:app:unregister flow --silent --force || true
	docker exec master-nextcloud-1 sudo -u www-data php occ app_api:app:register flow manual_install --json-info \
  "{\"id\":\"flow\",\"name\":\"Flow\",\"daemon_config_name\":\"manual_install\",\"version\":\"1.0.0\",\"secret\":\"12345\",\"port\":23000}" \
  --wait-finish
