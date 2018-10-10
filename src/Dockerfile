FROM nginx
LABEL maintainer="Elliot Saba <staticfloat@gmail.com>, Valder Gallo <valergallo@gmail.com>, Bruno Zell <bruno.zzell@gmail.com>"

# Do this apt/pip stuff all in one RUN command to avoid creating large
# intermediate layers on non-squashable docker installs
RUN apt update && \
    apt install -y python python-dev libffi6 libffi-dev libssl-dev curl build-essential && \
    curl -L 'https://bootstrap.pypa.io/get-pip.py' | python && \
    pip install -U cffi certbot && \
    apt remove --purge -y python-dev build-essential libffi-dev libssl-dev curl && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Add new directories
RUN mkdir -p /scripts/startup /var/www/letsencrypt

# Copy in scripts for certbot
COPY ./scripts/ /scripts

# Edit some permissions
RUN chmod +x /scripts/*.sh && chown www-data: -R /var/www

# Copy in default nginx configuration (which just forwards ACME requests to
# certbot, or redirects to HTTPS, but has no HTTPS configurations by default).
RUN rm -f /etc/nginx/conf.d/*
COPY nginx_conf.d/ /etc/nginx/conf.d/

# Create a volume to have persistant storage for obtained certificates
VOLUME /etc/letsencrypt

EXPOSE 80
EXPOSE 443

ENTRYPOINT []
CMD ["/bin/bash", "/scripts/entrypoint.sh"]
