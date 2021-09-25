REGION := ap-northeast-1
ACCOUNT_ID = $(shell aws sts get-caller-identity --output text | cut -f1)

.PHONY: login
login:
	aws ecr get-login-password --region ${REGION} | docker login \
		--username AWS \
		--password-stdin ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com

.PHONY: build
build: ## fetch resources to build containers
	make validate
	make login

	DOCKER_BUILDKIT=1 docker build \
		-t ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/strapi:latest
		.

.PHONY: push
push:
	make login
	docker push ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/strapi:latest
