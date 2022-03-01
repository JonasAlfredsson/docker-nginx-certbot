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

```bash
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


## Configuration Inheritance
To keep this explanation simple, yet useful, we begin by stating that the Nginx
configuration is split into four blocks. Variables and settings declared in an
outer block (e.g. the Global block) will be inherited by an inner block (e.g.
the Server block) unless you change it inside this inner block.

So in the example below I have added comments with the current value of the
[`keepalive_timeout`][9] setting in each block:

```bash
# -- Global/main block --
# keepalive_timeout = 60 (The default value)
http {
    # -- HTTP block --
    keepalive_timeout = 30 # The value has now changed to 30
    server {
        # -- Server block --
        # keepalive_timeout = 30 (value inherited from http block)
        location /abc/ {
            # -- Location block nbr 1 --
            keepalive_timeout = 50 # The value has now changed to 50
        }
        location /xyz/ {
            # -- Location block nbr 2 --
            # keepalive_timeout = 30 (value inherited from server block)
        }
    }
}
```

This is pretty straight forward for the settings that are only one value, but
the commonly used [`proxy_set_header`][10] setting can be declared multiple
times in order to add multiple values to it, and [its inheritance][11] works a
bit differently. The following is true of all of the settings that can be
declared multiple times.

In the example below we want to add two headers to all requests, so we
declare them in the `http` block. This builds a map/dictionary with the
key-value pairs we want, and this will be inherited to all the location blocks.
However, in the first location block we want to **add** another header, but
doing it in this way will instead overwrite the current one with just this new
header.

```bash
http {
    proxy_set_header key1 value1;
    proxy_set_header key2 value2;
    server {
        # proxy_headers: {
        #     "key1": "value1"
        #     "key2": "value2"
        # }
        location /abc/ {
            proxy_set_header key3 value3;
            # proxy_headers: {
            #     "key3": "value3"
            # }
        }
        location /xyz/ {
            # proxy_headers: {
            #     "key1": "value1"
            #     "key2": "value2"
            # }
        }
    }
}
```

The suggested solution to this problem is to create a separate file with the
"common" headers, and then `include` this file where needed. So in our case we
create the file `/etc/nginx/common_headers` with the following content:

```
proxy_set_header key1 value1;
proxy_set_header key2 value2;
```

and then change the config to the following which would make the special
location block have all the desired headers:

```bash
http {
    include common_headers;
    server {
        location /abc/ {
            include common_headers;
            proxy_set_header key3 value3;
            # proxy_headers: {
            #     "key1": "value1"
            #     "key2": "value2"
            #     "key3": "value3"
            # }
        }
        location /xyz/ {
        }
    }
}
```


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
[9]: https://nginx.org/en/docs/http/ngx_http_upstream_module.html#keepalive_timeout
[10]: https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_set_header
[11]: https://stackoverflow.com/a/32126596
