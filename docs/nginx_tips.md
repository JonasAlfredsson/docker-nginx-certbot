# Nginx Tips

This docuemnt contains some tips on how Nginx can be modified in some different
ways that might be of interest. None of these are required to do, but are more
of nice to know information that I found useful to write down for any potential
future endeavor.


## How Nginx Loads Configs
To understand how Nginx loads any custom configurations we first have to take
a look on the main `nginx.conf` file from the parent image. It has a couple of
standard settings included, but on the last line we can se that it opens the
`/etc/nginx/conf.d/` folder and loads any file that ends with `.conf`.

```conf
user  nginx;
worker_processes  auto;

error_log  /var/log/nginx/error.log notice;
pid        /var/run/nginx.pid;

events {
    worker_connections  1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile        on;
    #tcp_nopush     on;

    keepalive_timeout  65;

    #gzip  on;

    include /etc/nginx/conf.d/*.conf;    # <------------ Extra stuff loaded here
}
```

Files in this folder are being loaded in alphabetical order, so something named
`00-proxy.conf` will be loaded before `10-other.conf`. This i really useful to
know, since it allows you to load common settings used by multiple `server`
blocks that are loaded afterwards.

However, all of these `.conf` file are loaded within the `http` block in Nginx,
so if you want to change anything outside of this block (e.g. `events`) you
will have to add some sort of [`/docker-entrypoint.d/`][7] script to handle it
before Nginx starts, or you can mount your own custom `nginx.conf` on top of
the default.

A small disclaimer on the last part is that a host mounted file
(`-v $(pwd)/nginx.conf:/etc/nginx/nginx.conf`) will [not change][8] inside the
container if it is changed on the host. However, if you host mount a directory,
and change any of the files within it, the changes will be visible inside the
container.


## Reject Unknown Server Name
When setting up server blocks there exist a setting called `default_server`,
which means that Nginx will use this server block in case it cannot match
the incoming domain name with any of the other `server_name`s in its available
config files. However, a less known fact is that if you do not specify a
`default_server` Nginx will automatically use the [first server block][1] in
its configuration files as the default server.

This might cause confusion as Nginx could now "accidentally" serve a
completely wrong site without the user knowing it. Luckily HTTPS removes some
of this worry, since the browser will most likely throw an
`SSL_ERROR_BAD_CERT_DOMAIN` if the returned certificate is not valid for the
domain that the browser expected to visit. But if the cert is valid for that
domain as well, then there will be problems.

If you want to guard yourself against this, and return an error in the case
that the client tries to connect with an unknown server name, you need to
configure a catch-all block that responds in the default case. This is simple
in the non-SSL case, where you can just return `444` which will terminate the
connection immediately.

```
server {
    listen      80 default_server;
    server_name _;
    return      444;
}
```

> NOTE: The [redirector.conf](../src/nginx_conf.d/redirector.conf) should be
        the `default_server` for port 80 in this image.

Unfortunately it is not as simple in the secure HTTPS case, since Nginx would
first need to perform the SSL handshake (which needs a valid certificate)
before it can respond with `444` and drop the connection. To work around this
I found a comment in [this][2] post which mentions that in version `>=1.19.4`
of Nginx you can actually use the [`ssl_reject_handshake`][3] feature to
achieve the same functionality.

```
server {
    listen               443 ssl default_server;
    ssl_reject_handshake on;
}
```

This will lead to an `SSL_ERROR_UNRECOGNIZED_NAME_ALERT` error in case the
client tries to connect over HTTPS to a server name that is not served by this
instance of Nginx, and the connection will be dropped immediately.


## Add Custom Module
Adding a [custom module][4] to Nginx is not enirely trivial, since most guides
I have found require you to re-complie everything with the desired module
included and thus you cannot make use of the official Docker image to build
upon. However, after some research I found that most of these modules are
possible to compile and load as a [dynamic module][5], which enables us to more
or less just add one file and then change one line in the main `nginx.conf`.

A complete example of how to do this is available over at
[AxisCommunications/docker-nginx-ldap][6], where a multi-stage Docker build
can be viewed that add the LDAP module to the official Nginx image with
minimal changes to the original.






[1]: https://nginx.org/en/docs/http/request_processing.html
[2]: https://serverfault.com/a/631073
[3]: https://nginx.org/en/docs/http/ngx_http_ssl_module.html#ssl_reject_handshake
[4]: https://www.nginx.com/resources/wiki/modules/
[5]: https://www.nginx.com/blog/compiling-dynamic-modules-nginx-plus/
[6]: https://github.com/AxisCommunications/docker-nginx-ldap
[7]: https://github.com/nginxinc/docker-nginx/tree/master/entrypoint
[8]: hhttps://medium.com/@jonsbun/why-need-to-be-careful-when-mounting-single-files-into-a-docker-container-4f929340834
