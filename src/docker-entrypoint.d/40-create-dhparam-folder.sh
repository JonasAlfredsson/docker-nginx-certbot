#!/bin/bash
# Certbot is able to create its own folder structure in case it is missing,
# e.g. when a bind mount is made on top of the /etc/letsencrypt folder, but the
# /etc/letsencrypt/dhparams folder is outside of its scope which is why we need
# to create it manually at startup.

if [ ! -d "/etc/letsencrypt/dhparams" ]; then
    echo "Creating missing dhparams folder"
    mkdir -vp /etc/letsencrypt/dhparams
fi
