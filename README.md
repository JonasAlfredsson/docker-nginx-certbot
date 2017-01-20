# docker-certbot-cron
Create and automatically renew website SSL certificates using the letsencrypt free certificate authority, and its client *certbot*.  Define the environment variables `DOMAINS` (space-separated list of fully-qualified domain names) and `EMAIL` (your letsencrypt registration email) to automatically run `certbot` to renew/fetch your SSL certificates in the background.  Configure `nginx` to pass off the ACME validation challenge, and you'll have zero-downtime, 100% automatic SSL certificates for all your Docker containers!

# ACME Validation challenge

To authenticate the certificates, the you need to pass the ACME validation challenge. This requires requests made on port 80 to your.domain.com/.well-known/ to be forwarded to this container.

The recommended way to use this image is to set up your reverse proxy to automatically forward requests for the ACME validation challenges to this container.

## Nginx example

If you use nginx as a reverse proxy, you can add the following to your configuration file in order to pass the ACME challenge.

``` nginx
server {
    listen 80;
    location '/.well-known/acme-challenge' {
        default_type "text/plain";
        # Note: this works with docker-compose only if the service name is `certbot`,
        # and the `nginx` service `depends_on` the `certbot` service!
        proxy_pass http://certbot:80;
    }
}
```

## `docker-compose` example

To use this container with `docker-compose`, put something like the following into your configuration:
```yml
version '2'
services:
...
    certbot:
        image: staticfloat/docker-certbot-cron
        container_name: certbot
        volumes:
            - certbot_etc_letsencrypt:/etc/letsencrypt
        restart: unless-stopped
        environment:
            - DOMAINS="foo.bar.com baz.bar.com"
            - EMAIL=email@domain.com
...
    nginx:
        ...
        depends_on:
            - certbot
        volumes:
            - certbot_etc_letsencrypt:/etc/letsencrypt:ro
...
volumes:
    certbot_etc_letsencrypt:
        external: true
```
I personally like having my certificates stored in an external volume so that if I ever accidentally run `docker-compose down` I don't have to re-issue myself the certificates.

# More information

Find out more about letsencrypt: https://letsencrypt.org

Certbot github: https://github.com/certbot/certbot

This repository was originally forked from `@henridwyer`, many thanks to him for the good idea.  I've basically taken his approach and made it less flexible/simpler for my own use cases, so if you want this repository to do something a particular way, make sure [his repo](https://github.com/henridwyer/docker-letsencrypt-cron) doesn't already do it.

# Changelog

### 0.5
- Change the name to `docker-certbot-cron`, update documentation, strip out even more stuff I don't care about.

### 0.4
- Rip out a bunch of stuff because `@staticfloat` is a monster, and likes to do things his way

### 0.3
- Add support for webroot mode.
- Run certbot once with all domains.

### 0.2
- Upgraded to use certbot client
- Changed image to use alpine linux

### 0.1
- Initial release
