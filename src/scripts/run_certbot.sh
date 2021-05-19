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
    debug "Using staging environment"
    letsencrypt_url=${CERTBOT_STAGING_URL}
else
    debug "Using production environment"
    letsencrypt_url=${CERTBOT_PRODUCTION_URL}
fi

# Ensure that an RSA key size is set.
if [ -z "${RSA_KEY_SIZE}" ]; then
    debug "RSA_KEY_SIZE unset, defaulting to 2048"
    RSA_KEY_SIZE=2048
fi

# Ensure that an elliptic curve is set.
if [ -z "${ELLIPTIC_CURVE}" ]; then
    debug "ELLIPTIC_CURVE unset, defaulting to 'secp256r1'"
    ELLIPTIC_CURVE="secp256r1"
fi

if [ "${1}" = "force" ]; then
    info "Forcing renewal of certificates"
    force_renew="--force-renewal"
fi

# Helper function to ask certbot to request a certificate for the given cert
# name. The CERTBOT_EMAIL environment variable must be defined, so that
# Let's Encrypt may contact you in case of security issues.
#
# $1: The name of the certificate (e.g. domain-rsa)
# $2: String with all requested domains (e.g. -d domain.org -d www.domain.org)
# $3: Type of key algorithm to use (rsa or ecdsa)
get_certificate() {
    info "Requesting an ${3^^} certificate for '${1}'"
    certbot certonly \
        --agree-tos --keep -n --text \
        -a webroot --webroot-path=/var/www/letsencrypt \
        --preferred-challenges http-01 \
        --email "${CERTBOT_EMAIL}" \
        --server "${letsencrypt_url}" \
        --rsa-key-size "${RSA_KEY_SIZE}" \
        --elliptic-curve "${ELLIPTIC_CURVE}" \
        --key-type "${3}" \
        --cert-name "${1}" \
        ${2} \
        --debug ${force_renew}
}

# Go through all .conf files and find all cert names for which we should create
# certificate requests.
for conf_file in /etc/nginx/conf.d/*.conf*; do
    for cert_name in $(parse_cert_names "${conf_file}"); do
        # Determine which type of key algorithm to use for this certificate
        # request. Having the algorithm specified in the certificate name will
        # take precedence over the environmental variable.
        if [[ "${cert_name,,}" =~ ^.*(-|\.)ecdsa.*$ ]]; then
            debug "Found variant of 'ECDSA' in name '${cert_name}"
            key_type="ecdsa"
        elif [[ "${cert_name,,}" =~ ^.*(-|\.)ecc.*$ ]]; then
            debug "Found variant of 'ECC' in name '${cert_name}"
            key_type="ecdsa"
        elif [[ "${cert_name,,}" =~ ^.*(-|\.)rsa.*$ ]]; then
            debug "Found variant of 'RSA' in name '${cert_name}"
            key_type="rsa"
        elif [ "${USE_ECDSA}" == "1" ]; then
            key_type="ecdsa"
        else
            key_type="rsa"
        fi

        # Find all 'server_names' in this .conf file and assemble the list of
        # domains to be included in the request.
        domain_request=""
        for server_name in $(parse_server_names "${conf_file}"); do
            domain_request="${domain_request} -d ${server_name}"
        done

        # Hand over all the info required for the certificate request, and
        # let certbot decide if it is necessary to update the certificate.
        if ! get_certificate "${cert_name}" "${domain_request}" "${key_type}"; then
            error "Certbot failed for '${cert_name}'. Check the logs for details."
        fi
    done
done

# After trying to get all our certificates, auto enable any configs that we
# did indeed get certificates for.
auto_enable_configs

# Finally, tell Nginx to reload the configs.
nginx -s reload
