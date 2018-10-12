# If we have `--squash` support, then use it!
ifneq ($(shell docker build --help 2>/dev/null | grep squash),)
DOCKER_BUILD = docker build --squash
else
DOCKER_BUILD = docker build
endif

all: build

build: Makefile Dockerfile
	$(DOCKER_BUILD) -t jonasal/nginx-certbot .
	@echo "Done!  Use docker run jonasal/nginx-certbot to run"

release:
	$(DOCKER_BUILD) -t jonasal/nginx-certbot --pull --no-cache .

push:
	docker push jonasal/nginx-certbot
