# Certbot Authenticators

Certbot allows to use a number of [authenticators to get certificates][1]. By
default, and this will be sufficient for most users, this container uses the
[webroot authenticator][2] which will provision certificates for your domain
names by doing what is called [HTTP-01 validation][3]. Here the ownership of the
domain name is proven by serving a specific content at a given URL, whcih means
that a limitation with this authenticator is that the Let's Encrypt servers
must be able to reach your server on port 80 for it to work. This is the reason
for the ".well-known" location in the
[`redirector.conf`](../src/nginx_conf.d/redirector.conf) file.

Among the other authenticators available to certbot, the [DNS authenticators][4]
are also available through this container. DNS authenticators allow you to prove
ownership of a domain name by serving a challenge directly through a TXT record
added in your DNS provider. This challenge is called [DNS-01][5] and is a
stronger proof of ownership than using HTTP-01, which is why this method also
allow wildcard certificates (e.g. `*.yourdomain.org`). Using the DNS autheicator
also means that the Let's Encrypt servers only has to perform DNS lookups and do
not need to connect directly to your server. This means that you can get a
"proper" certificate to a service that otherwise is only reachable on your own
LAN.


## Preparing the Container for DNS-01 Challenges

To use DNS-01 challenges, you will need to create the credentials file for the
chosen authenticator.

You can find information about how to configure them by following those links
for the supported authenticators:

 - [dns-cloudflare][6]
 - [dns-digitalocean][8]
 - [dns-dnsimple][9]
 - [dns-dnsmadeeasy][10]
 - [dns-gehirn][11]
 - [dns-google][12]
 - [dns-linode][13]
 - [dns-luadns][14]
 - [dns-nsone][15]
 - [dns-ovh][16]
 - [dns-rfc2136][17]
 - [dns-route53][18]
 - [dns-sakuracloud][19]
 - [dns-ionos][20]
 - [dns-bunny][21]
 - [dns-duckdns][22]
 - [dns-hetzner][23]
 - [dns-infomaniak][24]
 - [dns-namecheap][26]
 - [dns-godaddy][27]
 - [dns-gandi][25]
 - [dns-powerdns][28]

You will need to setup the authenticator file at
`$CERTBOT_DNS_CREDENTIALS_DIR/<authenticator provider>.ini`, where the
`$CERTBOT_DNS_CREDENTIALS_DIR` variable defaults to `/etc/letsencrypt`.
So for e.g. Cloudflare you would need the file `/etc/letsencrypt/cloudflare.ini`
with the following content:

```ini
# Cloudflare API token used by Certbot
dns_cloudflare_api_token = 0123456789abcdef0123456789abcdef01234567
```

It is also possible to define unique credentials files by including extra
information in the certificate path, read more about it
[below](#unique-credentials-files).


## Using a DNS-01 Authenticator by Default

You can use an authenticator solving DNS-01 challenges by default by setting the
`CERTBOT_AUTHENTICATOR` environment variable with the value as the name of the
authenticator you wish to use (e.g. `dns-cloudflare`).

All the certificates needing renewal or creation will then start using that
authenticator. Make sure, of course, that you've setup the authenticator
correctly, as described above.


## Using a DNS-01 Authenticator for Specific Certificates Only

You might want to keep using the `webroot` authenticator in most cases, but
need to use a DNS-01 challenge to setup a wildcard certificate for a given
domain. Or you might even have a domain set up on Route53 while your other
domains are on Cloudflare, and you thus are using `dns-cloudflare` as your
default authenticator.

In such cases, you can specify the authenticator you wish to use in the
certificate path that you are setting up as `ssl_certificate_key` in your
server block of the nginx configuration. In our case, if we want to use
`dns-route53` for a specific certificate, we could be using the following:

```
server {
    listen              443 ssl;
    server_name         yourdomain.org *.yourdomain.org;
    ssl_certificate_key /etc/letsencrypt/live/test-name.dns-route53/privkey.pem;
    ...
}
```

The script running in the container to renew certificates will automatically
identify that it needs to use the Route53 authenticator here. Of course, you
will need that authenticator to be configured properly in order to be able to
use it.

This setting is also compatible with the
[multi-certificate setup](./advanced_usage.md#multi-certificate-setup), so an
RSA certificate via Clouflare's authenticator can be specified like this:

```
ssl_certificate_key /etc/letsencrypt/live/test-name.dns-cloudflare.rsa/privkey.pem;
```

### Unique Credentials Files
An expansion on the unique DNS authenticator feature mentioned above is that
it is possible to add a suffix to it in order to use individual credentials
files for the same DNS provider. In the following example we have two config
files with the following content:

```
server {
    listen              443 ssl;
    server_name         first.org *.first.org;
    ssl_certificate_key /etc/letsencrypt/live/c2.dns-cloudflare_1/privkey.pem;
    ...
}
```

```
server {
    listen              443 ssl;
    server_name         second.org *.second.org;
    ssl_certificate_key /etc/letsencrypt/live/c1.dns-cloudflare_2/privkey.pem;
    ...
}
```

As you can see they both use the Cloudflare DNS authenticator, but the first
one will use the `/etc/letsencrypt/cloudflare_1.ini` credentials file while the
second one will use `/etc/letsencrypt/cloudflare_2.ini`. This allows us to have
multiple scoped credentials for the DNS, instead of a single one that can
control all domains.

The limit to this feature is that the suffix may not consist of an `.` or a `-`
since they are used as separators for other things.

## Troubleshooting Tips

DNS propagation is usually quite fast, but depends a lot on caching. This means
that if Let's Encrypt tried to read the challenge recently, it might still hit
a cache returning an older value of the TXT record that was added by certbot.

If this happens often to you, you can set the `CERTBOT_DNS_PROPAGATION_SECONDS`
environment variable in your docker configuration, to increase the time to wait
for DNS propagation to happen.

When that environment variable is not set, certbot will use a default value,
which can be found in the documentation of the authenticator of your choosing.
At the time of writing, this default value is of 10 seconds for all of the DNS
authenticators.




[1]: https://eff-certbot.readthedocs.io/en/stable/using.html#getting-certificates-and-choosing-plugins
[2]: https://eff-certbot.readthedocs.io/en/stable/using.html#webroot
[3]: https://letsencrypt.org/docs/challenge-types/#http-01-challenge
[4]: https://eff-certbot.readthedocs.io/en/stable/using.html#dns-plugins
[5]: https://letsencrypt.org/docs/challenge-types/#dns-01-challenge
[6]: https://certbot-dns-cloudflare.readthedocs.io/en/stable/#credentials
[8]: https://certbot-dns-digitalocean.readthedocs.io/en/stable/#credentials
[9]: https://certbot-dns-dnsimple.readthedocs.io/en/stable/#credentials
[10]: https://certbot-dns-dnsmadeeasy.readthedocs.io/en/stable/#credentials
[11]: https://certbot-dns-gehirn.readthedocs.io/en/stable/#credentials
[12]: https://certbot-dns-google.readthedocs.io/en/stable/#credentials
[13]: https://certbot-dns-linode.readthedocs.io/en/stable/#credentials
[14]: https://certbot-dns-luadns.readthedocs.io/en/stable/#credentials
[15]: https://certbot-dns-nsone.readthedocs.io/en/stable/#credentials
[16]: https://certbot-dns-ovh.readthedocs.io/en/stable/#credentials
[17]: https://certbot-dns-rfc2136.readthedocs.io/en/stable/#credentials
[18]: https://certbot-dns-route53.readthedocs.io/en/stable/#credentials
[19]: https://certbot-dns-sakuracloud.readthedocs.io/en/stable/#credentials
[20]: https://github.com/helgeerbe/certbot-dns-ionos
[21]: https://github.com/mwt/certbot-dns-bunny
[22]: https://github.com/infinityofspace/certbot_dns_duckdns?tab=readme-ov-file#usage
[23]: https://github.com/ctrlaltcoop/certbot-dns-hetzner?tab=readme-ov-file#credentials
[24]: https://github.com/Infomaniak/certbot-dns-infomaniak
[25]: https://github.com/obynio/certbot-plugin-gandi
[26]: https://github.com/knoxell/certbot-dns-namecheap?tab=readme-ov-file#credentials
[27]: https://github.com/miigotu/certbot-dns-godaddy?tab=readme-ov-file#credentials
[28]: https://github.com/pan-net-security/certbot-dns-powerdns 
