# docker-nginx-certbot
Create and automatically renew website SSL certificates using the Let's Encrypt 
free certificate authority and its client *certbot*. Built on top of the Nginx 
server running on Debian. OpenSSL is used to create the Diffie-Hellman 
parameters used during the initial handshake.

# Acknowledgments and Thanks

This container requests SSL certificates from 
[Let's Encrypt](https://letsencrypt.org/), with the help of their 
[*certbot*](https://github.com/certbot/certbot) script, which they provide for 
the absolutely bargain price of free! 
If you like what they do, please [donate](https://letsencrypt.org/donate/).


This repository was originally forked from `@henridwyer` by `@staticfloat`, 
and is now forked again by me! I thought the container could be more autonomous 
and stricter when it comes to checking that all files exist. In addition,
this container also allows for multiple server names when requesting
certificates (i.e. both `example.com` and `www.example.com` will be included in
the same certificate request if they are defined in the Nginx configuration
files).

# Usage

## Before you start
1. This guide expects you to already own a domain which points at the correct 
   IP address, and that you have both port `80` and `443` correctly forwarded if 
   you are behind NAT. 
   Otherwise I recommend [DuckDNS](https://www.duckdns.org/) as a Dynamic DNS 
   provider, and then either search on how to port forward on your router or 
   maybe find it [here](https://portforward.com/router.htm). 

2. Tips on how to make a proper server config file, and how to create a simple
   test, can be found under the [Good to Know
   ](https://github.com/JonasAlfredsson/docker-nginx-certbot/#good-to-know)
   section. 

3. I don't think it is necessary to mention if you managed to find this 
   repository, however, I have been proven wrong before so I want to make it 
   clear that this is a Dockerfile which requires 
   [Docker](https://www.docker.com/) to function. 

## Run with `docker run`

### Build it yourself
This option is for if you have downloaded this entire repository. 

Place any additional server configuration you desire inside the `nginx_confd/` 
folder and run the following command in your terminal while residing inside 
the `src/` folder.
```bash
docker build --tag jonasal/nginx-certbot:latest . 
```

### Get it from Docker Hub
This option is for if you make your own `Dockerfile`.

This image exist on Docker Hub under `jonasal/nginx-certbot`, which means you 
can make your own `Dockerfile` for a cleaner folder structure. Just add a 
command where you copy in your own server configuration files.

```Dockerfile
FROM jonasal/nginx-certbot:latest
COPY conf.d/* /etc/nginx/conf.d/
```
Don't forget to build it!
```bash
docker build --tag jonasal/nginx-certbot:latest . 
```

### The run command
Irregardless what option you chose above you run it with the following command:
```bash
docker run -it --env CERTBOT_EMAIL=your@email.org -p 80:80 -p 443:443 \
-v nginx_secrets:/etc/letsencrypt jonasal/nginx-certbot:latest  
```
The `CERTBOT_EMAIL` environment variable is required by certbot for them to 
contact you in case of security issues.

> You should be able to detach from the container by pressing 
`Ctrl`+`p`+`Ctrl`+`o`

## Run with `docker-compose`

An example of a `docker-compose.yaml` file can be found in the `example` folder.
The default parameters that are found inside the `.env` file will be overwritten
any environment variables you set in the `.yaml` file.
```yaml
version: '3'
services:
  nginx-certbot:
    build: .
    restart: unless-stopped
    environment:
        - CERTBOT_EMAIL=your@email.org
        - STAGING=0
        - DHPARAM_SIZE=2048
        - RSA_KEY_SIZE=2048
    ports:
      - 80:80
      - 443:443
    volumes:
      - nginx_secrets:/etc/letsencrypt

volumes:
  nginx_secrets:
```

You then build and start with the following commands. Just remember to 
place any additional server configs you want inside the `nginx_confd/` folder
beforehand.

```bash
docker-compose up --build
```

# Good to Know

### Initial testing
In case you are experimenting with setting this up I suggest you set the 
environment variable `STAGING=1` as this will change the challenge URL to 
the staging one. This will not give you *proper* certificates, but it has 
ridiculous high 
[rate limits](https://letsencrypt.org/docs/staging-environment/) compared to 
the non-staging
[production certificates](https://letsencrypt.org/docs/rate-limits/).

Include it like this:
```bash
docker run -d --env CERTBOT_EMAIL=your@email.org --env STAGING=1 \
-p 80:80 -p 443:443 jonasal/nginx-certbot:latest  
```

### Creating a server .conf file

As an example of a barebone (but functional) SSL server in Nginx you can 
look at the file `example_server.conf` inside the `example` directory. By 
replacing '`yourdomain.org`' with your own domain you can actually use this 
config to quickly test if things are working properly.

Place the modified config inside `nginx_confd/`, `build` the container and then 
run it as described [above
](https://github.com/JonasAlfredsson/docker-nginx-certbot/#usage). Let it do 
it's magic for a while, and then try to visit your domain. You should be greeted
with the string `Let's Encrypt certificate successfully installed!`

### How the script add domain names to certificate requests

The script will go trough all configuration files it finds inside Nginx's 
`conf.d` folder, and create requests from the file's content. In every unique 
file it will find the line that says
```
ssl_certificate_key /etc/letsencrypt/live/yourdomain.org/privkey.pem;
```
which means that the "primary domain" is `yourdomain.org`. It will then find all
the lines that contain `server_name` and make a list of all the words that exist
on the same line. So a file containing something like this:
```
server {
    listen              443 ssl;
    server_name         yourdomain.org www.yourdomain.org;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.org/privkey.pem;
    ...
}

server {
    listen              443 ssl;
    server_name         yourdomain.org sub.yourdomain.org;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.org/privkey.pem;
    ...
}
```
will share the same certificate, but the certbot command will include all
listed domain variants. The limitation is that you should list all your 
listening servers that have the same primary domain in the same file. The 
certificate request from the above file will then become something like this:
```
certbot ... -d yourdomain.org -d www.yourdomain.org -d sub.yourdomain.org
```

### Diffie-Hellman parameters

Regarding the Diffie-Hellman parameter it is recommended that you have one for 
your server. However, you can make a config file without it and Nginx will work
fine with ciphers that don't rely on Diffie-Hellman key exchange. 
([Info about
ciphers](https://raymii.org/s/tutorials/Strong_SSL_Security_On_nginx.html)).

The larger you make these parameters the longer it will take to generate them. 
I was unlucky and it took me 65 minutes to generate a 4096 bit parameter on an 
old 3.0GHz CPU. This will vary greatly between runs as some randomness is 
involved. A 2048 bit parameter, which is still secure today, can probably be 
calculated in about 3-5 minutes on a modern CPU. To modify the size of the 
parameter you may set the `DHPARAM_SIZE` environment variable. Default is `2048`
if nothing is provided.

It is also possible to have all your server configs point to the same 
Diffie-Hellman parameter on disk. There is no negative effects in doing this for
home use 
[[1](https://security.stackexchange.com/questions/70831/does-dh-parameter-file-need-to-be-unique-per-private-key)]
[[2](https://security.stackexchange.com/questions/94390/whats-the-purpose-of-dh-parameters)].
For persistence you should place it inside the dedicated
folder `/etc/letsencrypt/dhparams/` which is inside a Docker volume. There is
however no requirement to do so, as a missing parameter will be created where 
the config file expects the file to be. This means that you may also create this
file on an external computer and mount it to any folder that is not under 
`/etc/letsencrypt/` as that will cause a double mount. 

# Changelog

### 0.9-gamma
- Make both Nginx and the update script child processes of the entryscript.
- Container will now die along with Nginx like it should.
- The Diffie-Hellman parameters now have better permissions.
- Container now exist on Docker Hub under `jonasal/nginx-certbot:latest`
- More documentation.

### 0.9-beta
- `@JonasAlfredsson` enters the battle.
- Diffie-Hellman parameters are now automatically generated.
- Nginx now handles everything http related, certbot set to webroot mode.
- Better checking to see if necessary files exist.
- Will now request a certificate that includes all domain variants listed 
  at the `server_name` line.
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
