# Advanced Usage

This document contains information about features that are deemed "advanced",
and will most likely require that you read some of the actual code to fully
understand what is happening.

## Signal handling

The container configures handlers for the following signals:

 - `SIGINT`, `SIGQUIT`, `SIGTERM` - Shutdown the child processes (nginx and the
   [sleep timer](./good_to_know.md#renewal-check-interval)) and exit the
   container.
 - `SIGHUP` - Rerun [`run_certbot.sh`](../src/scripts/run_certbot.sh) and tell
   nginx to test and reload the configuration files (i.e. `nginx -t` followed
   by `nginx -s reload`). See [Manual/Force Renewal](#manualforce-renewal),
   [Controlling NGINX][20], and [Changing configuration][21] for more details.
 - `SIGUSR1` - Tell nginx to reopen log files (i.e. `nginx -s reopen`). See
   [Controlling NGINX][20] and [Rotating Log-files][22] for more details.

Signals can be sent to the container by using the `docker kill` command (or
`docker compose kill` when using Docker Compose). For example, to send a
`SIGHUP` signal to the container run:

```bash
docker kill --signal=HUP <container_name>
```

## Manual/Force Renewal
It might be of interest to manually trigger a renewal of the certificates, and
that is why the [`run_certbot.sh`](../src/scripts/run_certbot.sh) script is
possible to run standalone at any time from within the container.

However, the preferred way of requesting a reload of all the configuration files
is to send in a [`SIGHUP`][1] to the container:

```bash
docker kill --signal=HUP <container_name>
```

This will terminate the [sleep timer](./good_to_know.md#renewal-check-interval)
and make the renewal loop start again from the beginning, which includes a lot
of other checks than just the certificates.

While this will be enough in the majority of the cases, it might sometimes be
necessary to **force** a renewal of the certificates even though certbot thinks
it could keep them for a while longer (like when [this][2] happened). It is
therefore possible to add "force" as an argument, when calling the
[`run_certbot.sh`](../src/scripts/run_certbot.sh) script, to have it append
the `--force-renewal` flag to the requests made.

```bash
docker exec -it <container_name> /scripts/run_certbot.sh force
```

This will request new certificates regardless of when they are set to expire.

> :warning: Using "force" will make new requests for **all** you certificates,
  so don't run it too often since there are some limits to requesting
  [production certificates][3].


## Override `server_name`
Nginx allows you to to do a lot of stuff in the [`server_name` declaration][18],
but since the scripts inside this image compose certificate requests from the
same lines we are severely limited in what is possible to define on those lines.
For example the line `server_name mail.*` would produce a certificate request
for the domain name `mail.*`, which is not valid.

However, to combat this limitation it is possible to define a special comment
on the same line in order to override what the scripts will pick up. So in this
contrived example

```bash
server {
    listen              443 ssl;
    ssl_certificate_key /etc/letsencrypt/live/test-name/privkey.pem;

    server_name         yourdomain.org;
    server_name         www.yourdomain.org; # certbot_domain:*.yourdomain.org
    server_name         sub.yourdomain.org; # certbot_domain:*.yourdomain.org
    server_name         mail.*;             # certbot_domain:*.yourdomain.org
    server_name         ~^(?<user>.+)\.yourdomain\.org$;
    ...
}
```

we will end up with a certificate request which looks like this:

```
certbot --cert-name "test-name" ... -d yourdomain.org -d *.yourdomain.org
```

The fist server name will be picked up as usual, while the following three will
be shadowed by the domain in the comment, i.e. `*.yourdomain.org` (and duplicate
names will be removed in the final request).

The last server name is special, in that it is a regex and those always start
with a `~`. Since we know we will never be able to create a valid request from
a name which start with that character they will always be ignored by the
script (a trailing comment will take precedence instead of being ignored).
A more detailed example of this can be viewed in
[`example_server_overrides.conf`](../examples/example_server_overrides.conf).

Important to remember is that here we define a wildcard domain name (the `*`
in the the `*.yourdomain.org`), and that requires you to use an authenticator
capable of DNS-01 challenges, and more info about that may be found in the
[certbot_authenticators.md](./certbot_authenticators.md) document.


## Multi-Certificate Setup
This is a continuation of the
[RSA and ECDSA](./good_to_know.md#ecdsa-and-rsa-certificates) section from
the [Good to Know](./good_to_know.md) document, where it was briefly mentioned
that it is actually possible to have Nginx serve both of these certificate
types at the same time, thus expanding support for semi-old devices again while
also allowing the most up to date encryption to be used. [The setup][4] is a
bit more complicated, but the
[`example_server_multicert.conf`](../examples/example_server_multicert.conf)
file should be configured so you should only have to edit the "yourdomain.org"
statements at the top.

How this works is that Nginx is able to [load multiple certificate files][5]
for each server block, and you then configure the cipher suites in an order
that prefers ECDSA certificates. The [scripts](../src/scripts/run_certbot.sh)
running inside the container then looks for some (case insensitive) variant of
these strings in the
[`--cert-name`](./good_to_know.md#how-the-script-add-domain-names-to-certificate-requests)
argument:

- `-rsa`
- `.rsa`
- `-ecc`
- `.ecc`
- `-ecdsa`
- `.ecdsa`

and makes a certificate request with the correct type set. See the
[actual commit][6] for more details, but what you need to know is that if
these options are found they override the [`USE_ECDSA`](../README.md#optional)
environment variable.


## Use Custom ACME URL
There are two variables available at the top of the
[`run_certbot.sh`](../src/scripts/run_certbot.sh) script:

- `CERTBOT_PRODUCTION_URL`
- `CERTBOT_STAGING_URL`

which are used to define which server certbot will try to contact when
requesting new certificates. These variables have default values, but it is
possible to override them by defining environment vairables with the same name.
This then enables you to redirect certbot to another custom URL if you, for
example, are running your own custom ACME server.


## Local CA
During the development phase of a website you might be testing stuff on a
computer that either does not have a DNS record pointing to itself or perhaps
it does not have internet access at all. Since certbot has both of these as
requirements to function properly it was previously impossible to use this
image during those particular situations.

That is why the [`run_local_ca.sh`](../src/scripts/run_local_ca.sh) script was
created, since this makes it possible to use a
[local (self-signed) certificate authority][10] that can issue website
certificates without relying on any external service or internet connection.
It also enables us to issue certificates that are valid for `localhost` and/or
IP addresses like `::1`, which are otherwise [impossible][7] for certbot to
create.

> You can also use this solution if your intend to deploy behind a CDN and you
> do not need a "real" certificate in order to encrypt the communication
> between the origin server and the CDN's infrastructure. But please read
> this entire section before going forward with that kind of setup.

To enable the usage of this local CA you just set
[`USE_LOCAL_CA=1`](../README.md#advanced), and this will then trigger the
execution of the [`run_local_ca.sh`](../src/scripts/run_local_ca.sh) script
instead of the [`run_certbot.sh`](../src/scripts/run_certbot.sh) one when it is
time to renew the certificates. This script, when run, will always overwrite
any previous keys and certificates, so alternating between the use of a local
CA and certbot without first emptying the `/etc/letsencrypt` folder is **not**
supported.

The script is designed to mimic certbot as closely as reasonable, so the
keys/certs created are placed in the same locations as certbot would have. This
means that you only have to edit the `server_name` in your server configuration
files to include the variant that you want for your local instance (e.g.
`localhost`) and you should be all set.

However, if you navigate to your site at this point you will run into an error
named similar to Firefox's `SEC_ERROR_UNKNOWN_ISSUER`, which just means that
your browser does not recognize the CA that has signed your site's certificate.
This is expected (since we just created our own local CA), but at this point
the connection is using all the fancy HTTPS stuff, and is thus "secure", so you
can just ignore this warning if you want.

Another solution is to [import][9] the local CA's certificate created by this
script into your browser, thus making this a known certificate authority and
any of its signed certs trusted. What this file is, and how to obtain it, is
explained further in the [next section](#files-and-folders).


### Files and Folders
For the local CA to operate a couple of things are needed:

- `caPrivkey.pem`: The private key used by the CA -> this is the most secret
                   thing that (in a real CA's case) must be protected at all
                   costs.
- `caCert.pem`: The public certificate part of the CA -> needed by all clients
                in order to trust any other certificates this CA signs.
- `serial.txt`: A long random hexadecimal number that is incremented by one
                every time a new certificate is signed by the CA.
- `index.txt`: Keeps a [record][8] of all certificates that have been issued
               by this CA.
- `new_certs/`: Folder where a copy of all the newly signed certificates are
                placed.

All of these are created automatically by the script inside the folder defined
by [`LOCAL_CA_DIR`](../src/scripts/run_local_ca.sh) (which defaults to
`/etc/local_ca`), so by host mounting this folder you will be able to see all
these files. By then taking the `caCert.pem` and [importing][9] it in your
browser you will be able to visit these sites without the error stating that
the certificate is signed by an unknown authority.

An important thing to know is that these files are only created if they do
not exist. What this enables is an even more advanced usecase where you might
already have a private key and certificate that you trust on your devices, and
you would like to continue using it for the websites you host as well. Read
more about this in the [next section](#creating-a-custom-ca).


### Creating a Custom CA
The validity period for the automatically created CA is only 30 days by
default, and the reason for this is to deter people from using this solution
blindly in production. While it is possible to quickly change this through the
`LOCAL_CA_ROOT_CERT_VALIDITY` variable, there are security concerns regarding
managing your own certificate authority which should be thought through before
doing this in a production environment.

Nevertheless, as was mentioned in the previous section it is possible to supply
the [`run_local_ca.sh`](../src/scripts/run_local_ca.sh) script with a local
certificate authority that has been created manually by you that you want to
trust on multiple other devices.
Basically all you need to do is to host mount your custom private key and
certificate to the `LOCAL_CA_DIR`, and the script will use these instead of
the short lived automatically created ones. Just make sure the files are named
in accordance to [what the script expects](#files-and-folders), and if any one
of these components are missing they will be created the first time the service
is started.

> As of now a password protected private key is not supported.

I did not find it trivial to create a **well configured** CA, so if you want
to go this route I really suggest that you read up on what you are doing and
making sure all settings are correctly tuned for your usecase.

There is a [lot][11] of [high-level][12] information [available][13] in regards
to how to create your own CA, but what I found most confusing was exactly what
was expected to be inside the [`openssl.cnf`][14] file that is necessary to
have when running most of the OpenSSL commands. The configuration that is
present inside the [`run_local_ca.sh`](../src/scripts/run_local_ca.sh) script
should be quite minimalistic for what we need, while still providing the
[strict settings][15] that some clients need else they will reject these
custom certificates.

The most comprehensive guide I have found is the [OpenSSL Cookbook][17],
which goes into great detail about basically everything OpenSSL is able to do,
along with [this post][16] which summarizes the settings needed for different
certificate types. With these two you should be able to make an informed
configuration in case you want to create your own custom certificate authority,
and you may of course take a look at the commands used in the
[`generate_ca()`](../src/scripts/run_local_ca.sh) function to help you on your
way of creating your own files.

When the long term CA is in place you can probably tune the `RENEWAL_INTERVAL`
variable to equal something slightly less than the hard-coded `90d` expiry
time of the leaf certificates created. This is the expiry time recommended by
Let's Encrypt (and perhaps [soon mandated][19]), and since the renewal script
_should_ always be successful you only need to run it just before the expiry
time. You can, of course, run it more often than that, but it will not yield
and special benefits.






[1]: https://github.com/JonasAlfredsson/docker-nginx-certbot/commit/bf2c1354f55adffadc13b1f1792e205f9dd25f86
[2]: https://community.letsencrypt.org/t/revoking-certain-certificates-on-march-4/114864
[3]: https://letsencrypt.org/docs/rate-limits/
[4]: https://medium.com/hackernoon/rsa-and-ecdsa-hybrid-nginx-setup-with-letsencrypt-certificates-ee422695d7d3
[5]: https://scotthelme.co.uk/hybrid-rsa-and-ecdsa-certificates-with-nginx/
[6]: https://github.com/JonasAlfredsson/docker-nginx-certbot/commit/9195bf02cb200dcec8206b46da971734b1d6669f
[7]: https://letsencrypt.org/docs/certificates-for-localhost/
[8]: https://pki-tutorial.readthedocs.io/en/latest/cadb.html
[9]: https://support.securly.com/hc/en-us/articles/360008547993-How-to-Install-Securly-s-SSL-Certificate-in-Firefox-on-Windows
[10]: https://gist.github.com/Soarez/9688998
[11]: https://gist.github.com/fntlnz/cf14feb5a46b2eda428e000157447309
[12]: https://github.com/llekn/openssl-ca
[13]: https://jamielinux.com/docs/openssl-certificate-authority/create-the-root-pair.html
[14]: https://github.com/llekn/openssl-ca/blob/master/openssl.cnf
[15]: https://derflounder.wordpress.com/2019/06/06/new-tls-security-requirements-for-ios-13-and-macos-catalina-10-15/
[16]: https://superuser.com/questions/738612/openssl-ca-keyusage-extension/1248085#1248085
[17]: https://www.feistyduck.com/library/openssl-cookbook/online/ch-openssl.html
[18]: https://nginx.org/en/docs/http/server_names.html
[19]: https://www.globalsign.com/en-ae/blog/google-90-day-certificate-validity-requires-automation
[20]: https://docs.nginx.com/nginx/admin-guide/basic-functionality/runtime-control/#controlling-nginx
[21]: https://nginx.org/en/docs/control.html#reconfiguration
[22]: https://nginx.org/en/docs/control.html#logs
