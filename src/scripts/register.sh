#!/bin/sh

PRODUCTION_URL='https://acme-v01.api.letsencrypt.org/directory'
STAGING_URL='https://acme-staging.api.letsencrypt.org/directory'

if [ "${IS_STAGING}" = "1" ]; then
    letsencrypt_url=$STAGING_URL
    echo "Staging ..."
else
    letsencrypt_url=$PRODUCTION_URL
    echo "Production ..."
fi

echo "running certbot ... $letsencrypt_url $1 $2"
certbot certonly --agree-tos --keep -n --text --email $2 --server \
    $letsencrypt_url -d $1 --http-01-port 1337 \
    --standalone --preferred-challenges http-01 --debug
