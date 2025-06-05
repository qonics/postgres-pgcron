.PHONY: build test run stop clean help push

DOCKER_HUB_USERNAME = qonicsinc
IMAGE_NAME = postgres-pgcron
OG_IMAGE_NAME = postgres
IMAGE_TAG = 17.5
CONTAINER_NAME = postgres-pgcron-dev
FULL_IMAGE_NAME = $(DOCKER_HUB_USERNAME)/$(IMAGE_NAME)

help: ## Show this help message
	@echo "Available commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-15s %s\n", $$1, $$2}'

build: ## Build the Docker image
	@echo "Building $(FULL_IMAGE_NAME):$(IMAGE_TAG)..."
	docker build \
		--cache-from $(OG_IMAGE_NAME):$(IMAGE_TAG) \
		--build-arg BUILDKIT_INLINE_CACHE=1 \
		-t $(FULL_IMAGE_NAME):$(IMAGE_TAG) \
		-t $(FULL_IMAGE_NAME):latest \
		.

test: build ## Build and test the image
	@echo "Running tests..."
	./test.sh

run: ## Run the container in development mode
	@echo "Starting $(CONTAINER_NAME)..."
	docker run -d \
		--name $(CONTAINER_NAME) \
		-e POSTGRES_PASSWORD=dev123 \
		-p 5432:5432 \
		$(FULL_IMAGE_NAME):$(IMAGE_TAG)

stop: ## Stop and remove the development container
	@echo "Stopping $(CONTAINER_NAME)..."
	docker stop $(CONTAINER_NAME) 2>/dev/null || true
	docker rm $(CONTAINER_NAME) 2>/dev/null || true

clean: stop ## Clean up containers and images
	@echo "Cleaning up..."
	docker image rm $(FULL_IMAGE_NAME):$(IMAGE_TAG) 2>/dev/null || true
	docker image rm $(FULL_IMAGE_NAME):latest 2>/dev/null || true
	docker system prune -f

push: test ## Push the image to Docker Hub
	@echo "Pushing $(FULL_IMAGE_NAME):$(IMAGE_TAG) to Docker Hub..."
	docker push $(FULL_IMAGE_NAME):$(IMAGE_TAG)
	docker push $(FULL_IMAGE_NAME):latest

logs: ## Show container logs
	docker logs -f $(CONTAINER_NAME)

shell: ## Open shell in the running container
	docker exec -it $(CONTAINER_NAME) bash

psql: ## Connect to PostgreSQL in the running container
	docker exec -it $(CONTAINER_NAME) psql -U postgres