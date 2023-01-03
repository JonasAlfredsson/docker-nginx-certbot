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

Note that when switching to production certificates you either need to remove the
staging certificates or issue a [force renewal](./advanced_usage.md#manualforce-renewal)
since by default certbot will *not* request new certificates if any valid
(staging or production) certificates already exist.

## Creating a Server `.conf` File
As an example of a barebone (but functional) SSL server in Nginx you can
look at the file [`example_server.conf`](../examples/example_server.conf)
inside the [`examples/`](../examples) directory. By replacing '`yourdomain.org`'
with your own domain you can actually use this config to quickly test if things
are working properly. When doing this for real you should also change the
certificate paths'
["test-name"](#how-the-script-add-domain-names-to-certificate-requests) to
something more descriptive.

Place the modified config inside your [`user_conf.d/`](#the-user_confd-folder)
folder, and then run it as described
[in the main README](../README.md#run-with-docker-run). Let the container do
it's [magic](#diffie-hellman-parameters) for a while, and then try to visit
your domain. You should now be greeted with the string \
"`Let's Encrypt certificate successfully installed!`".

The files [already present](../src/nginx_conf.d) inside the container's config
folder are there to handle redirection to HTTPS for all incoming requests that
are not part of the certbot challenge requests, so be careful to not overwrite
these unless you know what you are doing.

## The `user_conf.d` Folder
Nginx will, by default, load any file ending with `.conf` from within the
`/etc/nginx/conf.d/` folder. However, this image makes use of one important
[configuration file](../src/nginx_conf.d) which need to be present (unless you
know how to replace it with your own), and host mounting a local folder to
the aforementioned location would shadow this important file.

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
ssl_certificate_key /etc/letsencrypt/live/test-name/privkey.pem;
```

and only extract the part which here says "`test-name`". This is the value that
will be provided to the [`--cert-name`][14] argument for certbot, so while you
may set basically any name you want here I suggest you keep it descriptive for
your own sake.

After this the script will find all the lines that contain `server_name` and
make a list of all the domain names that exist on the same line. So a file
containing something like this:

```
server {
    listen              443 ssl;
    server_name         yourdomain.org www.yourdomain.org;
    ssl_certificate_key /etc/letsencrypt/live/test-name/privkey.pem;
    ...
}

server {
    listen              443 ssl;
    server_name         sub.yourdomain.org;
    ssl_certificate_key /etc/letsencrypt/live/test-name/privkey.pem;
    ...
}
```

will share the same certificate file (i.e. the "test-name" certificate), and
all listed domain variants will be included as valid [alt names][15]. It is
also possible to split these sever blocks into two separate config files,
as the script will keep track of the "test-name" value across the scans and just
add any additional findings to it. So in the end we will get a single request
that looks something like this:

```
certbot --cert-name "test-name" ... -d yourdomain.org -d www.yourdomain.org -d sub.yourdomain.org
```

The scripts are quite powerful when it comes to customizability for defining
what should be included in the request, but this is considered a more advanced
usecase that may be further studied in the
[Override `server_name`](./advanced_usage.md#override-server_name) section of
the Advanced Usage document.

Furthermore, we support wildcard domain names, but that requires you to use an
authenticator capable of DNS-01 challenges, and more info about that may be
found in the [certbot_authenticators.md](./certbot_authenticators.md) document.


## ECDSA and RSA Certificates
[ECDSA (or ECC)][16] certificates use a newer encryption algorithm than the well
established RSA certificates, and are supposedly more secure while being much
smaller. The downside with these is that they are not supported by all clients
yet, but if you don't expect to serve anything outisde the "Modern" row in
[Mozillas compatibility table][17] you should not hesitate to configure certbot
to request these types of certificates.

This is achieved by setting the [environment variable](../README.md#optional)
`USE_ECDSA=1` (the default since version 3.0.1), and you can optionally tune
which [curve][18] to use with `ELLIPTIC_CURVE`. If you already have RSA
certificates downloaded you will either have to wait until they expire, or
[force](./advanced_usage.md#manualforce-renewal) a renewal, before this change
takes affect.

With this option you will create only ECDSA certificates for all of your server
configurations, however, I should mention that there is a way to configure
Nginx to serve both ECDSA and RSA certificates at the same time, but this
is explained further in the
[Advanced Usage](./advanced_usage.md#multi-certificate-setup) document.



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
[`example_server.conf`](../examples/example_server.conf)). However, you can
make a config file without it and Nginx will work just fine with ciphers that
don't rely on the Diffie-Hellman key exchange ([more info about ciphers][7]).

The larger you make these parameters the longer it will take to generate them.
I was unlucky and it took me 65 minutes to generate a 4096 bit parameter on a
really old 3.0GHz CPU. This will vary **greatly** between runs as some
randomness is involved. A 2048 bit parameter, which is still secure today, can
probably be calculated in about 1-3 minutes on a modern CPU (this process will
only have to be done once, since one of these parameters is good for the rest
of your website's lifetime). To modify the size of the parameter you may set the
`DHPARAM_SIZE` environment variable. Default is `2048` if nothing is provided.

It is also possible to have **all** your server configs point to **the same**
Diffie-Hellman parameter on disk. There is no negative effects in doing this for
home use ([source 1][8] & [source 2][9]). For persistence you should place it
inside the dedicated folder `/etc/letsencrypt/dhparams/`, which is inside the
predefined Docker [volume](../README.md#volumes). There is, however, no
requirement to do so, since a missing parameter will be created where the
config file expects the file to be. But this would mean that the script will
have to re-create these every time you restart the container, which may become
a little bit tedious.

You can also create this file on a completely different (faster?) computer and
just mount/copy the created file into this container. This is perfectly fine,
since it is nothing "private/personal" about this file. The only thing to
think about in that case would perhaps be to use a folder that is not under
`/etc/letsencrypt/`, since that would otherwise cause a double mount.

## Help Migrating from `@staticfloat`'s Image
The two images are not that different when it comes to building/running, since
this repository was originally a fork. So just like in `@staticfloat`'s setup
you need to get your own `*.conf` files into the container's
`/etc/nginx/conf.d/` folder, and then you should be able to start this one
just like you did with his.

This can either be done by copying your own files into the container at
[build time](../README.md#build-it-yourself), or you can mount a local folder to
[`/etc/nginx/user_conf.d/`](#the-user_confd-folder) and
[run it directly](../README.md#run-with-docker-run). In the former case you need
to make sure you do not accidentally overwrite the two files present in this
repository's [`nginx_conf.d/`](../src/nginx_conf.d) folder, since these are
required in order for certbot to request certificates.

The only obligatory environment variable for starting this container is the
[`CERTBOT_EMAIL`](../README.md#required) one, just like in `@staticfloat`'s
case, but I have exposed a [couple of more](../README.md#optional) that can be
changed from their defaults if you like. Then there is of course any environment
variables read by the [parent container][11] as well, but those are probably
not as important.

If you were using [templating][12] before, you should probably look into
["template" files][13] used by the Nginx parent container, since this is not
something I have personally implemented in mine.





[1]: https://letsencrypt.org/docs/staging-environment/
[2]: https://letsencrypt.org/docs/rate-limits/
[3]: https://github.com/JonasAlfredsson/docker-nginx-certbot/commit/91f8ecaa613f1e7c0dc4ece38fa8f38a004f61ec
[4]: http://man7.org/linux/man-pages/man1/sleep.1.html
[5]: https://github.com/staticfloat/docker-nginx-certbot
[6]: https://community.letsencrypt.org/t/solved-how-often-to-renew/13678
[7]: https://raymii.org/s/tutorials/Strong_SSL_Security_On_nginx.html
[8]: https://security.stackexchange.com/questions/70831/does-dh-parameter-file-need-to-be-unique-per-private-key
[9]: https://security.stackexchange.com/questions/94390/whats-the-purpose-of-dh-parameters

[11]: https://github.com/nginxinc/docker-nginx
[12]: https://github.com/staticfloat/docker-nginx-certbot#templating
[13]: https://github.com/docker-library/docs/tree/master/nginx#using-environment-variables-in-nginx-configuration-new-in-119
[14]: https://certbot.eff.org/docs/using.html#where-are-my-certificates
[15]: https://www.digicert.com/faq/subject-alternative-name.htm
[16]: https://sectigostore.com/blog/ecdsa-vs-rsa-everything-you-need-to-know/
[17]: https://wiki.mozilla.org/Security/Server_Side_TLS
[18]: https://security.stackexchange.com/questions/31772/what-elliptic-curves-are-supported-by-browsers/104991#104991
