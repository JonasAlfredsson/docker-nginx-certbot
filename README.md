# docker-nginx-certbot

Automatically create and renew website SSL certificates using the
[Let's Encrypt][1] free certificate authority and its client [*certbot*][2].
Built on top of the [official Nginx Docker images][9] (both Debian and Alpine),
and uses OpenSSL/LibreSSL to automatically create the Diffie-Hellman parameters
used during the initial handshake of some ciphers.

> :information_source: The very first time this container is started it might
  take a long time before before it is ready to respond to requests. Read more
  about this in the
  [Diffie-Hellman parameters](./docs/good_to_know.md#diffie-hellman-parameters)
  section.

> :information_source: Please use a [specific tag](./docs/dockerhub_tags.md)
  when doing a Docker pull, since `:latest` might not always be 100% stable.

### Noteworthy Features
- Handles multiple server names when [requesting certificates](./docs/good_to_know.md#how-the-script-add-domain-names-to-certificate-requests) (i.e. both `example.com` and `www.example.com`).
- Handles wildcard domain request in case you use [DNS authentication](./docs/certbot_authenticators.md).
- Can request both [RSA and ECDSA](./docs/good_to_know.md#ecdsa-and-rsa-certificates) certificates ([at the same time](./docs/advanced_usage.md#multi-certificate-setup)).
- Will create [Diffie-Hellman parameters](./docs/good_to_know.md#diffie-hellman-parameters) if they are defined.
- Uses the [parent container][9]'s [`/docker-entrypoint.d/`][7] folder.
- Will report correct [exit code][6] when stopped/killed/failed.
- You can do a live reload of configs by [sending in a `SIGHUP`](./docs/advanced_usage.md#manualforce-renewal) signal (no container restart needed).
- Possibility to use this image **offline** with the help of a [local CA](./docs/advanced_usage.md#local-ca).
- Both [Debian and Alpine](./docs/dockerhub_tags.md) images built for [multiple architectures][14].



# Acknowledgments and Thanks

This container requests SSL certificates from [Let's Encrypt][1], with the help
of their [*certbot*][2] script, which they provide for the absolutely bargain
price of free! If you like what they do, please [donate][3].

This repository was originally forked from [`@henridwyer`][4] by
[`@staticfloat`][5], before it was forked again by me. However, the changes to
the code has since become so significant that this has now been detached as its
own independent repository (while still retaining all the history). Migration
instructions, from `@staticfloat`'s image, can be found
[here](./docs/good_to_know.md#help-migrating-from-staticfloats-image).



# Usage

## Before You Start
1. This guide expects you to already own a domain which points at the correct
   IP address, and that you have both port `80` and `443` correctly forwarded
   if you are behind NAT. Otherwise I recommend [DuckDNS][12] as a Dynamic DNS
   provider, and then either search on how to port forward on your router or
   maybe find it [here][13].

2. I suggest you read at least the first two sections in the
   [Good to Know](./docs/good_to_know.md) documentation, since this will give
   you some important tips on how to create a basic server config, and how to
   use the Let's Encrypt staging servers in order to not get rate limited.

3. I don't think it is necessary to mention if you managed to find this
   repository, but you will need to have [Docker][11] installed for this to
   function.


## Available Environment Variables

### Required
- `CERTBOT_EMAIL`: Your e-mail address. Used by Let's Encrypt to contact you in case of security issues.

### Optional
- `DHPARAM_SIZE`: The size of the [Diffie-Hellman parameters](./docs/good_to_know.md#diffie-hellman-parameters) (default: `2048`)
- `ELLIPTIC_CURVE`: The size/[curve][15] of the ECDSA keys (default: `secp256r1`)
- `RENEWAL_INTERVAL`: Time interval between certbot's [renewal checks](./docs/good_to_know.md#renewal-check-interval) (default: `8d`)
- `RSA_KEY_SIZE`: The size of the RSA encryption keys (default: `2048`)
- `STAGING`: Set to `1` to use Let's Encrypt's [staging servers](./docs/good_to_know.md#initial-testing) (default: `0`)
- `USE_ECDSA`: Set to `0` to have certbot use [RSA instead of ECDSA](./docs/good_to_know.md#ecdsa-and-rsa-certificates) (default: `1`)

### Advanced
- `CERTBOT_AUTHENTICATOR`: The [authenticator plugin](./docs/certbot_authenticators.md) to use when responding to challenges (default: `webroot`)
- `CERTBOT_DNS_PROPAGATION_SECONDS`: The number of seconds to wait for the DNS challenge to [propagate](.docs/certbot_authenticators.md#troubleshooting-tips) (default: certbot's default)
- `DEBUG`: Set to `1` to enable debug messages and use the [`nginx-debug`][10] binary (default: `0`)
- `USE_LOCAL_CA`: Set to `1` to enable the use of a [local certificate authority](./docs/advanced_usage.md#local-ca) (default: `0`)


## Volumes
- `/etc/letsencrypt`: Stores the obtained certificates and the Diffie-Hellman parameters


## Run with `docker run`
Create your own [`user_conf.d/`](./docs/good_to_know.md#the-user_confd-folder)
folder and place all of you custom server config files in there. When done you
can just start the container with the following command
([available tags](./docs/dockerhub_tags.md)):

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
[respond to requests](./docs/good_to_know.md#diffie-hellman-parameters), please
be a little bit patient. If you change any of the config files after the
container is ready, you can just
[send in a `SIGHUP`](./docs/advanced_usage.md#manualforce-renewal) to tell
the scripts and Nginx to reload everything.

```bash
docker kill --signal=HUP <container_name>
```


## Run with `docker-compose`
An example of a [`docker-compose.yaml`](./examples/docker-compose.yml) file can
be found in the [`examples/`](./examples) folder. The default parameters that
are found inside the [`nginx-certbot.env`](./examples/nginx-certbot.env) file
will be overwritten by any environment variables you set inside the `.yaml`
file.

> NOTE: You can use both `environment:` and `env_file:` together or only one
        of them, the only requirement is that `CERTBOT_EMAIL` is defined
        somewhere.

Like in the example above, you just need to place your custom server configs
inside your [`user_conf.d/`](./docs/good_to_know.md#the-user_confd-folder)
folder beforehand. Then you start it all with the following command.

```bash
docker-compose up
```


## Build It Yourself
This option is for if you make your own `Dockerfile`. Check out which tags that
are available in [this document](./docs/dockerhub_tags.md), or on
[Docker Hub][8], and then choose how specific you want to be.

In this case it is possible to completely skip the
[`user_conf.d/`](./docs/good_to_know.md#the-user_confd-folder) folder and just
write your files directly into Nginx's `conf.d/` folder. This way you can
replace the files I have built [into the image](./src/nginx_conf.d) with your
own. However, if you do that please take a moment to understand what they do,
and what you need to include in order for certbot to continue working.

```Dockerfile
FROM jonasal/nginx-certbot:latest
COPY conf.d/* /etc/nginx/conf.d/
```



# Tests
We make use of [BATS][16] to test parts of this codebase. The easiest way to
run all the tests is to execute the following command in the root of this
repository:

```bash
docker run -it --rm -v "$(pwd):/workdir" ffurrer/bats:latest ./tests
```

> NOTE: This image used here is based on `alpine` which makes use of busybox
        `sort` instead of the coreutils one, and the default sorting order
        handles `*` differently, so the tests might thus fail if run on
        something else.



# More Resources
Here is a collection of links to other resources that provide useful
information.

- [Good to Know](./docs/good_to_know.md)
  - A lot of good to know stuff about this image and the features it provides.
- [Changelog](./docs/changelog.md)
  - List of all the tagged versions of this repository, as well as bullet points to what has changed between the releases.
- [DockerHub Tags](./docs/dockerhub_tags.md)
  - All the tags available from Docker Hub.
- [Advanced Usage](./docs/advanced_usage.md)
  - Information about the more advanced features this image provides.
- [Certbot Authenticators](./docs/certbot_authenticators.md)
  - Information on the different authenticators that are available in this image.
- [Nginx Tips](./docs/nginx_tips.md)
  - Some interesting tips on how Nginx can be configured.



# External Guides
Here is a list of projects that use this image in various creative ways. Take
a look and see if one of these helps or inspires you to do something similar:

- [A `Node.js` application served over HTTPS in AWS Elastic Beanstalk](https://efraim-rodrigues.medium.com/using-docker-to-containerize-your-node-js-aefcd1ecd37d)






[1]: https://letsencrypt.org/
[2]: https://github.com/certbot/certbot
[3]: https://letsencrypt.org/donate/
[4]: https://github.com/henridwyer/docker-letsencrypt-cron
[5]: https://github.com/staticfloat/docker-nginx-certbot
[6]: https://github.com/JonasAlfredsson/docker-nginx-certbot/commit/43dde6ec24f399fe49729b28ba4892665e3d7078
[7]: https://github.com/nginxinc/docker-nginx/tree/master/entrypoint
[8]: https://hub.docker.com/r/jonasal/nginx-certbot
[9]: https://github.com/nginxinc/docker-nginx
[10]: https://github.com/docker-library/docs/tree/master/nginx#running-nginx-in-debug-mode
[11]: https://docs.docker.com/engine/install/
[12]: https://www.duckdns.org/
[13]: https://portforward.com/router.htm
[14]: https://github.com/JonasAlfredsson/docker-nginx-certbot/issues/28
[15]: https://security.stackexchange.com/a/104991
[16]: https://github.com/bats-core/bats-core
