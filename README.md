# docker-nginx-certbot
Create and automatically renew website SSL certificates using the letsencrypt 
free certificate authority, and its client *certbot*, built on top of the nginx 
server running on Debian. OpenSSL is used to create the Diffie-Hellman 
parameters used during the initial handshake.

# Acknowledgments and Thanks

This container requests SSL certificates from 
[Let's Encrypt](https://letsencrypt.org/), with the help of their 
[*certbot*](https://github.com/certbot/certbot) script, which they provide for 
the absolutley bargain price of free! 
If you like what they do, please [donate](https://letsencrypt.org/donate/).


This repository was originally forked from `@henridwyer` by `@staticfloat`, 
and is now forked again by me! I thought the container could be more autonomous 
and a little bit stricter when it comes to checking that all files exist. This
container also allows for multiple server names when requesting certificates 
(i.e. both example.com and www.example.com will be included in the same 
certificate request if they are defined in the nginx configuration files).


# Usage

## Before you start
This guide expects you to already have a domain name which points at your 
address, and have both port 80 and 443 correctly forwarded if you are behind 
NAT. Otherwise I reccomend [DuckDNS](https://www.duckdns.org/) as a Dynamic DNS 
provider, and then either search on how to port forward on your router or maybe 
find it [here](https://portforward.com/router.htm). 

This image have not yet been publicized to Dockerhub, so for now you will have
to download this repository.

I don't think it is neccessary to point out if you found this repository, 
however, I have been proven wrong before so I want to make it clear that this is
a Dockerfile which requires [Docker](https://www.docker.com/) to function. 

## Creating a proper server config

As an example of a very barebone (but functional) https server in nginx you can 
find the file `example_server.conf` inside the `example` directory. By replacing 
`yourdomain.org` with your own domain you can use this file to quickly test if 
things are working. 

### Initial testing
In case you are experimenting with setting this up I suggest you set the 
environment variable `IS_STAGING=1` as this will change the challenge URL to 
the staging one. This will not give you 'proper' certificates, but it has 
ridiculous high 
[rate limits](https://letsencrypt.org/docs/staging-environment/) compared to 
the 'real' [production certificates](https://letsencrypt.org/docs/rate-limits/).

### Diffie-Hellman parameters

Regarding the Diffie-Hellman parameter it is recommended that you have one for 
your server. However, you can make a config file without it and nginx will work
fine with ciphers that don't rely on Diffie-Hellman key exchange. 
([Info about
ciphers](https://raymii.org/s/tutorials/Strong_SSL_Security_On_nginx.html)).

The larger you make these parameters the longer it will take to generate them. 
I was unlucky and it took me 65 minutes to generate a 4096 bit parameter on an 
old 3.0Ghz CPU. This will vary greatly between runs as some randomness is 
involved. A 2048 bit parameter, which is still secure today, can probably be 
calculated in about 3-5 minutes on a modern CPU. To modify the size of the 
parameter you may set the `DHPARAM_SIZE` environment variable. Default is 2048 
if nothing is provided.

It is also posible to have all your server configs point to the same 
Diffie-Hellman parameter on disk. There doesn't seem to be any negative effects 
doing it for home use 
[[1](https://security.stackexchange.com/questions/70831/does-dh-parameter-file-need-to-be-unique-per-private-key)]
[[2](https://security.stackexchange.com/questions/94390/whats-the-purpose-of-dh-parameters)].
For persistence you should probably place it inside the dedicated
folder `/etc/letsencrypt/dhparams/` which is insde a Docker volume. There is
however no requirement to do so, as a missing parameter will be created where 
the config file expects the file to be. This means that you may also create this
file on an external computer and mount it to any folder that is not under 
`/etc/letsencrypt/` as that will casue a double mount. 

## Run with just Docker 
Place any additional server configuration you desire inside the `nginx_confd/` 
folder and run the following commands in your terminal while residing inside 
the `src/` folder.
```bash
docker build --tag dnc:latest . 
```
```bash
docker run -d --env CERTBOT_EMAIL=your@email.org -p 80:80 -p 443:443 \
-v nginx_secrets:/etc/letsencrypt dnc:latest  
```

## Run with docker-compose

An example of a `docker-compose.yaml` file can be found in the `example` folder.
That file takes use of an Environment file which is called `ENVS` in the same 
folder. If that is not to your liking they can be included in the `.yaml` like
this instead:
```yaml
version: '3'
services:
    nginx:
        environment:
            - CERTBOT_EMAIL=your@email.org
            - IS_STAGING=0
            - DHPARAM_SIZE=2048
            - RSA_KEY_SIZE=2048
  ...
```

This is then built and started with 

```bash
docker-compose build 
```
```bash
docker-compose up  
```

# Changelog

### 0.9
- `@JonasAlfredsson` enters the battle.
- Diffie-Hellman parameters are now automatically created.
- Nginx now handles everything http related, certbot set to webroot mode.
- Better checking to see if necessary files exist.
- Will now request a certificate that includes all domain variants listed 
  in `server_name`.
- More extensive documentation.

### 0.8
- Ditch cron, it never liked me anway.  Just use `sleep` and a `while` 
  loop instead.

### 0.7
- Complete rewrite, build this image on top of the `nginx` image, and run 
  `cron`/`certbot` alongside `nginx` so that we can have nginx configs 
  dynamically enabled as we get SSL certificates.

### 0.6
- Add `nginx_auto_enable.sh` script to `/etc/letsencrypt/` so that users can 
  bring nginx up before SSL certs are actually available.

### 0.5
- Change the name to `docker-certbot-cron`, update documentation, strip out 
  even more stuff I don't care about.

### 0.4
- Rip out a bunch of stuff because `@staticfloat` is a monster, and likes to 
  do things his way

### 0.3
- Add support for webroot mode.
- Run certbot once with all domains.

### 0.2
- Upgraded to use certbot client
- Changed image to use alpine linux

### 0.1
- Initial release
