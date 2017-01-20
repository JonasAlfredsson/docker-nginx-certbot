all: build

build: Makefile Dockerfile
	docker build --squash -t staticfloat/docker-certbot-cron .

push:
	docker push staticfloat/docker-certbot-cron
