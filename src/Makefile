all: build

build: Makefile Dockerfile
	docker build --progress=plain -t estakhri/nginx-certbot-http3-brotli:latest .

run:
	docker run -it --rm \
	-e CERTBOT_EMAIL=user@example.com \
	-e DEBUG=1 \
	estakhri/nginx-certbot-http3-brotli:latest

build-alpine: Makefile Dockerfile
	docker build --progress=plain -t estakhri/nginx-certbot-http3-brotli:local-alpine -f ./Dockerfile-alpine .

run-alpine:
	docker run -it --rm \
	-e CERTBOT_EMAIL=user@example.com \
	-e DEBUG=1 \
	estakhri/nginx-certbot-http3-brotli:local-alpine

# These commands are primarily used for development, see link for more info:
# https://github.com/JonasAlfredsson/docker-nginx-certbot/issues/28
dev:
	docker buildx build --platform linux/amd64,linux/386,linux/arm64,linux/arm/v7 --tag estakhri/nginx-certbot-http3-brotli:dev -f ./Dockerfile ./

dev-alpine:
	docker buildx build --platform linux/amd64,linux/arm64 --tag estakhri/nginx-certbot-http3-brotli:dev-alpine -f ./Dockerfile-alpine ./

push:
	docker buildx build --platform linux/amd64,linux/arm64 --tag estakhri/nginx-certbot-http3-brotli:dev --pull --no-cache --push .
