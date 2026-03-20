#!/bin/bash
set -e

# URLs used when requesting certificates (same defaults as run_certbot.sh).
: "${CERTBOT_PRODUCTION_URL=https://acme-v02.api.letsencrypt.org/directory}"
: "${CERTBOT_STAGING_URL=https://acme-staging-v02.api.letsencrypt.org/directory}"

# Source in util.sh so we can have our nice tools.
. "$(cd "$(dirname "$0")"; pwd)/util.sh"

info "Starting lego certificate renewal process"

# We require an email to be able to request a certificate.
if [ -z "${CERTBOT_EMAIL}" ]; then
    error "CERTBOT_EMAIL environment variable undefined; lego will do nothing!"
    exit 1
fi

# Use the correct challenge URL depending on if we want staging or not.
if [ "${STAGING}" = "1" ]; then
    debug "Using staging environment"
    letsencrypt_url="${CERTBOT_STAGING_URL}"
else
    debug "Using production environment"
    letsencrypt_url="${CERTBOT_PRODUCTION_URL}"
fi

# Directory where multi*.ini credentials files are kept (same as certbot).
: "${CERTBOT_DNS_CREDENTIALS_DIR=/etc/letsencrypt}"

# Root path for lego storage; certificates land in ${LEGO_PATH}/certificates/.
: "${LEGO_PATH=/etc/letsencrypt}"

if [ "${1}" = "force" ]; then
    force_renew="--force"
fi

# Map certbot key-type names to lego --key-type values.
map_key_type() {
    case "${1}" in
        rsa)   echo "rsa2048" ;;
        ecdsa) echo "EC256"   ;;
        *)     echo "EC256"   ;;
    esac
}

# Request or renew a dns-multi certificate using lego.
#
# $1: cert_name  — the name used in the letsencrypt/live/ path
#                  (e.g. "lalatina-freemyip.dns-multi")
# $2: space-separated domain list (e.g. "lalatina.freemyip.com *.lalatina.freemyip.com")
# $3: key type   — rsa or ecdsa
get_certificate_lego() {
    local cert_name="${1}"
    local domains=($2)
    local key_type
    key_type=$(map_key_type "${3}")

    # Extract any suffix after dns-multi (e.g. "_1" from "name.dns-multi_1") to
    # support unique credentials files: multi_1.ini, multi_2.ini, etc.
    local creds_suffix=""
    if [[ "${cert_name,,}" =~ (^|[-.])dns-multi(_[^-.]+)?([-.]|$) ]]; then
        creds_suffix="${BASH_REMATCH[2]}"
    fi
    local creds_file="${CERTBOT_DNS_CREDENTIALS_DIR}/multi${creds_suffix}.ini"

    if [ ! -f "${creds_file}" ]; then
        error "Credentials file '${creds_file}' not found for '${cert_name}'"
        return 1
    fi

    # Parse multi.ini: extract dns_multi_provider and all env var lines.
    # Format:
    #   dns_multi_provider = <provider>
    #   PROVIDER_ENV_VAR   = value
    local provider=""
    local -a env_args=()
    while IFS= read -r line; do
        [[ "${line}" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue
        local key value
        key=$(echo "${line}"  | cut -d= -f1  | tr -d ' ')
        value=$(echo "${line}" | cut -d= -f2- | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
        if [ "${key}" = "dns_multi_provider" ]; then
            provider="${value}"
        elif [ -n "${key}" ]; then
            env_args+=("${key}=${value}")
        fi
    done < "${creds_file}"

    if [ -z "${provider}" ]; then
        error "No 'dns_multi_provider' entry found in '${creds_file}'"
        return 1
    fi

    # Build lego --domains args.
    local -a domain_args=()
    for d in "${domains[@]}"; do
        domain_args+=("--domains" "${d}")
    done

    # Determine the filename lego will use.  lego names the output file after
    # the first domain, replacing '*' with '_'.
    local primary_domain="${domains[0]}"
    local lego_cert_name="${primary_domain//\*/_}"
    local lego_certs_dir="${LEGO_PATH}/certificates"
    local lego_cert="${lego_certs_dir}/${lego_cert_name}.crt"

    # Use 'run' for a new certificate, 'renew' for an existing one.
    local lego_subcmd="run"
    local lego_extra_args=()
    if [ -f "${lego_cert}" ]; then
        lego_subcmd="renew"
        [ -n "${force_renew}" ] && lego_extra_args+=("${force_renew}")
    fi

    info "Requesting a ${key_type} certificate for '${cert_name}' (dns-01 through lego/${provider})"
    env "${env_args[@]}" lego \
        --path    "${LEGO_PATH}" \
        --email   "${CERTBOT_EMAIL}" \
        --server  "${letsencrypt_url}" \
        --dns     "${provider}" \
        --key-type "${key_type}" \
        --accept-tos \
        "${domain_args[@]}" \
        ${lego_subcmd} "${lego_extra_args[@]}" || return 1

    # Symlink lego's output into the certbot-compatible live/<cert_name>/ layout
    # so that nginx finds fullchain.pem and privkey.pem at the expected paths.
    #
    #   lego output                      certbot equivalent
    #   <domain>.crt  (full chain)   ->  fullchain.pem
    #   <domain>.key  (private key)  ->  privkey.pem
    #   <domain>.issuer.crt (chain)  ->  chain.pem
    local live_dir="${LEGO_PATH}/live/${cert_name}"
    mkdir -p "${live_dir}"
    ln -sf "${lego_certs_dir}/${lego_cert_name}.crt"        "${live_dir}/fullchain.pem"
    ln -sf "${lego_certs_dir}/${lego_cert_name}.key"        "${live_dir}/privkey.pem"
    ln -sf "${lego_certs_dir}/${lego_cert_name}.issuer.crt" "${live_dir}/chain.pem"
    debug "Symlinked lego certs into '${live_dir}'"
}

# Discover all cert names from nginx configs — same mechanism as run_certbot.sh.
declare -A certificates
while IFS= read -r -d $'\0' conf_file; do
    parse_config_file "${conf_file}" certificates
done < <(find -L /etc/nginx/conf.d/ -name "*.conf*" -type f -print0)

# Process only certs whose name contains dns-multi; all others belong to certbot.
lego_ran=0
for cert_name in "${!certificates[@]}"; do
    if ! [[ "${cert_name,,}" =~ (^|[-.])dns-multi([-._]|$) ]]; then
        continue
    fi

    server_names=(${certificates["${cert_name}"]})

    # Determine key type from cert name (same logic as run_certbot.sh).
    if [[ "${cert_name,,}" =~ (^|[-.])ecdsa([-.]|$) ]] || \
       [[ "${cert_name,,}" =~ (^|[-.])ecc([-.]|$) ]]; then
        key_type="ecdsa"
    elif [[ "${cert_name,,}" =~ (^|[-.])rsa([-.]|$) ]]; then
        key_type="rsa"
    elif [ "${USE_ECDSA}" == "0" ]; then
        key_type="rsa"
    else
        key_type="ecdsa"
    fi

    if ! get_certificate_lego "${cert_name}" "${server_names[*]}" "${key_type}"; then
        error "Lego failed for '${cert_name}'. Check the logs for details."
    else
        lego_ran=1
    fi
done

# Only reload nginx if lego actually obtained or renewed at least one certificate.
if [ "${lego_ran}" -eq 1 ]; then
    auto_enable_configs

    if ! nginx -t; then
        error "Nginx configuration is invalid after lego renewal. Check the logs for details."
        exit 0
    fi

    nginx -s reload
fi
