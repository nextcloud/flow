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
	@echo "  build-push-dev    build image and upload to ghcr.io with 'latest' tag"
	@echo "  "
	@echo "  run               install WorkflowEngine for Nextcloud Last"
	@echo "  run-dev           install WorkflowEngine with 'latest' tag for Nextcloud 30"

.PHONY: init
init:
	git -c advice.detachedHead=False clone -b v1.368.3 https://github.com/windmill-labs/windmill.git windmill_src
	cp Dockerfile requirements.txt windmill_src/
	cp -r ex_app windmill_src/
	cp -r ex_app_scripts windmill_src/

.PHONY: build-push
build-push:
	docker login ghcr.io
	VERSION=$$(xmlstarlet sel -t -v "//image-tag" appinfo/info.xml) && \
	pushd windmill_src && \
	docker buildx build --push --build-arg VITE_BASE_URL=/index.php/apps/app_api/proxy/windmill_app --platform linux/arm64/v8,linux/amd64 --tag ghcr.io/cloud-py-api/windmill_app:$$VERSION . && \
	popd

.PHONY: build-push-dev
build-push-dev:
	docker login ghcr.io
	pushd windmill_src && \
	docker buildx build --push --build-arg VITE_BASE_URL=/index.php/apps/app_api/proxy/windmill_app --platform linux/arm64/v8,linux/amd64 --tag ghcr.io/cloud-py-api/windmill_app:latest . && \
	popd

.PHONY: run
run:
	docker exec master-nextcloud-1 sudo -u www-data php occ app_api:app:unregister windmill_app --silent --force || true
	docker exec master-nextcloud-1 sudo -u www-data php occ app_api:app:register windmill_app --force-scopes \
		--info-xml https://raw.githubusercontent.com/cloud-py-api/windmill_app/main/appinfo/info.xml

.PHONY: run-dev
run-dev:
	docker exec master-nextcloud-1 sudo -u www-data php occ app_api:app:unregister windmill_app --silent --force || true
	docker exec master-nextcloud-1 sudo -u www-data php occ app_api:app:register windmill_app --json-info \
  "{\"id\":\"windmill_app\",\"name\":\"Workflow Engine\",\"version\":\"1.0.0\",\"docker-install\":{\"registry\":\"ghcr.io\", \"image\":\"cloud-py-api/windmill_app\", \"image-tag\":\"latest\"},\"scopes\":[\"ALL\"]}" \
  --force-scopes --wait-finish

.PHONY: register
register:
	docker exec master-nextcloud-1 sudo -u www-data php occ app_api:app:unregister windmill_app --silent --force || true
	docker exec master-nextcloud-1 sudo -u www-data php occ app_api:app:register windmill_app manual_install --json-info \
  "{\"id\":\"windmill_app\",\"name\":\"Workflow Engine\",\"daemon_config_name\":\"manual_install\",\"version\":\"1.0.0\",\"secret\":\"12345\",\"port\":23000,\"scopes\":[\"ALL\"]}" \
  --force-scopes --wait-finish
