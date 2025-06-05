.PHONY: build build-alpine test test-alpine run run-alpine stop clean help push push-alpine all

DOCKER_HUB_USERNAME = qonicsinc
IMAGE_NAME = postgres-pgcron
OG_IMAGE_NAME = postgres
IMAGE_TAG = 17.5
ALPINE_TAG = $(IMAGE_TAG)-alpine
CONTAINER_NAME = postgres-pgcron-dev
ALPINE_CONTAINER_NAME = postgres-pgcron-alpine-dev
FULL_IMAGE_NAME = $(DOCKER_HUB_USERNAME)/$(IMAGE_NAME)

help: ## Show this help message
	@echo "🐘 PostgreSQL with pg_cron and pg_partman Build System"
	@echo "======================================================"
	@echo "Available commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'
	@echo ""
	@echo "🏷️  Image tags:"
	@echo "  Standard: $(FULL_IMAGE_NAME):$(IMAGE_TAG), $(FULL_IMAGE_NAME):latest"
	@echo "  Alpine:   $(FULL_IMAGE_NAME):$(ALPINE_TAG), $(FULL_IMAGE_NAME):alpine"

# Standard Debian-based build
build: ## Build the standard Docker image (Debian-based)
	@echo "🔨 Building $(FULL_IMAGE_NAME):$(IMAGE_TAG) (Debian)..."
	docker build \
		--cache-from $(OG_IMAGE_NAME):$(IMAGE_TAG) \
		--build-arg BUILDKIT_INLINE_CACHE=1 \
		-t $(FULL_IMAGE_NAME):$(IMAGE_TAG) \
		-t $(FULL_IMAGE_NAME):latest \
		.
	@echo "✅ Standard build completed!"

# Alpine-based build
build-alpine: ## Build the Alpine Docker image (smaller size)
	@echo "🏔️  Building $(FULL_IMAGE_NAME):$(ALPINE_TAG) (Alpine)..."
	docker build \
		--cache-from $(OG_IMAGE_NAME):$(IMAGE_TAG)-alpine \
		--build-arg BUILDKIT_INLINE_CACHE=1 \
		-f Dockerfile.alpine \
		-t $(FULL_IMAGE_NAME):$(ALPINE_TAG) \
		-t $(FULL_IMAGE_NAME):alpine \
		.
	@echo "✅ Alpine build completed!"

# Build both versions
all: build build-alpine ## Build both standard and Alpine images
	@echo "🎉 All builds completed!"
	@echo "📏 Image size comparison:"
	@docker images $(FULL_IMAGE_NAME) --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}" | head -6

test: build ## Build and test the standard image
	@echo "🧪 Running tests for standard image..."
	./test.sh

test-alpine: build-alpine ## Build and test the Alpine image
	@echo "🧪 Running tests for Alpine image..."
	IMAGE_NAME="$(FULL_IMAGE_NAME):$(ALPINE_TAG)" ./test.sh

run: ## Run the standard container in development mode
	@echo "🚀 Starting $(CONTAINER_NAME) (standard)..."
	docker run -d \
		--name $(CONTAINER_NAME) \
		-e POSTGRES_PASSWORD=dev123 \
		-e POSTGRES_DB=dev_db \
		-p 5432:5432 \
		$(FULL_IMAGE_NAME):$(IMAGE_TAG)
	@echo "✅ Container started at localhost:5432"

run-alpine: ## Run the Alpine container in development mode
	@echo "🚀 Starting $(ALPINE_CONTAINER_NAME) (Alpine)..."
	docker run -d \
		--name $(ALPINE_CONTAINER_NAME) \
		-e POSTGRES_PASSWORD=dev123 \
		-e POSTGRES_DB=dev_db \
		-p 5433:5432 \
		$(FULL_IMAGE_NAME):$(ALPINE_TAG)
	@echo "✅ Alpine container started at localhost:5433"

stop: ## Stop and remove development containers
	@echo "🛑 Stopping development containers..."
	docker stop $(CONTAINER_NAME) 2>/dev/null || true
	docker rm $(CONTAINER_NAME) 2>/dev/null || true
	docker stop $(ALPINE_CONTAINER_NAME) 2>/dev/null || true
	docker rm $(ALPINE_CONTAINER_NAME) 2>/dev/null || true

clean: stop ## Clean up containers and images
	@echo "🧹 Cleaning up..."
	docker image rm $(FULL_IMAGE_NAME):$(IMAGE_TAG) 2>/dev/null || true
	docker image rm $(FULL_IMAGE_NAME):latest 2>/dev/null || true
	docker image rm $(FULL_IMAGE_NAME):$(ALPINE_TAG) 2>/dev/null || true
	docker image rm $(FULL_IMAGE_NAME):alpine 2>/dev/null || true
	docker system prune -f

push: test ## Push the standard image to Docker Hub
	@echo "🚢 Pushing standard images to Docker Hub..."
	docker push $(FULL_IMAGE_NAME):$(IMAGE_TAG)
	docker push $(FULL_IMAGE_NAME):latest

push-alpine: test-alpine ## Push the Alpine image to Docker Hub
	@echo "🚢 Pushing Alpine images to Docker Hub..."
	docker push $(FULL_IMAGE_NAME):$(ALPINE_TAG)
	docker push $(FULL_IMAGE_NAME):alpine

push-all: push push-alpine ## Push both standard and Alpine images
	@echo "🎉 All images pushed to Docker Hub successfully!"

logs: ## Show standard container logs
	docker logs -f $(CONTAINER_NAME)

shell: ## Open shell in the running container
	docker exec -it $(CONTAINER_NAME) bash

psql: ## Connect to PostgreSQL in the running container
	docker exec -it $(CONTAINER_NAME) psql -U postgres