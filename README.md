# docker-nginx-certbot

Automatically create and renew website SSL certificates using the Let's Encrypt
free certificate authority and its client *certbot*. Built on top of the Nginx
server running on Debian. OpenSSL is used to automatically create the
Diffie-Hellman parameters used during the initial handshake of some ciphers.

> :information_source: The very first time this container is started it might
  take a long time before before it is ready to respond to requests. Read more
  about this in the [Diffie-Hellman parameters](#diffie-hellman-parameters)
  section.



# Acknowledgments and Thanks

This container requests SSL certificates from [Let's Encrypt][1], with the help
of their [*certbot*][2] script, which they provide for the absolutely bargain
price of free! If you like what they do, please [donate][3].

This repository was originally forked from [`@henridwyer`][4] by
[`@staticfloat`][5], before it was forked again by me. However, the changes to
the code has since become so significant that this has now been detached as its
own independent repository (while still retaining all the history).

I thought the container could be more autonomous and stricter when it comes to
checking that all files exist. In addition, this container also allows for
multiple server names when requesting certificates (i.e. both `example.com` and
`www.example.com` will be included in the same certificate request if they are
defined in the Nginx configuration files). It is also possible to easily
[force renewal](#manualforce-renewal) of certificates if necessary.



# Usage

## Before You Start
1. This guide expects you to already own a domain which points at the correct
   IP address, and that you have both port `80` and `443` correctly forwarded if
   you are behind NAT.
   Otherwise I recommend [DuckDNS](https://www.duckdns.org/) as a Dynamic DNS
   provider, and then either search on how to port forward on your router or
   maybe find it [here](https://portforward.com/router.htm).

2. Tips on how to make a proper server config file, and how to create a simple
   test, can be found under the [Good to Know](#good-to-know) section.

3. I don't think it is necessary to mention if you managed to find this
   repository, however, I have been proven wrong before so I want to make it
   clear that this is a Dockerfile which requires
   [Docker](https://www.docker.com/) to function.


## Available Environment Variables

### Required
- `CERTBOT_EMAIL`: Your e-mail address. Used by Let's Encrypt to contact you in
                   case of security issues.

### Optional
- `STAGING`: Set to `1` to use Let's Encrypt's
             [staging servers](#initial-testing) (default: `0`)
- `DHPARAM_SIZE`: The size of the
                  [Diffie-Hellman parameters](#diffie-hellman-parameters)
                  (default: `2048`)
- `RSA_KEY_SIZE`: The size of the RSA encryption keys (default: `2048`)
- `RENEWAL_INTERVAL`: Time interval between certbot's
                      [renewal checks](#renewal-check-interval) (default: `8d`)


## Volumes
- `/etc/letsencrypt`: Stores the obtained certificates and the Diffie-Hellman
                      parameters


## Run with `docker run`

### Build it yourself...
This option is for if you have downloaded this entire repository.

Place any additional server configuration you desire inside the `nginx_conf.d/`
folder and run the following command in your terminal while residing inside
the `src/` folder.

```bash
docker build --tag jonasal/nginx-certbot:local .
```

### ...or get it from Docker Hub
This option is for if you make your own `Dockerfile`.

This image exist on Docker Hub under `jonasal/nginx-certbot`, which means you
can make your own `Dockerfile` for a cleaner folder structure. Just add a
command where you copy in your own server configuration files (make sure
that none of your files replace those already present).

```Dockerfile
FROM jonasal/nginx-certbot:latest
COPY conf.d/* /etc/nginx/conf.d/
```

Don't forget to build it!

```bash
docker build --tag jonasal/nginx-certbot:local .
```

### The `run` Command
Irregardless what option you chose above you run it with the following command:

```bash
docker run -it -p 80:80 -p 443:443 \
           --env CERTBOT_EMAIL=your@email.org \
           -v $(pwd)/nginx_secrets:/etc/letsencrypt \
           --name nginx-certbot jonasal/nginx-certbot:local
```

> You should be able to detach from the container by pressing
  `Ctrl`+`p`+`Ctrl`+`o`


## Run with `docker-compose`
An example of a `docker-compose.yaml` file can be found in the `examples/`
folder. The default parameters that are found inside the `nginx-certbot.env`
file will be overwritten by any environment variables you set inside the `.yaml`
file.

Move the `.yaml` file (and optionally the `.env` file) into the `src/` folder,
and then build and start with the following commands. Just remember to place any
additional server configs you want inside the `nginx_conf.d/` folder beforehand.

```bash
docker-compose build --pull
docker-compose up
```



# Good to Know

## Initial Testing
In case you are just experimenting with setting this up I suggest you set the
environment variable `STAGING=1`, since this will change the challenge URL to
the staging one. This will not give you "*proper*" certificates, but it has
ridiculous high [rate limits][6] compared to the non-staging
[production certificates][7].

Include it like this:
```bash
docker run -d -p 80:80 -p 443:443 \
           --env CERTBOT_EMAIL=your@email.org \
           --env STAGING=1 \
           --name nginx-certbot jonasal/nginx-certbot:latest
```

## Creating a Server `.conf` File
As an example of a barebone (but functional) SSL server in Nginx you can
look at the file `example_server.conf` inside the `examples/` directory. By
replacing '`yourdomain.org`' with your own domain you can actually use this
config to quickly test if things are working properly.

Place the modified config inside the `nginx_conf.d/` folder, `build` the
container and then run it as described [above](#usage). Let the container do
it's [magic](#diffie-hellman-parameters) for a while, and then try to visit
your domain. You should now be greeted with the string \
"`Let's Encrypt certificate successfully installed!`".

## How the Script add Domain Names to Certificate Requests
The included script will go trough all configuration files (`*.conf*`) it
finds inside Nginx's `/etc/nginx/conf.d/` folder, and create requests from the
file's content. In every unique file it will find any line that says:

```
ssl_certificate_key /etc/letsencrypt/live/yourdomain.org/privkey.pem;
```

and only extract the part which here says "`yourdomain.org`", and this will
henceforth be used as the "primary domain" for this config file. It will then
find all the lines that contain `server_name` and make a list of all the domain
names that exist on the same line. So a file containing something like this:

```
server {
    listen              443 ssl;
    server_name         yourdomain.org www.yourdomain.org;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.org/privkey.pem;
    ...
}

server {
    listen              443 ssl;
    server_name         sub.yourdomain.org www.yourdomain.org;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.org/privkey.pem;
    ...
}
```

will share the same certificate file (the "primary domain"), but the certbot
command will include all listed domain variants. The limitation is that you
should write all your server blocks that have the same primary domain in the
same file. The certificate request from the above file will then become
something like this (duplicates will be removed):

```
certbot ... -d yourdomain.org -d www.yourdomain.org -d sub.yourdomain.org
```

## Renewal Check Interval
This container will automatically start a certbot certificate renewal check
after the time duration that is defined in the environmental variable
`RENEWAL_INTERVAL` has passed. After certbot has done its stuff, the code will
return and wait the defined time before triggering again.

This process is very simple, and is just a `while [ true ];` loop with a `sleep`
at the end:

```bash
while [ true ]; do
    # Run certbot...
    sleep "$RENEWAL_INTERVAL"
done
```

So when setting the environmental variable, it is possible to use any string
that is recognized by `sleep`, e.g. `3600` or `60m` or `1h`. Read more about
which values that are allowed in its [manual][8].

The default is `8d`, since this allows for multiple retries per month, while
keeping the output in the logs at a very low level. If nothing needs to be
renewed certbot won't do anything, so it should be no problem setting it lower
if you want to. The only thing to think about is to not to make it longer than
one month, because then you would [miss the window][9] where certbot would deem
it necessary to update the certificates.

## Diffie-Hellman Parameters
Regarding the Diffie-Hellman parameter it is recommended that you have one for
your server, and in Nginx you define it by including a line that starts with
`ssl_dhparam` in the server block (see `examples/example_server.conf`). However,
you can make a config file without it and Nginx will work just fine with ciphers
that don't rely on the Diffie-Hellman key exchange
([more info about ciphers][10]).

The larger you make these parameters the longer it will take to generate them.
I was unlucky and it took me 65 minutes to generate a 4096 bit parameter on an
old 3.0GHz CPU. This will vary **greatly** between runs as some randomness is
involved. A 2048 bit parameter, which is still secure today, can probably be
calculated in about 1-3 minutes on a modern CPU (this process will only have to
be done once, since one of these parameters is good for the rest of your
website's lifetime). To modify the size of the parameter you may set the
`DHPARAM_SIZE` environment variable. Default is `2048` if nothing is provided.

It is also possible to have **all** your server configs point to **the same**
Diffie-Hellman parameter on disk. There is no negative effects in doing this for
home use ([source 1][11] & [source 2][12]). For persistence you should place it
inside the dedicated folder `/etc/letsencrypt/dhparams/`, which is inside the
predefined Docker [volume](#volumes). There is, however, no requirement to do
so, since a missing parameter will be created where the config file expects the
file to be. But this would mean that the script will have to re-create these
every time you restart the container, which may become a little bit tedious.

You can also create this file on a completely different (faster?) computer and
just mount/copy the created file into this container. This is perfectly fine,
since it is nothing "private/personal" about this file. The only thing to
think about in that case would perhaps be to use a folder that is not under
`/etc/letsencrypt/`, since that would otherwise cause a double mount.

## Manual/Force Renewal
It might be of interest to manually trigger a renewal of the certificates, and
that is why the `run_certbot.sh` script is possible to run standalone at any
time from within the container.

However, the preferred way of requesting a reload of all the configuration files
is to send in a `SIGHUP` to the container:

```bash
docker kill --signal=HUP <container_name>
```

This will terminate the [sleep timer](#renewal-check-interval) and make the
renewal loop start again from the beginning.

While this will be enough in the majority of the cases, it might sometimes be
necessary to **force** a renewal of the certificates even though certbot thinks
it could keep them for a while longer (like when [this][13] happened). It is
therefore possible to add "force" as an argument, when calling the
`run_certbot.sh` script, to have it append the `--force-renewal` flag to the
requests made.

```bash
docker exec -it <container_name> /scripts/run_certbot.sh force
```

This will request new certificates irregardless of then they are set to expire.

> NOTE: Using "force" will make new requests for **all** you certificates, so
        don't run it too often since there are some limits to requesting
        [production certificates][7].




# Changelog

### 0.16
- Container now listens to [`SIGHUP`](#manualforce-renewal) and will reload
  all configs if this signal is received.
  - More details can be found in the commit message: [bf2c135][18]
- Made Docker image slightly smaller by including `--no-install-recommends`.
- There is now also a [`dev` branch][17]/tag if you are brave and want to run
  experimental builds.
- JonasAlfredsson/docker-nginx-certbot is now its own independent repository
  (i.e. no longer just a fork).

### 0.15
- It is now possible to [manually trigger](#manualforce-renewal) a renewal of
  certificates.
  - It is also possible to include "force" to add `--force-renewal` to the
    request.
- The "clean exit" trap now handle that parent container changed to
  [`SIGQUIT`][15] as stop signal.
- The "certbot" server block (in Nginx) now prints to stdout by default.
- Massive refactoring of both code and files:
  - Our "start **command**" file is now called `start_nginx_certbot.sh` instead
    of `entrypoint.sh`.
  - Both `create_dhparams.sh` and `run_certbot.sh` can now be run by themselves
    inside the container.
  - I have added `set -e` in most of the files so the program exit as intended
    when unexpected errors occurs.
  - Added `{}` and `""` around most of the bash variables.
  - Change some log messages and where they appear.
- Our `/scripts/startup/` folder has been removed.
  - The parent container will run any `*.sh` file found inside the
    [`/docker-entryoint.d/`][16] folder.

### 0.14
- Made so that the container now exits gracefully and reports the correct exit
  code.
  - More details can be found in the commit message: [43dde6e][14]
- Bash script now correctly monitors **both** the Nginx and the certbot renewal
  process PIDs.
  - If either one of these processes dies, the container will exit with the same
    exit code as that process.
  - This will also trigger a graceful exit for the rest of the processes.
- Removed unnecessary and empty `ENTRYPOINT` from Dockerfile.
- A lot of refactoring of the code, cosmetic changes and editing of comments.

### 0.13
- Fixed the regex used in all of the `sed` commands.
  - Now makes sure that the proper amount of spaces are present in the right
    places.
  - Now allows comments at the end of the lines in the configs. `# Nice!`
  - Made the expression a little bit more readable thanks to the `-r` flag.
- Now made certbot solely responsible for checking if the certificates needs to
  be renewed.
  - Certbot is actually smart enough to not send any renewal requests if it
    doesn't have to.
- The time interval used to trigger the certbot renewal check is now user
  configurable.
  - The environment variable to use is `RENEWAL_INTERVAL`.

### 0.12
- Added `--cert-name` flag to the certbot certificate request command.
  - This allows for both adding and subtracting domains to the same certificate
    file.
  - Makes it possible to have path names that are not domain names (but this
    is not allowed yet).
- Made the file parsing functions smarter so they only find unique file paths.
- Cleaned up some log output.
- Updated the `docker-compose` example.
- Fixed some spelling in the documentation.

### 0.11
- Python 2 is EOL, so it's time to move over to Python 3.
- From now on DockerHub will also automatically build with tags.
  - Lock the version by specifying the tag: `jonasal/nginx-certbot:0.11`

### 0.10
- Update to new ACME v2 servers.

### 0.9
- I am now confident enough to remove the version suffixes.
- `nginx:mainline` is now using Debian 10 Buster.
- Updated documentation.

### 0.9-gamma
- Make both Nginx and the update script child processes of the `entrypoint.sh`
  script.
- Container will now die along with Nginx like it should.
- The Diffie-Hellman parameters now have better permissions.
- Container now exist on Docker Hub under `jonasal/nginx-certbot:latest`
- More documentation.

### 0.9-beta
- `@JonasAlfredsson` enters the battle.
- Diffie-Hellman parameters are now automatically generated.
- Nginx now handles everything HTTP related -> certbot set to webroot mode.
- Better checking to see if necessary files exist.
- Will now request a certificate that includes all domain variants listed
  on the `server_name` line.
- More extensive documentation.

### 0.8
- Ditch cron, it never liked me anyway.  Just use `sleep` and a `while`
  loop instead.

### 0.7
- Complete rewrite, build this image on top of the `nginx` image, and run
  `cron`/`certbot` alongside `nginx` so that we can have Nginx configs
  dynamically enabled as we get SSL certificates.

### 0.6
- Add `nginx_auto_enable.sh` script to `/etc/letsencrypt/` so that users can
  bring Nginx up before SSL certs are actually available.

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






[1]: https://letsencrypt.org/
[2]: https://github.com/certbot/certbot
[3]: https://letsencrypt.org/donate/
[4]: https://github.com/henridwyer/docker-letsencrypt-cron
[5]: https://github.com/staticfloat/docker-nginx-certbot
[6]: https://letsencrypt.org/docs/staging-environment/
[7]: https://letsencrypt.org/docs/rate-limits/
[8]: http://man7.org/linux/man-pages/man1/sleep.1.html
[9]: https://community.letsencrypt.org/t/solved-how-often-to-renew/13678
[10]: https://raymii.org/s/tutorials/Strong_SSL_Security_On_nginx.html
[11]: https://security.stackexchange.com/questions/70831/does-dh-parameter-file-need-to-be-unique-per-private-key
[12]: https://security.stackexchange.com/questions/94390/whats-the-purpose-of-dh-parameters
[13]: https://community.letsencrypt.org/t/revoking-certain-certificates-on-march-4/114864
[14]: https://github.com/JonasAlfredsson/docker-nginx-certbot/commit/43dde6ec24f399fe49729b28ba4892665e3d7078
[15]: https://github.com/nginxinc/docker-nginx/commit/3fb70ddd7094c1fdd50cc83d432643dc10ab6243
[16]: https://github.com/nginxinc/docker-nginx/tree/master/entrypoint
[17]: https://github.com/JonasAlfredsson/docker-nginx-certbot/tree/dev
[18]: https://github.com/JonasAlfredsson/docker-nginx-certbot/commit/bf2c1354f55adffadc13b1f1792e205f9dd25f86
