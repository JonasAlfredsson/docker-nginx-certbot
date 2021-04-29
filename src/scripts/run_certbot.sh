#!/bin/bash
set -e

# URLs used when requesting certificates.
CERTBOT_PRODUCTION_URL='https://acme-v02.api.letsencrypt.org/directory'
CERTBOT_STAGING_URL='https://acme-staging-v02.api.letsencrypt.org/directory'

# Source in util.sh so we can have our nice tools.
. "$(cd "$(dirname "$0")"; pwd)/util.sh"

info "Starting certificate renewal process"

# We require an email to be able to request a certificate.
if [ -z "${CERTBOT_EMAIL}" ]; then
    error "CERTBOT_EMAIL environment variable undefined; certbot will do nothing!"
    exit 1
fi

# Use the correct challenge URL depending on if we want staging or not.
if [ "${STAGING}" = "1" ]; then
    letsencrypt_url=${CERTBOT_STAGING_URL}
    debug "Using staging environment"
else
    letsencrypt_url=${CERTBOT_PRODUCTION_URL}
    debug "Using production environment"
fi

# Ensure that a key size is set.
if [ -z "${RSA_KEY_SIZE}" ]; then
    debug "RSA_KEY_SIZE unset, defaulting to 2048"
    RSA_KEY_SIZE=2048
fi

if [ "${1}" = "force" ]; then
    info "Forcing renewal of certificates"
    force_renew="--force-renewal"
fi

# Helper function to ask certbot to request a certificate for the given
# domain(s). The CERTBOT_EMAIL environment variable must be defined, so that
# Let's Encrypt may contact you in case of security issues.
#
# $1: The name of the certificate file (e.g. domain.org)
# $2: String with all requested domains (e.g. -d domain.org -d www.domain.org)
get_certificate() {
    info "Requesting certificate for the primary domain '${1}'"
    certbot certonly \
        --agree-tos --keep -n --text \
        -a webroot --webroot-path=/var/www/letsencrypt \
        --rsa-key-size "${RSA_KEY_SIZE}" \
        --preferred-challenges http-01 \
        --email "${CERTBOT_EMAIL}" \
        --server "${letsencrypt_url}" \
        --cert-name "$1" \
        $2 \
        --debug ${force_renew}
}

# Go through all .conf files and find all domain names that should be added
# to the certificate request.
for conf_file in /etc/nginx/conf.d/*.conf*; do
    for primary_domain in $(parse_primary_domains "${conf_file}"); do
        # At minimum we will make a request for the primary domain.
        domain_request="-d ${primary_domain}"

        # Find all 'server_names' in this .conf file and add them to the
        # same request.
        for server_name in $(parse_server_names "${conf_file}"); do
            domain_request="${domain_request} -d ${server_name}"
        done

        # Hand over all the info required for the certificate request, and
        # let certbot decide if it is necessary to update the certificate.
        if ! get_certificate "${primary_domain}" "${domain_request}"; then
            error "Certbot failed for '${primary_domain}'. Check the logs for details."
        fi
    done
done

# After trying to get all our certificates, auto enable any configs that we
# did indeed get certificates for.
auto_enable_configs

# Finally, tell Nginx to reload the configs.
nginx -s reload
