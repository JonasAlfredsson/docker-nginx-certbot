FROM python:2
MAINTAINER Elliot Saba <staticfloat@gmail.com>

VOLUME /etc/letsencrypt
EXPOSE 80

RUN apt update && apt install -y cron
RUN pip install certbot
RUN mkdir /scripts

COPY ./crontab /etc/cron.d/certbot
RUN crontab /etc/cron.d/certbot

COPY ./scripts/ /scripts
RUN chmod +x /scripts/*.sh

ENTRYPOINT []
CMD ["/bin/bash", "/scripts/entrypoint.sh"]
