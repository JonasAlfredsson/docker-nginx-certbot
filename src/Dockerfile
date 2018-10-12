FROM nginx:mainline
LABEL maintainer="Jonas Alfredsson <jonas.alfredsson@protonmail.com>"

# Do a single run command to make the intemediary containers smaller.
# Install all necessary packages 
RUN set -ex && \
    apt-get update && \
    apt-get install -y \
            build-essential \
            curl \
            libffi6 \
            libffi-dev \
            libssl-dev \
            python \
            python-dev \
            openssl \
    && \
# Install certbot
    curl -L 'https://bootstrap.pypa.io/get-pip.py' | python && \
    pip install -U cffi certbot \
    && \
# Remove everything that is no longer necessary
    apt-get remove --purge -y \
            build-essential \
            curl \
            libffi-dev \
            libssl-dev \
            python-dev \
    && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* \
    && \
# Create new directories and set correct permissions
    mkdir -p /var/www/letsencrypt && \
    chown www-data:www-data -R /var/www && \
    mkdir -p /etc/letsencrypt/dhparams && \
    chmod 700 /etc/letsencrypt/dhparams \
    && \
# Copy in default nginx configuration (which just forwards ACME requests to
# certbot, or redirects to HTTPS, but has no HTTPS configurations by default).
    rm -f /etc/nginx/conf.d/*
COPY nginx_conf.d/ /etc/nginx/conf.d/

# Copy in scripts and set permissions
COPY scripts/ /scripts
RUN chmod +x -R /scripts

# Create a volume to have persistent storage for obtained certificates
VOLUME /etc/letsencrypt

EXPOSE 80
EXPOSE 443

ENTRYPOINT []
CMD ["/bin/bash", "/scripts/entrypoint.sh"]
