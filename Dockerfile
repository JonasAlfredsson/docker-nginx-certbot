FROM python:2-alpine
MAINTAINER Henri Dwyer <henri@dwyer.io>

VOLUME /certs
VOLUME /etc/letsencrypt
EXPOSE 80

RUN apk add --no-cache --virtual .build-deps linux-headers gcc musl-dev\
  && apk add --no-cache libffi-dev openssl-dev dialog\
  && pip install certbot\
  && apk del .build-deps\
  && mkdir /scripts

ADD crontab /etc/crontabs
RUN crontab /etc/crontabs/crontab

COPY ./scripts/ /scripts
RUN chmod +x /scripts/run_certbot.sh

ENTRYPOINT []
CMD ["crond", "-f"]
