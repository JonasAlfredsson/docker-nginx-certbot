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
# $1: The name of the certificate (e.g. domain.rsa.dns-rfc2136)
# $2: String with all requested domains (e.g. -d domain.org -d www.domain.org)
# $3: Type of key algorithm to use (rsa or ecdsa)
# $4: The authenticator to use to solve the challenge
get_certificate() {
    local authenticator="${4,,}"
    local authenticator_params=""
    local challenge_type=""

    # Add correct parameters for the different authenticator types.
    if [ "${authenticator}" == "webroot" ]; then
        challenge_type="http-01"
        authenticator_params="--webroot-path=/var/www/letsencrypt"
    elif [[ "${authenticator}" == dns-* ]]; then
        local configfile="/etc/letsencrypt/${authenticator#dns-}.ini"
        if [ ! -f "${configfile}" ]; then
            error "Authenticator is '${authenticator}' but '${configfile}' is missing"
            return 1
        fi

        challenge_type="dns-01"
        authenticator_params="--${authenticator}-credentials=${configfile}"
        if [ -n "${CERTBOT_DNS_PROPAGATION_SECONDS}" ]; then
            authenticator_params="${authenticator_params} --${authenticator}-propagation-seconds=${CERTBOT_DNS_PROPAGATION_SECONDS}"
        fi
    else
        error "Unknown authenticator '${authenticator}' for '${1}'"
        return 1
    fi

    info "Requesting an ${3^^} certificate for '${1}' (${challenge_type} through ${authenticator})"
    certbot certonly \
        --agree-tos --keep -n --text \
        --preferred-challenges ${challenge_type} \
        --authenticator ${authenticator} \
        ${authenticator_params} \
        --email "${CERTBOT_EMAIL}" \
        --server "${letsencrypt_url}" \
        --rsa-key-size "${RSA_KEY_SIZE}" \
        --elliptic-curve "${ELLIPTIC_CURVE}" \
        --key-type "${3}" \
        --cert-name "${1}" \
        ${2} \
        --debug ${force_renew}
}

# Get all the cert names for which we should create certificate requests and
# have them signed, along with the corresponding server names.
#
# This will return an associative array that looks something like this:
# "cert_name" => "server_name1 server_name2"
declare -A certificates
for conf_file in /etc/nginx/conf.d/*.conf*; do
    parse_config_file "${conf_file}" certificates
done

# Iterate over each key and make a certificate request for them.
for cert_name in "${!certificates[@]}"; do
    server_names=(${certificates["$cert_name"]})

    # Determine which type of key algorithm to use for this certificate
    # request. Having the algorithm specified in the certificate name will
    # take precedence over the environmental variable.
    if [[ "${cert_name,,}" =~ (^|[-.])ecdsa([-.]|$) ]]; then
        debug "Found variant of 'ECDSA' in name '${cert_name}"
        key_type="ecdsa"
    elif [[ "${cert_name,,}" =~ (^|[-.])ecc([-.]|$) ]]; then
        debug "Found variant of 'ECC' in name '${cert_name}"
        key_type="ecdsa"
    elif [[ "${cert_name,,}" =~ (^|[-.])rsa([-.]|$) ]]; then
        debug "Found variant of 'RSA' in name '${cert_name}"
        key_type="rsa"
    elif [ "${USE_ECDSA}" == "1" ]; then
        key_type="ecdsa"
    else
        key_type="rsa"
    fi

    # Determine the authenticator to use to solve the authentication challenge.
    # Having the authenticator specified in the certificate name will take
    # precedence over the environmental variable.
    if [[ "${cert_name,,}" =~ (^|[-.])webroot([-.]|$) ]]; then
        authenticator="webroot"
        debug "Found mention of 'webroot' in name '${cert_name}"
    elif [[ "${cert_name,,}" =~ (^|[-.])(dns-($(echo ${CERTBOT_DNS_AUTHENTICATORS} | sed 's/ /|/g')))([-.]|$) ]]; then
        authenticator=${BASH_REMATCH[2]}
        debug "Found mention of authenticator '${authenticator}' in name '${cert_name}'"
    elif [ -n "${CERTBOT_AUTHENTICATOR}" ]; then
        authenticator="${CERTBOT_AUTHENTICATOR}"
    else
        authenticator="webroot"
    fi

    # Assemble the list of domains to be included in the request from
    # the parsed 'server_names'
    domain_request=""
    for server_name in "${server_names[@]}"; do
        domain_request="${domain_request} -d ${server_name}"
    done

    # Hand over all the info required for the certificate request, and
    # let certbot decide if it is necessary to update the certificate.
    if ! get_certificate "${cert_name}" "${domain_request}" "${key_type}" "${authenticator}"; then
        error "Certbot failed for '${cert_name}'. Check the logs for details."
    fi
done

# After trying to get all our certificates, auto enable any configs that we
# did indeed get certificates for.
auto_enable_configs

# Finally, tell Nginx to reload the configs.
nginx -s reload
