all: build

build: Makefile Dockerfile
	docker build --squash -t staticfloat/nginx-certbot .
	@echo "Done!  Use docker run staticfloat/nginx-certbot to run"

push:
	docker push staticfloat/nginx-certbot
