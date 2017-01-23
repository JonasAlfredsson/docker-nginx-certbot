all: build

build: Makefile Dockerfile
	docker build --squash -t staticfloat/docker-certbot-cron .
	echo "Done!  Use docker run staticfloat/docker-certbot-cron to run"

push:
	docker push staticfloat/docker-certbot-cron
