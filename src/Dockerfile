FROM nginx:1.27.3
LABEL maintainer="Jonas Alfredsson <jonas.alfredsson@protonmail.com>"

ENV CERTBOT_DNS_AUTHENTICATORS="\
    cloudflare \
    digitalocean \
    dnsimple \
    dnsmadeeasy \
    gehirn \
    google \
    linode \
    luadns \
    nsone \
    ovh \
    rfc2136 \
    route53 \
    sakuracloud \
    ionos \
    bunny \
    duckdns \
    hetzner \
    "

# Needed in order to install Python packages via PIP after PEP 668 was
# introduced, but I believe this is safe since we are in a container without
# any real need to cater to other programs/environments.
ARG PIP_BREAK_SYSTEM_PACKAGES=1

# We need to do some platfrom specific workarounds in the build script, so bring
# this information in to the build environment.
ARG TARGETPLATFORM

# Through this we gain the ability to handle certbot upgrades through
# dependabot pull requests.
COPY requirements.txt /requirements.txt

# Do a single run command to make the intermediary containers smaller.
RUN set -ex && \
# Install packages necessary during the build phase (for all architectures).
    apt-get update && \
    apt-get install -y --no-install-recommends \
            build-essential \
            curl \
            libffi8 \
            libffi-dev \
            libssl-dev \
            openssl \
            pkg-config \
            procps \
            python3 \
            python3-dev \
    && \
# Install the latest version of rustc/cargo if we are in an architecture that
# needs to build the cryptography Python package.
    if echo "$TARGETPLATFORM" | grep -E -q '^(linux/386|linux/arm64|linux/arm/v7)'; then \
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | /bin/sh -s -- -y \
# For some reason the rustup script is unable to correctly identify the
# environment if we are building an i386 image on an x86_64 system, so we need
# to provide this information manually.
        $(if [ "$TARGETPLATFORM" = "linux/386" ]; then \
            echo "--default-host i686-unknown-linux-gnu"; \
        fi) && \
        . "$HOME/.cargo/env"; \
    fi && \
# Install the latest version of PIP, Setuptools and Wheel.
    curl -L 'https://bootstrap.pypa.io/get-pip.py' | python3 && \
# Install certbot.
    pip3 install -r /requirements.txt && \
# And the supported extra authenticators.
    pip3 install $(echo $CERTBOT_DNS_AUTHENTICATORS | sed 's/\(^\| \)/\1certbot-dns-/g') && \
# Remove everything that is no longer necessary.
    apt-get remove --purge -y \
            build-essential \
            curl \
            libffi-dev \
            libssl-dev \
            pkg-config \
            python3-dev \
    && \
    if echo "$TARGETPLATFORM" | grep -E -q '^(linux/386|linux/arm64|linux/arm/v7)'; then \
        rustup self uninstall -y; \
    fi && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /root/.cache && \
# Create new directories and set correct permissions.
    mkdir -p /var/www/letsencrypt && \
    mkdir -p /etc/nginx/user_conf.d && \
    chown www-data:www-data -R /var/www \
    && \
# Make sure there are no surprise config files inside the config folder.
    rm -f /etc/nginx/conf.d/*

# Copy in our "default" Nginx server configurations, which make sure that the
# ACME challenge requests are correctly forwarded to certbot and then redirects
# everything else to HTTPS.
COPY nginx_conf.d/ /etc/nginx/conf.d/

# Copy in all our scripts and make them executable.
COPY scripts/ /scripts
RUN chmod +x -R /scripts && \
# Make so that the parent's entrypoint script is properly triggered (issue #21).
    sed -ri '/^if \[ "\$1" = "nginx" \] \|\| \[ "\$1" = "nginx-debug" \]; then$/,${s//if echo "$1" | grep -q "nginx"; then/;b};$q1' /docker-entrypoint.sh

# Create a volume to have persistent storage for the obtained certificates.
VOLUME /etc/letsencrypt

# The Nginx parent Docker image already expose port 80, so we only need to add
# port 443 here.
EXPOSE 443

# Change the container's start command to launch our Nginx and certbot
# management script.
CMD [ "/scripts/start_nginx_certbot.sh" ]
