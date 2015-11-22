FROM quay.io/letsencrypt/letsencrypt
MAINTAINER Henri Dwyer <henri@dwyer.io>

RUN mkdir /certs
 
# Add crontab file in the cron directory
ADD crontab /etc/cron.d/crontab
 
# Give execution rights on the cron job
RUN chmod 0644 /etc/cron.d/crontab

COPY ./scripts/ /

ENTRYPOINT ["/bin/sh", "-c"]

CMD ["/run_cron.sh"]
