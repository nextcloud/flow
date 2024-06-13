.DEFAULT_GOAL := help

.PHONY: help
help:
	@echo "Welcome to WorkflowEngine project. Please use \`make <target>\` where <target> is one of"
	@echo " "
	@echo "  Next commands are only for dev environment with nextcloud-docker-dev!"
	@echo "  They should run from the host you are developing on(with activated venv) and not in the container with Nextcloud!"
	@echo "  "
	@echo "  build-push        build image and upload to ghcr.io"
	@echo "  "
	@echo "  run               install WorkflowEngine for Nextcloud Last"

.PHONY: build-push
build-push:
	docker login ghcr.io
	docker buildx build --push --platform linux/arm64/v8,linux/amd64 --tag ghcr.io/cloud-py-api/windmill_app_dev:latest .

.PHONY: build-dev
build-dev:
	docker login ghcr.io
	docker buildx build --push --platform linux/arm64/v8,linux/amd64 --tag ghcr.io/cloud-py-api/windmill_app_dev:latest .
	#docker build -t windmill_app_dev:latest .

.PHONY: run-dev
run-dev:
	docker exec master-nextcloud-1 sudo -u www-data php occ app_api:app:unregister windmill_app --silent --force || true
	docker exec master-nextcloud-1 sudo -u www-data php occ app_api:app:register windmill_app --force-scopes \
		--info-xml https://raw.githubusercontent.com/cloud-py-api/windmill_app/main/appinfo/info.xml

.PHONY: register
register:
	docker exec master-nextcloud-1 sudo -u www-data php occ app_api:app:unregister windmill_app --silent --force || true
	docker exec master-nextcloud-1 sudo -u www-data php occ app_api:app:register windmill_app manual_install --json-info \
  "{\"id\":\"windmill_app\",\"name\":\"Workflow Engine\",\"daemon_config_name\":\"manual_install\",\"version\":\"1.0.0\",\"secret\":\"12345\",\"port\":23000,\"scopes\":[\"ALL\"],\"system_app\":1}" \
  --force-scopes --wait-finish
