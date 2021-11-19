# Wildcard Certificates

The certbot script will automatically request a certificate for each conf file that references one using the domains in `server_name`. To use a single wildcard cert with [DNS validation](certbot_authenticators.md) instead, set up a default site as usual, then create an _include file_ with the same cert that can be used for the subdomains (using the same `ssl_certificate_key` in two conf files will cause the cert to be overwritten with different domains; see [#91](https://github.com/JonasAlfredsson/docker-nginx-certbot/issues/91)).

For example, with /etc/nginx/includes mounted to a folder on the host in additon to user_conf.d:

**/etc/nginx/user_conf.d/default.conf**

```nginx
server {
  # Listen to port 443 on both IPv4 and IPv6.
  listen 443 ssl default_server reuseport;
  listen [::]:443 ssl default_server reuseport;

  # Domain names this server should respond to.
  server_name example.com *.example.com;

  # Load the certificate files.
  ssl_certificate         /etc/letsencrypt/live/default/fullchain.pem;
  ssl_certificate_key     /etc/letsencrypt/live/default/privkey.pem;
  ssl_trusted_certificate /etc/letsencrypt/live/default/chain.pem;

  # Load the Diffie-Hellman parameter.
  ssl_dhparam /etc/letsencrypt/dhparams/dhparam.pem;

  # Reject the request (alternatively, `return 444;` to trigger ERR_EMPTY_RESPONSE but with valid SSL)
  # https://github.com/JonasAlfredsson/docker-nginx-certbot/blob/master/docs/nginx_tips.md#reject-unknown-server-name
  ssl_reject_handshake on;
}
```

**/etc/nginx/includes/ssl**

```nginx
listen 443;

# Load the certificate files.
ssl_certificate         /etc/letsencrypt/live/default/fullchain.pem;
ssl_certificate_key     /etc/letsencrypt/live/default/privkey.pem;
ssl_trusted_certificate /etc/letsencrypt/live/default/chain.pem;

# Load the Diffie-Hellman parameter.
ssl_dhparam /etc/letsencrypt/dhparams/dhparam.pem;
```

**/etc/nginx/user_conf.d/foo.conf**

```nginx
server {
  include includes/ssl;

  server_name foo.example.com;

  return 200 "Hello";
  add_header Content-Type text/plain;
}
```
