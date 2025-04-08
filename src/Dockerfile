FROM ubuntu:22.04
LABEL maintainer="Nima Estakhri <nimaestakhri@gmail.com>"
# Set environment variables
ENV NGINX_VERSION=1.27.4
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
    infomaniak \
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
            git \
            wget \
            gcc \
            curl \
            libffi7 \
            libffi-dev \
            libssl-dev \
            openssl \
            pkg-config \
            procps \
            python3 \
            python3-dev \
            python3-pip \
            python3-setuptools \
            python3-wheel \
            gettext-base \
            libpcre3 \
            libpcre3-dev \
            cmake \
            zlib1g-dev && \
    # mkdir /tmp/openssl && \
    # # Download and install OpenSSL
    # cd /tmp/openssl && \
    # wget https://github.com/openssl/openssl/releases/download/openssl-3.4.1/openssl-3.4.1.tar.gz && \
    # tar -xzf openssl-3.4.1.tar.gz && \
    # cd openssl-3.4.1 && \
    # ./config --prefix=/usr/local/openssl-3.4.1 --openssldir=/usr/local/openssl-3.4.1 && \
    # make && \
    # make install && \
    # # Set the environment variables for OpenSSL
    # export LD_LIBRARY_PATH=/usr/local/openssl-3.4.1/lib:$LD_LIBRARY_PATH && \
    # export PATH=/usr/local/openssl-3.4.1/bin:$PATH && \
    # # Set the OpenSSL path for Nginx
    # export OPENSSL_PATH=/usr/local/openssl-3.4.1 && \
    # Download and install Brotli
    git clone https://github.com/google/ngx_brotli.git /tmp/ngx_brotli && \
    cd /tmp/ngx_brotli && git submodule update --init && \
    cd deps/brotli && mkdir -p out && cd out && \
    cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local .. && \
    make && make install && \
    cd /tmp/ngx_brotli && \
    wget http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz -O /tmp/nginx.tar.gz && \
    tar -xzf /tmp/nginx.tar.gz -C /tmp && \
    cd /tmp/nginx-${NGINX_VERSION} && \
    mkdir /etc/nginx/ && \
    cp ./conf/mime.types /etc/nginx/ && \
    ./configure \
    --add-dynamic-module=/tmp/ngx_brotli \
    --with-http_ssl_module \
    --with-http_gzip_static_module \
    --with-pcre \
    --with-http_v2_module \
    --with-http_v3_module  \
    --with-cc-opt='-DNGX_QUIC' \
    --prefix=/opt/nginx && \ 
    make && make install && \
    cp objs/ngx_http_brotli_filter_module.so /opt/nginx/modules/ && \
    cp objs/ngx_http_brotli_static_module.so /opt/nginx/modules/ && \
    mkdir /var/log/nginx/ && \
    touch /var/log/nginx/access.log && \
    touch /var/log/nginx/error.log && \
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
    #mkdir /tmp/pip && \
    #cd /tmp/pip && \
    #curl -L 'https://bootstrap.pypa.io/get-pip.py' | python3 && \
# Install certbot.
    pip3 install -r /requirements.txt && \
# And the supported extra authenticators.
    pip3 install $(echo $CERTBOT_DNS_AUTHENTICATORS | sed 's/\(^\| \)/\1certbot-dns-/g') && \
# Remove everything that is no longer necessary.
    apt-get remove --purge -y \
            build-essential \
            git \
            curl \
            gcc \
            wget \
            cmake\
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
    rm -rf /tmp/nginx.tar.gz /tmp/nginx-1.27.4 /tmp/ngx_brotli && \
    rm -rf /etc/nginx/conf.d/*.conf && \
    rm -rf /opt/nginx/conf/* && \
    rm -rf /tmp/openssl/* && \
    rm -rf /usr/share/man/* /usr/share/doc/* /var/lib/apt/lists/* &&\
# Create new directories and set correct permissions.
    mkdir -p /var/www/letsencrypt && \
    mkdir -p /etc/nginx/user.conf.d && \
    chown www-data:www-data -R /var/www \
    && \
# Make sure there are no surprise config files inside the config folder.
    rm -f /etc/nginx/conf.d/*

# Copy in our "default" Nginx server configurations, which make sure that the
# ACME challenge requests are correctly forwarded to certbot and then redirects
# everything else to HTTPS.

COPY nginx_conf.d/ /etc/nginx/conf.d/
COPY nginx.conf /opt/nginx/conf/nginx.conf

    
# Add NGINX binary to PATH
ENV PATH="/opt/nginx/sbin:${PATH}"

# Copy in all our scripts and make them executable.
COPY scripts/ /scripts
RUN chmod +x -R /scripts
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# Create a volume to have persistent storage for the obtained certificates.
VOLUME /etc/letsencrypt

EXPOSE 80
EXPOSE 443

# Change the container's start command to launch our Nginx and certbot
# management script.
CMD ["/scripts/start_nginx_certbot.sh"]
