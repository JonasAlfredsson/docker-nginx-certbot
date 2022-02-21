# If we have `--squash` support, then use it!
ifneq ($(shell docker build --help 2>/dev/null | grep squash),)
DOCKER_BUILD = docker build --squash
else
DOCKER_BUILD = docker build
endif

all: build

build: Makefile Dockerfile
	$(DOCKER_BUILD) -t jonasal/nginx-certbot:local .
	@echo "Done!  Use docker run jonasal/nginx-certbot:local to run"

build-alpine: Makefile Dockerfile
	$(DOCKER_BUILD) -t jonasal/nginx-certbot:local-alpine -f ./Dockerfile-alpine .
	@echo "Done!  Use docker run jonasal/nginx-certbot:local-alpine to run"

# These commands are primarily used for development, see link for more info:
# https://github.com/JonasAlfredsson/docker-nginx-certbot/issues/28
dev:
	docker buildx build --build-arg --platform linux/amd64,linux/arm64 --tag jonasal/nginx-certbot:dev -f ./Dockerfile ./

dev-alpine:
	docker buildx build --platform linux/amd64,linux/arm64 --tag jonasal/nginx-certbot:dev-alpine -f ./Dockerfile-alpine ./

push:
	docker buildx build --build-arg --platform linux/amd64,linux/arm64 --tag jonasal/nginx-certbot:dev --pull --no-cache --push .
