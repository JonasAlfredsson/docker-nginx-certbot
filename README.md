# docker-nginx-certbot

Automatically create and renew website SSL certificates using the Let's Encrypt
free certificate authority and its client *certbot*. Built on top of the Nginx
server running on Debian. OpenSSL is used to automatically create the
Diffie-Hellman parameters used during the initial handshake of some ciphers.

> :information_source: The very first time this container is started it might
  take a long time before before it is ready to respond to requests. Read more
  about this in the [Diffie-Hellman parameters][diffie-hellman-parameters]
  section.



# Acknowledgments and Thanks

This container requests SSL certificates from [Let's Encrypt][1], with the help
of their [*certbot*][2] script, which they provide for the absolutely bargain
price of free! If you like what they do, please [donate][3].

This repository was originally forked from [`@henridwyer`][4] by
[`@staticfloat`][5], before it was forked again by me. However, the changes to
the code has since become so significant that this has now been detached as its
own independent repository (while still retaining all the history). Migration
instructions, from `@staticfloat`'s image, can be found
[here][help-migrating-from-staticfloats-image].

Some of the more significant additions to this container:

- Handles multiple server names when
  [requesting certificates][how-the-script-add-domain-names-to-certificate-requests]
  (i.e. both `example.com` and `www.example.com`).
- Will create [Diffie-Hellman parameters][diffie-hellman-parameters] if they
  are defined.
- Uses the [parent container][9]'s [`/docker-entrypoint.d/`][7] folder.
- Will report correct [exit code][6] when stopped/killed/failed.
- Stricter when it comes to checking that all files exist.
- Easy to [force renewal][manualforce-renewal] of certificates if necessary.
- You can do a live reload of configs by
  [sending in a `SIGHUP`][manualforce-renewal] signal.
- You can tune your own [renewal interval][renewal-check-interval].
- Builds for multiple architectures available on [Docker Hub][8].



# Usage

## Before You Start
1. This guide expects you to already own a domain which points at the correct
   IP address, and that you have both port `80` and `443` correctly forwarded if
   you are behind NAT. Otherwise I recommend [DuckDNS][12] as a Dynamic DNS
   provider, and then either search on how to port forward on your router or
   maybe find it [here][13].

2. I suggest you read at least the first two sections in the
   [Good to Know][good-to-know] documentation, since this will give you some
   important tips on how to create a basic server config, and how to use
   the Let's Encrypt staging servers in order to not get rate limited.

3. I don't think it is necessary to mention if you managed to find this
   repository, but you will need to have [Docker][11] installed for this to
   function.


## Available Environment Variables

### Required
- `CERTBOT_EMAIL`: Your e-mail address. Used by Let's Encrypt to contact you in case of security issues.

### Optional
- `STAGING`: Set to `1` to use Let's Encrypt's [staging servers][initial-testing] (default: `0`)
- `DHPARAM_SIZE`: The size of the [Diffie-Hellman parameters][diffie-hellman-parameters] (default: `2048`)
- `RSA_KEY_SIZE`: The size of the RSA encryption keys (default: `2048`)
- `RENEWAL_INTERVAL`: Time interval between certbot's [renewal checks][renewal-check-interval] (default: `8d`)
- `DEBUG`: Set to `1` to enable debug messages and use the [`nginx-debug`][10] binary (default: `0`).


## Volumes
- `/etc/letsencrypt`: Stores the obtained certificates and the Diffie-Hellman parameters


## Run with `docker run`
Create your own [`user_conf.d/`][the-user_conf.d-folder] folder and place all
of you custom server config files in there. When done you can just start the
container with the following command:

```bash
docker run -it -p 80:80 -p 443:443 \
           --env CERTBOT_EMAIL=your@email.org \
           -v $(pwd)/nginx_secrets:/etc/letsencrypt \
           -v $(pwd)/user_conf.d:/etc/nginx/user_conf.d:ro \
           --name nginx-certbot jonasal/nginx-certbot:latest
```

> You should be able to detach from the container by holding `Ctrl` and pressing
  `p` + `q` after each other.

As was mentioned in the introduction; the very first time this container is
started it might take a long time before before it is ready to
[respond to requests][diffie-hellman-parameters], please be a little bit
patient. If you change any of the config files after the container is ready,
you can just [send in a `SIGHUP`][manualforce-renewal] to tell my scripts and
Nginx to reload everything.

```bash
docker kill --signal=HUP <container_name>
```


## Run with `docker-compose`
An example of a `docker-compose.yaml` file can be found in the
[`examples/`](./examples) folder. The default parameters that are found inside
the `nginx-certbot.env` file will be overwritten by any environment variables
you set inside the `.yaml` file.

Like in the example above, you just need to place your custom server configs
inside your [`user_conf.d/`][the-user_conf.d-folder] folder beforehand. Then
you start it all with the following command.

```bash
docker-compose up
```


## Build It Yourself
This option is for if you make your own `Dockerfile`. Check out which tags that
are available on Docker Hub under [`jonasal/nginx-certbot`][8].

In this case it is possible to completely skip the
[`user_conf.d/`][the-user_conf.d-folder] folder, and write your files directly
into Nginx's `conf.d/` folder. This way you can replace the files I have built
[into the image](./src/nginx_conf.d) with your own. However, if you do that
please take a moment to understand what they do, and what you need to include
in order for certbot to continue working.

```Dockerfile
FROM jonasal/nginx-certbot:latest
COPY conf.d/* /etc/nginx/conf.d/
```



# More Resources

### Good to Know
[Document][good-to-know] with a lot of good to know stuff about this image.

### Changelog
[Document][changelog] with all the tagged versions of this repository, as well as
bullet points to what has changed between the releases.






[good-to-know]: https://github.com/JonasAlfredsson/docker-nginx-certbot/tree/master/docs/good_to_know.md
[diffie-hellman-parameters]: https://github.com/JonasAlfredsson/docker-nginx-certbot/tree/master/docs/good_to_know.md#diffie-hellman-parameters
[help-migrating-from-staticfloats-image]: https://github.com/JonasAlfredsson/docker-nginx-certbot/tree/master/docs/good_to_know.md#help-migrating-from-staticfloats-image
[how-the-script-add-domain-names-to-certificate-requests]: https://github.com/JonasAlfredsson/docker-nginx-certbot/tree/master/docs/good_to_know.md#how-the-script-add-domain-names-to-certificate-requests
[manualforce-renewal]: https://github.com/JonasAlfredsson/docker-nginx-certbot/tree/master/docs/good_to_know.md#manualforce-renewal
[renewal-check-interval]: https://github.com/JonasAlfredsson/docker-nginx-certbot/tree/master/docs/good_to_know.md#renewal-check-interval
[initial-testing]: https://github.com/JonasAlfredsson/docker-nginx-certbot/tree/master/docs/good_to_know.md#initial-testing
[the-user_conf.d-folder]: https://github.com/JonasAlfredsson/docker-nginx-certbot/tree/master/docs/good_to_know.md#the-user_conf.d-folder
[changelog]: https://github.com/JonasAlfredsson/docker-nginx-certbot/tree/master/docs/changelog.md

[1]: https://letsencrypt.org/
[2]: https://github.com/certbot/certbot
[3]: https://letsencrypt.org/donate/
[4]: https://github.com/henridwyer/docker-letsencrypt-cron
[5]: https://github.com/staticfloat/docker-nginx-certbot
[6]: https://github.com/JonasAlfredsson/docker-nginx-certbot/commit/43dde6ec24f399fe49729b28ba4892665e3d7078
[7]: https://github.com/nginxinc/docker-nginx/tree/master/entrypoint
[8]: https://hub.docker.com/r/jonasal/nginx-certbot/tags?page=1&ordering=last_updated
[9]: https://github.com/nginxinc/docker-nginx
[10]: https://github.com/docker-library/docs/tree/master/nginx#running-nginx-in-debug-mode
[11]: https://docs.docker.com/engine/install/
[12]: https://www.duckdns.org/
[13]: https://portforward.com/router.htm
