#!/bin/bash
set -e

# Source in util.sh so we can have our nice tools.
. "$(cd "$(dirname "$0")"; pwd)/util.sh"

info "Starting certificate renewal process"

# Lookup config for debug mode here too since this script is sometimes run as a standalone
# script with the "force" argument.
DEBUG=$(get_config nginx-certbot.debug DEBUG 0 "debug mode")
export DEBUG

# Load the configuration
certbot_email=$(get_config certbot.email CERTBOT_EMAIL '' "certbot email")
certbot_authenticator=$(get_config certbot.authenticator CERTBOT_AUTHENTICATOR webroot "default certbot authenticator")
certbot_elliptic_curve=$(get_config certbot.elliptic-curve ELLIPTIC_CURVE secp256r1 "certbot elliptic curve")
certbot_key_type=$(get_config certbot.key-type '' "$( [ "${USE_ECDSA}" == "0" ] && echo "rsa" || echo "ecdsa")" "default certbot key type")
certbot_rsa_key_size=$(get_config certbot.rsa-key-size RSA_KEY_SIZE 2048 "default certbot RSA key size")
certbot_staging=$(get_config certbot.staging STAGING 0 "certbot staging")
certbot_dns_propagation=$(get_config certbot.dns-propagation-seconds CERTBOT_DNS_PROPAGATION_SECONDS '' "DNS propagation timeout")

# URLs used when requesting certificates.
# These are picked up from the environment if they are set, which enables
# advanced usage of custom ACME servers, else it will use the default Let's
# Encrypt servers defined here.
certbot_production_url=$(get_config certbot.production-url CERTBOT_PRODUCTION_URL "https://acme-v02.api.letsencrypt.org/directory" "certbot production URL")
certbot_staging_url=$(get_config certbot.staging-url CERTBOT_STAGING_URL "https://acme-staging-v02.api.letsencrypt.org/directory" "certbot staging URL")

# We require an email to be able to request a certificate.
if [ -z "${certbot_email}" ]; then
    error "certbot.email or the CERTBOT_EMAIL environment variable must be set; without it certbot will do nothing!"
    exit 1
fi

# Use the correct challenge URL depending on if we want staging or not.
if [ "${certbot_staging}" = "1" ]; then
    debug "Using staging environment (${certbot_staging_url})"
    letsencrypt_url="${certbot_staging_url}"
else
    debug "Using production environment (${certbot_production_url})"
    letsencrypt_url="${certbot_production_url}"
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
# $5: The RSA key size (--rsa-key-size)
# $6: The elliptic curve (--elliptic-curve)
# $7: Credentials file for the authenticator
get_certificate() {
    local cert_name="${1}"
    local domain_request="${2}"
    local key_type="${3}"
    local authenticator="${4,,}"
    local rsa_key_size="${5:-certbot_rsa_key_size}"
    local elliptic_curve="${6:-certbot_elliptic_curve}"
    local credentials="${7}"
    local authenticator_params=""
    local challenge_type=""

    # Add correct parameters for the different authenticator types.
    if [ "${authenticator}" == "webroot" ]; then
        challenge_type="http-01"
        authenticator_params="--webroot-path=/var/www/letsencrypt"
    elif [[ "${authenticator}" == dns-* ]]; then
        challenge_type="dns-01"

        if [ "${authenticator#dns-}" == "route53" ]; then
            # This one is special and makes use of a different configuration.
            if [[ ( -z "${AWS_ACCESS_KEY_ID}" || -z "${AWS_SECRET_ACCESS_KEY}" ) && ! -f "${HOME}/.aws/config" ]]; then
                error "Authenticator is '${authenticator}' but neither '${HOME}/.aws/config' or AWS_ACCESS_KEY_ID + AWS_SECRET_ACCESS_KEY are found"
                return 1
            fi
        else
            local configfile="${credentials:-/etc/letsencrypt/${authenticator#dns-}.ini}"
            if [ ! -f "${configfile}" ]; then
                error "Authenticator '${authenticator}' requires credentials but '${configfile}' is missing"
                return 1
            fi
            authenticator_params="--${authenticator}-credentials=${configfile}"
        fi

        if [ -n "${certbot_dns_propagation}" ]; then
            authenticator_params="${authenticator_params} --${authenticator}-propagation-seconds=${certbot_dns_propagation}"
        fi
    else
        error "Unknown authenticator '${authenticator}' for '${cert_name}'"
        return 1
    fi

    info "Requesting an ${key_type^^} certificate for '${cert_name}' (${challenge_type} through ${authenticator})"
    certbot certonly \
        --agree-tos --keep -n --text \
        --preferred-challenges ${challenge_type} \
        --authenticator ${authenticator} \
        ${authenticator_params} \
        --email "${certbot_email}" \
        --server "${letsencrypt_url}" \
        --rsa-key-size "${rsa_key_size}" \
        --elliptic-curve "${elliptic_curve}" \
        --key-type "${key_type}" \
        --cert-name "${cert_name}" \
        ${domain_request} \
        --debug ${force_renew}
}

# Get all the cert names for which we should create certificate requests and
# have them signed, along with the corresponding server names.
# If we have a config file with the 'certificates' key we request certificates based on the
# specifications within that file otherwise we parse the nginx config files to automatically
# discover certificate names, key types, authenticators, and domains.
if [ -f "${CONFIG_FILE}" ] && shyaml -q get-value certificates >/dev/null <"${CONFIG_FILE}"; then
    debug "Using config file '${CONFIG_FILE}' for certificate specifications"
    # Loop over the certificates array and request the certificates
    while read -r -d '' cert; do
        debug "Parsing certificate specification"

        # name (required)
        cert_name="$(shyaml get-value name '' <<<"${cert}")"
        if [ -z "${cert_name}" ]; then
            error "'name' is missing; ignoring this certificate specification"
            continue
        fi
        debug " - certificate name is: ${cert_name}"

        # domains (required)
        domains=()
        while read -r -d '' domain; do
            domains+=("${domain}")
        done < <(shyaml get-values-0 domains '' <<<"${cert}")
        if [ "${#domains[@]}" -eq 0 ]; then
            error "'domains' are missing; ignoring this certificate specification"
            continue
        fi
        debug " - certificate domains are: ${domains[*]}"
        domain_request=""
        for domain in "${domains[@]}"; do
            domain_request+=" --domain ${domain}"
        done

        # key-type (optional)
        key_type=$(shyaml get-value key-type "${certbot_key_type}" <<<"${cert}")
        debug " - certificate key-type is: ${key_type}"

        # authenticator (optional)
        authenticator=$(shyaml get-value authenticator "${certbot_authenticator}" <<<"${cert}")
        debug " - certificate authenticator is: ${authenticator}"

        # credentials (optional)
        credentials=$(shyaml get-value credentials '' <<<"${cert}")
        debug " - certificate authenticator credential file is: ${credentials}"

        # rsa-key-size (optional)
        rsa_key_size=$(shyaml get-value rsa-key-size "${certbot_rsa_key_size}" <<<"${cert}")
        debug " - certificate RSA key size is: ${rsa_key_size}"

        # elliptic-curve (optional)
        elliptic_curve=$(shyaml get-value elliptic-curve "${certbot_elliptic_curve}" <<<"${cert}")
        debug " - certificate elliptic curve is: ${elliptic_curve}"

        # Hand over all the info required for the certificate request, and
        # let certbot decide if it is necessary to update the certificate.
        if ! get_certificate "${cert_name}" "${domain_request}" "${key_type}" "${authenticator}" "${rsa_key_size}" "${elliptic_curve}" "${credentials}"; then
            error "Certbot failed for '${cert_name}'. Check the logs for details."
        fi
    done < <(shyaml -y get-values-0 certificates '' <"${CONFIG_FILE}")
else
    debug "Using automatic discovery of nginx conf file for certificate specifications"
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
        else
            key_type="${certbot_key_type}"
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
        else
            authenticator="${certbot_authenticator}"
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
fi

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
