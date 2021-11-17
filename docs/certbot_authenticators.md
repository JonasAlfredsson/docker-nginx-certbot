# Certbot Authenticators

Certbot allows to use a number of [authenticators to get certificates][1]. By default, and this will be sufficient for most users, this container uses the [webroot authenticator][2], which will provision certificates for your domain names by doing what we call [HTTP-01 validation][3], where we prove ownership of the domain name by serving a specific content at a given URL.

Among the other authenticators available to certbot, the [DNS authenticators][4] are also available through this container. DNS authenticators allow to prove ownership of a domain name by serving a challenge directly through a TXT record, added in your DNS provider, which is called [DNS-01][5]. As these challenges are a stronger proof of ownership than using HTTP-01, they also allow to provision wildcard certificates, that cover a whole subdomain layer of your domain (e.g. `*.example.com` covers `<anything>.example.com`, where `<anything>` can be... well... anything that is valid for DNS).


## Setting up the container to use DNS-01 challenges

To use DNS-01 challenges, you will need to create the credentials file for the chosen authenticator.

You can find information about how to configure them by following those links for the supported authenticators:
 - [dns-cloudflare][6]
 - [dns-cloudxns][7]
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

You will need to setup the authenticator file at `/etc/letsencrypt/<authenticator provider>.ini`.
E.g. for Cloudflare, we would create the file `/etc/letsencrypt/cloudflare.ini` with the following content:

```ini
# Cloudflare API token used by Certbot
dns_cloudflare_api_token = 0123456789abcdef0123456789abcdef01234567
```


## Using a DNS-01 authenticator by default

You can use an authenticator solving DNS-01 challenges by default by setting the `CERTBOT_AUTHENTICATOR` environment variable in your docker configuration with for value the name of the authenticator you wish to use (e.g. `dns-cloudflare`).

All the certificates needing renewal or creation will then start using that authenticator. Make sure, of course, that you've setup the authenticator correctly, as described above.


## Using a DNS-01 authenticator for specific certificates only

You might want to keep using the `webroot` authenticator in most cases, but need to use a DNS-01 challenge to setup a wildcard certificate for a given domain. Or you might even have a domain setup on Route53 while your other domains are on Cloudflare, and you thus are using `dns-cloudflare` as default authenticator.

In such cases, you can specify the authenticator you wish to use in the certificate path that you are setting up as `ssl_certificate_key` in your server block of the nginx configuration. In our case, if we want to use `dns-route53` for a specific certificate, we could be using the following:

```
server {
    listen              443 ssl;
    server_name         yourdomain.org *.yourdomain.org;
    ssl_certificate_key /etc/letsencrypt/live/test-name.dns-route53/privkey.pem;
    ...
}
```

The script ran in the container to renew certificates will automatically identify that it needs to use the Route53 authenticator here. Of course, you will need that authenticator to be configured properly in order to be able to use it. This setting is also compatible with the [multi-certificate setup](./advanced_usage.md#multi-certificate-setup).

## DNS-01 challenges are failing even though I can see the challenges setup in my provider's configuration

DNS propagation is usually quite fast, but depends a lot on caching. This means that if Let's Encrypt tried to read the challenge recently, it might still hit a cache returning an older value of the TXT record that was added by certbot.

If this happens often to you, you can set the `CERTBOT_DNS_PROPAGATION_SECONDS` environment variable in your docker configuration, to increase the time to wait for DNS propagation to happen.

When that environment variable is not set, certbot will use a default value, which can be found in the documentation of the authenticator of your chosing. At the time of writing, this default value is of 10 seconds for all of the DNS authenticators.




[1]: https://eff-certbot.readthedocs.io/en/stable/using.html#id8
[2]: https://eff-certbot.readthedocs.io/en/stable/using.html#webroot
[3]: https://letsencrypt.org/docs/challenge-types/#http-01-challenge
[4]: https://eff-certbot.readthedocs.io/en/stable/using.html#dns-plugins
[5]: https://letsencrypt.org/docs/challenge-types/#dns-01-challenge
[6]: https://certbot-dns-cloudflare.readthedocs.io/en/stable/#credentials
[7]: https://certbot-dns-cloudxns.readthedocs.io/en/stable/#credentials
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

