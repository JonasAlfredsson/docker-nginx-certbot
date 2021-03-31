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

# These commands are primarily used for development, see link for more info:
# https://github.com/JonasAlfredsson/docker-nginx-certbot/issues/28
dev:
	docker buildx build --build-arg BUILDX_QEMU_ENV=true --platform linux/amd64,linux/386,linux/arm64,linux/arm/v7,linux/mips64le,linux/s390x,linux/ppc64le --tag jonasal/nginx-certbot:dev .

push:
	docker buildx build --build-arg BUILDX_QEMU_ENV=true --platform linux/amd64,linux/386,linux/arm64,linux/arm/v7 --tag jonasal/nginx-certbot:dev --pull --no-cache --push .
