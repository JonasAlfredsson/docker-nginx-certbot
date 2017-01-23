# docker-certbot-cron
Create and automatically renew website SSL certificates using the letsencrypt free certificate authority, and its client *certbot*.

# More information

Find out more about letsencrypt: https://letsencrypt.org

Certbot github: https://github.com/certbot/certbot

This repository was originally forked from `@henridwyer`, many thanks to him for the good idea.  I've rewritten about 90% of this repository, so it bears almost no resemblance to the original.  This repository is _much_ more opinionated about the structure of your webservers/code, however it is easier to use as long as all of your webservers follow that pattern.

# Changelog

### 0.7
- Complete rewrite, build this image on top of the `nginx` image, and run `cron` alongside `nginx` so that we can have nginx configs dynamically enabled as we get SSL certificates.

### 0.6
- Add `nginx_auto_enable.sh` script to `/etc/letsencrypt/` so that users can bring nginx up before SSL certs are actually available.

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
