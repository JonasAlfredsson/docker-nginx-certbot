#!/bin/bash
set -e

# URLs used when requesting certificates.
# These are picked up from the environment if they are set, which enables
# advanced usage of custom ACME servers, else it will use the default Let's
# Encrypt servers defined here.
: "${CERTBOT_PRODUCTION_URL=https://acme-v02.api.letsencrypt.org/directory}"
: "${CERTBOT_STAGING_URL=https://acme-staging-v02.api.letsencrypt.org/directory}"

# Source in util.sh so we can have our nice tools.
. "$(cd "$(dirname "$0")"; pwd)/util.sh"

info "Starting certificate renewal process"

# We require an email to be able to request a certificate.
if [ -z "${CERTBOT_EMAIL}" ]; then
    error "CERTBOT_EMAIL environment variable undefined; certbot will do nothing!"
    exit 1
fi

if [ ! -z "${CUSTOM_SERVER_URL}" ]
then
    debug "Using custom CA server at \"${CUSTOM_SERVER_URL}\""
    letsencrypt_url="${CUSTOM_SERVER_URL}" # Not necessarily Let's Encrypt anymore though...
else
    # Use the correct challenge URL depending on if we want staging or not.
    if [ "${STAGING}" = "1" ]; then
        debug "Using staging environment"
        letsencrypt_url="${CERTBOT_STAGING_URL}"
    else
        debug "Using production environment"
        letsencrypt_url="${CERTBOT_PRODUCTION_URL}"
    fi
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

# Ensure that we have a directory where DNS credentials may be placed.
: "${CERTBOT_DNS_CREDENTIALS_DIR=/etc/letsencrypt}"
if [ ! -d "${CERTBOT_DNS_CREDENTIALS_DIR}" ]; then
    error "DNS credentials directory '${CERTBOT_DNS_CREDENTIALS_DIR}' does not exist"
    exit 1
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
get_certificate() {
    local cert_name="${1}"
    local authenticator=""
    local authenticator_params=""
    local challenge_type=""
    local dns_config_file=""

    # Determine the authenticator to use to solve the authentication challenge.
    # Having the authenticator specified in the certificate name will take
    # precedence over the environmental variable.
    if [[ "${cert_name,,}" =~ (^|[-.])webroot([-.]|$) ]]; then
        debug "Found mention of 'webroot' in name '${cert_name}"
        authenticator="webroot"
    elif [[ "${cert_name,,}" =~ (^|[-.])dns-([^-.]*)([-.]|$) ]]; then
        # Looks like there is some kind of DNS authenticator in the name, save the full name as the
        # config file. This allows something like "name.dns-rfc2136_conf1.ecc" to then use the
        # config file name "rfc2136_conf1.ini" instead of just "rfc2136.ini" further down.
        dns_config_file="${CERTBOT_DNS_CREDENTIALS_DIR}/${BASH_REMATCH[2]}.ini"
        if [[ "${BASH_REMATCH[2]}" =~ ($(echo ${CERTBOT_DNS_AUTHENTICATORS} | sed 's/ /|/g')) ]]; then
            authenticator="dns-${BASH_REMATCH[1]}"
            debug "Found mention of authenticator '${authenticator}' in name '${cert_name}'"
        else
            error "The DNS authenticator found in '${cert_name}' does not appear to be supported"
            return 1
        fi
    elif [ -n "${CERTBOT_AUTHENTICATOR}" ]; then
        authenticator="${CERTBOT_AUTHENTICATOR}"
    else
        authenticator="webroot"
    fi

    # Add correct parameters for the different authenticator types.
    if [ "${authenticator}" == "webroot" ]; then
        challenge_type="http-01"
        authenticator_params="--webroot-path=/var/www/letsencrypt"
    elif [[ "${authenticator}" =~ ^dns-($(echo ${CERTBOT_DNS_AUTHENTICATORS} | sed 's/ /|/g'))$ ]]; then
        challenge_type="dns-01"

        if [ "${authenticator#dns-}" == "route53" ]; then
            # This one is special and makes use of a different configuration.
            if [[ ( -z "${AWS_ACCESS_KEY_ID}" || -z "${AWS_SECRET_ACCESS_KEY}" ) && ! -f "${HOME}/.aws/config" ]]; then
                error "Authenticator is '${authenticator}' but neither '${HOME}/.aws/config' or AWS_ACCESS_KEY_ID + AWS_SECRET_ACCESS_KEY are found"
                return 1
            fi
        else
            if [ -z "${dns_config_file}" ]; then
                # If we don't already have a config file set for this authenticator we assemble
                # the default path.
                dns_config_file="${CERTBOT_DNS_CREDENTIALS_DIR}/${authenticator#dns-}.ini"
            fi
            if [ ! -f "${dns_config_file}" ]; then
                error "Authenticator is '${authenticator}' but '${dns_config_file}' is missing"
                return 1
            fi
            debug "Using DNS credentials file at '${dns_config_file}'"
            authenticator_params="--${authenticator}-credentials=${dns_config_file}"
        fi

        if [ -n "${CERTBOT_DNS_PROPAGATION_SECONDS}" ]; then
            authenticator_params="${authenticator_params} --${authenticator}-propagation-seconds=${CERTBOT_DNS_PROPAGATION_SECONDS}"
        fi
    else
        error "Unknown authenticator '${authenticator}' for '${cert_name}'"
        return 1
    fi

    info "Requesting an ${3^^} certificate for '${cert_name}' (${challenge_type} through ${authenticator})"
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
        --cert-name "${cert_name}" \
        ${2} \
        --debug ${force_renew}
}

# Get all the cert names for which we should create certificate requests and
# have them signed, along with the corresponding server names.
#
# This will return an associative array that looks something like this:
# "cert_name" => "server_name1 server_name2"
declare -A certificates
while IFS= read -r -d $'\0' conf_file; do
    parse_config_file "${conf_file}" certificates
done < <(find -L /etc/nginx/conf.d/ -name "*.conf*" -type f -print0)

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
    elif [ "${USE_ECDSA}" == "0" ]; then
        key_type="rsa"
    else
        key_type="ecdsa"
    fi

    # Assemble the list of domains to be included in the request from
    # the parsed 'server_names'
    domain_request=""
    for server_name in "${server_names[@]}"; do
        domain_request="${domain_request} -d ${server_name}"
    done

    # Hand over all the info required for the certificate request, and
    # let certbot decide if it is necessary to update the certificate.
    if ! get_certificate "${cert_name}" "${domain_request}" "${key_type}"; then
        error "Certbot failed for '${cert_name}'. Check the logs for details."
    fi
done

# After trying to get all our certificates, auto enable any configs that we
# did indeed get certificates for.
auto_enable_configs

# Make sure the Nginx configs are valid.
if ! nginx -t; then
  error "Nginx configuration is invalid, skipped reloading. Check the logs for details."
  exit 0
fi

# Finally, tell Nginx to reload the configs.
nginx -s reload
