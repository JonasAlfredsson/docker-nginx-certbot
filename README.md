# docker-letsencrypt-cron
Create and automatically renew website certificates using the letsencrypt free CA.

This image will renew your certificates every 2 months, and place the lastest ones in the /certs folder on the host.

Note: before letsencrypt becomes generally available, you will need to sign up for the private beta.

# Setup

In docker-compose.yml, change the environment variables:
- set the DOMAINS environment variable to a space separated list of domains for which you want to generate certificates.
- set the EMAIL environment variable for your account on the ACME server, and where you will receive updates from letsencrypt.

If you want to use the certificates with nginx or apache, uncomment the relevant lines in scripts/run_letsencrypt.sh.

# ACME Validation challenge

To authenticate the certificates, the you need to pass the ACME validation challenge. This requires requests made to on port 80 to example.com/.well-known/ to be forwarded to this image.

## Haproxy example

If you use a haproxy reverse proxy, you can add the following to your configuration file in order to pass the ACME challenge.

``` haproxy
frontend http
  bind *:80
  acl letsencrypt_check path_beg /.well-known

  use_backend letsencrypt if letsencrypt_check

backend letsencrypt
  server letsencrypt letsencrypt:80 maxconn 32
```

## Nginx example

If you use nginx as a reverse proxy, you can add the following to your configuration file in order to pass the ACME challenge.

``` nginx
upstream letsencrypt_upstream{
  server letsencrypt:80;
}

server {
  listen              80;
  location '/.well-known/acme-challenge' {
    default_type "text/plain";
    proxy_pass http://letsencrypt_upstream;
  }
}

```

# Usage

```shell
docker-compose up -d
```

The first time you start it up, you may want to run the certificate generation script immediately:

```shell
docker exec letsencrypt sh -c "/run_letsencrypt.sh"
```

At 3AM, on the 1st of every even month, a cron job will start the script, renewing your certificates.

# More information

Find out more about letsencrypt: https://letsencrypt.org

Sign up for the private beta: https://letsencrypt.org/2015/11/12/public-beta-timing.html

Letsencrypt github: https://github.com/letsencrypt/letsencrypt
