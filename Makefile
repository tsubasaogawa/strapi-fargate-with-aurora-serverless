REGION := $(shell cd terraform && terraform output -raw region)
ACCOUNT_ID := $(shell aws sts get-caller-identity --output text | cut -f1)
CLUSTER_NAME := $(shell cd terraform && terraform output -raw ecs_cluster_name)
TASK_DEFINITION := $(shell cd terraform && terraform output -raw task_definition_family)
PLATFORM_VERSION := 1.4.0
SUBNETS := $(shell cd terraform && terraform output -json subnet_ids | jq -c .public)
SECURITY_GROUP := $(shell cd terraform && terraform output -json security_group_ids | jq -c .task)
NETWORK_CONFIGURATION := {"awsvpcConfiguration": {"subnets": ${SUBNETS}, "securityGroups": [${SECURITY_GROUPS}], "assignPublicIp": "ENABLED"}}

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

.PHONY: run_task
run_task:
	aws ecs run-task \
		--cluster ${CLUSTER_NAME} \
		--task-definition ${TASK_DEFINITION} \
		--count 1 \
		--capacity-provider-strategy capacityProvider=FARGATE_SPOT,weight=1 \
		--platform-version ${PLATFORM_VERSION} \
		--network-configuration '${NETWORK_CONFIGURATION}' \
		--started-by "make run_task" \
		--region ${REGION}
