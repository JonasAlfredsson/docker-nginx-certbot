FROM nginx
MAINTAINER Elliot Saba <staticfloat@gmail.com>

VOLUME /etc/letsencrypt
EXPOSE 80
EXPOSE 443

#RUN apt update && apt install -y cron python python-dev python-pip libffi-dev libssl-dev
#RUN pip install -U cffi certbot
RUN apt update && apt install -y cron python python-dev libffi6 libffi-dev libssl1.0.0 libssl-dev curl build-essential
RUN curl -L 'https://bootstrap.pypa.io/get-pip.py' | python
RUN pip install -U cffi certbot
RUN apt remove -y python-dev build-essential libffi-dev libssl-dev curl && apt-get autoremove -y && apt-get clean

# Copy in cron job and scripts for certbot
COPY ./crontab /etc/cron.d/certbot
RUN crontab /etc/cron.d/certbot
COPY ./scripts/ /scripts
RUN chmod +x /scripts/*.sh

# Copy in default nginx configuration (which just forwards ACME requests to
# certbot, or redirects to HTTPS, but has no HTTPS configurations by default).
RUN rm -f /etc/nginx/conf.d/*
COPY nginx_conf.d/ /etc/nginx/conf.d/

ENTRYPOINT []
CMD ["/bin/bash", "/scripts/entrypoint.sh"]
