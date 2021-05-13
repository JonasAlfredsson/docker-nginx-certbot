# Good to Know
This document contains information about features and behavior that might be
good to know before you start using this image. Feel free to read it all, but I
recommend the first two sections for everyone.

## Initial Testing
In case you are just experimenting with setting this up I suggest you set the
environment variable `STAGING=1`, since this will change the Let's Encrypt
challenge URL to their staging one. This will not give you "*proper*"
certificates, but it has ridiculous high [rate limits][1] compared to the
non-staging [production certificates][2] so you can do more mistakes without
having to worry. You can also add `DEBUG=1` for more verbose logging to better
understand what is going on.

Include them like this:
```bash
docker run -it -p 80:80 -p 443:443 \
           --env CERTBOT_EMAIL=your@email.org \
           --env STAGING=1 \
           --env DEBUG=1 \
           jonasal/nginx-certbot:latest
```

## Creating a Server `.conf` File
As an example of a barebone (but functional) SSL server in Nginx you can
look at the file `example_server.conf` inside the [`examples/`][examples]
directory. By replacing '`yourdomain.org`' with your own domain you can
actually use this config to quickly test if things are working properly.

Place the modified config inside your [`user_conf.d/`](#the-user_confd-folder)
folder, and then run it as described [in the main README][run-with-docker-run].
Let the container do it's [magic](#diffie-hellman-parameters) for a while, and
then try to visit your domain. You should now be greeted with the string \
"`Let's Encrypt certificate successfully installed!`".

The files [already present][nginx_confd] inside the container's config folder
are there to handle redirection to HTTPS for all incoming requests that are not
part of the certbot challenge requests, so be careful to not overwrite these
unless you know what you are doing.

## The `user_conf.d` Folder
Nginx will, by default, load any file ending with `.conf` from within the
`/etc/nginx/conf.d/` folder. However, this image makes use of two important
[configuration files][nginx_confd] which need to be present (unless you
know how to replace them with your own), and host mounting a local folder to
the aforementioned location would shadow these important files.

To solve this problem I therefore suggest you host mount a local folder to
`/etc/nginx/user_conf.d/` instead, and a part of the management scripts will
[create symlinks][3] from `conf.d/` to the files in `user_conf.d/`. This way
we give users a simple way to just start the container, without having to build
a local image first, while still giving them the opportunity to keep doing it
in the old way like how [`@staticfloat`'s image][5] worked.


## How the Script add Domain Names to Certificate Requests
The included script will go through all configuration files (`*.conf*`) it
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
    server_name         sub.yourdomain.org;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.org/privkey.pem;
    ...
}
```

will share the same certificate file (the "primary domain"), but the certbot
command will include all listed domain variants. The limitation is that you
should write all your server blocks that have the same "primary domain" in the
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
which values that are allowed in its [manual][4].

The default is `8d`, since this allows for multiple retries per month, while
keeping the output in the logs at a very low level. If nothing needs to be
renewed certbot won't do anything, so it should be no problem setting it lower
if you want to. The only thing to think about is to not to make it longer than
one month, because then you would [miss the window][6] where certbot would deem
it necessary to update the certificates.

## Diffie-Hellman Parameters
Regarding the Diffie-Hellman parameter it is recommended that you have one for
your server, and in Nginx you define it by including a line that starts with
`ssl_dhparam` in the server block (see
[`examples/example_server.conf`][nginx_confd]). However, you can make a
config file without it and Nginx will work just fine with ciphers that don't
rely on the Diffie-Hellman key exchange ([more info about ciphers][7]).

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
home use ([source 1][8] & [source 2][9]). For persistence you should place it
inside the dedicated folder `/etc/letsencrypt/dhparams/`, which is inside the
predefined Docker [volume][volumes]. There is, however, no requirement to do
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
renewal loop start again from the beginning, which includes a lot of other
checks than just the certificates.

While this will be enough in the majority of the cases, it might sometimes be
necessary to **force** a renewal of the certificates even though certbot thinks
it could keep them for a while longer (like when [this][10] happened). It is
therefore possible to add "force" as an argument, when calling the
`run_certbot.sh` script, to have it append the `--force-renewal` flag to the
requests made.

```bash
docker exec -it <container_name> /scripts/run_certbot.sh force
```

This will request new certificates irregardless of then they are set to expire.

> NOTE: Using "force" will make new requests for **all** you certificates, so
        don't run it too often since there are some limits to requesting
        [production certificates][2].


## Help Migrating from `@staticfloat`'s Image
The two images are not that different when it comes to building/running, since
this repository was originally a fork. So just like in `@staticfloat`'s setup
you need to get your own `*.conf` files into the container's
`/etc/nginx/conf.d/` folder, and then you should be able to start this one
just like you did with his.

This can either be done by copying your own files into the container at
[build time][build-it-yourself], or you can mount a local folder to
[`/etc/nginx/user_conf.d/`](#the-user_confd-folder) and
[run it directly][run-with-docker-run]. In the former case you need
to make sure you do not accidentally overwrite the two files present in this
repository's [`src/nginx_conf.d/`][nginx_confd] folder, since these are
required in order for certbot to request certificates.

The only obligatory environment variable for starting this container is the
[`CERTBOT_EMAIL`][required] one, just like in `@staticfloat`'s case, but I
have exposed a [couple of more][optional] that can be changed from their
defaults if you like. Then there is of course any environment variables read by
the [parent container][11] as well, but those are probably not as important.

If you were using [templating][12] before, you should probably look into
["template" files][13] used by the Nginx parent container, since this is not
something I have personally implemented in mine.






[examples]: https://github.com/JonasAlfredsson/docker-nginx-certbot/tree/master/examples
[run-with-docker-run]: https://github.com/JonasAlfredsson/docker-nginx-certbot#run-with-docker-run
[nginx_confd]: https://github.com/JonasAlfredsson/docker-nginx-certbot/tree/master/src/nginx_conf.d
[volumes]: https://github.com/JonasAlfredsson/docker-nginx-certbot#volumes
[build-it-yourself]: https://github.com/JonasAlfredsson/docker-nginx-certbot#build-it-yourself
[required]: https://github.com/JonasAlfredsson/docker-nginx-certbot#required
[optional]: https://github.com/JonasAlfredsson/docker-nginx-certbot#optional

[1]: https://letsencrypt.org/docs/staging-environment/
[2]: https://letsencrypt.org/docs/rate-limits/
[3]: https://github.com/JonasAlfredsson/docker-nginx-certbot/commit/91f8ecaa613f1e7c0dc4ece38fa8f38a004f61ec
[4]: http://man7.org/linux/man-pages/man1/sleep.1.html
[5]: https://github.com/staticfloat/docker-nginx-certbot
[6]: https://community.letsencrypt.org/t/solved-how-often-to-renew/13678
[7]: https://raymii.org/s/tutorials/Strong_SSL_Security_On_nginx.html
[8]: https://security.stackexchange.com/questions/70831/does-dh-parameter-file-need-to-be-unique-per-private-key
[9]: https://security.stackexchange.com/questions/94390/whats-the-purpose-of-dh-parameters
[10]: https://community.letsencrypt.org/t/revoking-certain-certificates-on-march-4/114864
[11]: https://github.com/nginxinc/docker-nginx
[12]: https://github.com/staticfloat/docker-nginx-certbot#templating
[13]: https://github.com/docker-library/docs/tree/master/nginx#using-environment-variables-in-nginx-configuration-new-in-119
