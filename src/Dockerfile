FROM nginx:mainline
LABEL maintainer="Jonas Alfredsson <jonas.alfredsson@protonmail.com>"

# Do a single run command to make the intermediary containers smaller.
RUN set -ex && \
# Install all necessary packages.
    apt-get update && \
    apt-get install -y \
            build-essential \
            curl \
            libffi6 \
            libffi-dev \
            libssl-dev \
            openssl \
            procps \
            python3 \
            python3-dev \
    && \
# Install certbot.
    curl -L 'https://bootstrap.pypa.io/get-pip.py' | python3 && \
    pip3 install -U cffi certbot \
    && \
# Remove everything that is no longer necessary.
    apt-get remove --purge -y \
            build-essential \
            curl \
            libffi-dev \
            libssl-dev \
            python3-dev \
    && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* \
    && \
# Create new directories and set correct permissions for them.
    mkdir -p /var/www/letsencrypt && \
    chown www-data:www-data -R /var/www && \
    mkdir -p /etc/letsencrypt/dhparams && \
    chmod 700 /etc/letsencrypt/dhparams \
    && \
# Copy in our "default" Nginx server configurations, which make sure that the
# ACME challenge requests are correctly forwarded to certbot and then redirects
# everything else to HTTPS.
    rm -f /etc/nginx/conf.d/*
COPY nginx_conf.d/ /etc/nginx/conf.d/

# Copy in our scripts and make them executable.
COPY scripts/ /scripts
RUN chmod +x -R /scripts

# Create a volume to have persistent storage for the obtained certificates.
VOLUME /etc/letsencrypt

# The Nginx parent Docker image already expose port 80, so we only need to add
# port 443 here.
EXPOSE 443

# Change the container's start command to launch our Nginx and certbot
# management script.
CMD ["/bin/bash", "/scripts/start_nginx_certbot.sh"]
