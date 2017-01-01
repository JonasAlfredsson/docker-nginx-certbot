FROM python:2
MAINTAINER Henri Dwyer <henri@dwyer.io>

VOLUME /etc/letsencrypt
EXPOSE 80

RUN apt update && apt install -y cron
RUN pip install certbot
RUN mkdir /scripts

ADD ./crontab /etc/cron.d/certbot
RUN crontab /etc/cron.d/certbot

COPY ./scripts/ /scripts
RUN chmod +x /scripts/run_certbot.sh

ENTRYPOINT []
CMD ["/scripts/entrypoint.sh"]
