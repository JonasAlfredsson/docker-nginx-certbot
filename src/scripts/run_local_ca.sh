#!/bin/bash
set -e

# Important files necessary for this script to work. The LOCAL_CA_DIR variable
# is read from the environment if it is set, else it will use the default
# provided here.
: ${LOCAL_CA_DIR:="/etc/local_ca"}
LOCAL_CA_KEY="${LOCAL_CA_DIR}/caPrivkey.pem"
LOCAL_CA_CRT="${LOCAL_CA_DIR}/caCert.pem"
LOCAL_CA_DB="${LOCAL_CA_DIR}/index.txt"
LOCAL_CA_SRL="${LOCAL_CA_DIR}/serial.txt"
LOCAL_CA_CRT_DIR="${LOCAL_CA_DIR}/new_certs"

# Source in util.sh so we can have our nice tools.
. "$(cd "$(dirname "$0")"; pwd)/util.sh"

info "Starting certificate renewal process with local CA"

# We require an email to be set here as well, in order to simulate how it would
# be in the real certbot case.
if [ -z "${CERTBOT_EMAIL}" ]; then
    error "CERTBOT_EMAIL environment variable undefined; local CA will do nothing!"
    exit 1
fi

# Ensure that an RSA key size is set.
if [ -z "${RSA_KEY_SIZE}" ]; then
    debug "RSA_KEY_SIZE unset, defaulting to 2048"
    RSA_KEY_SIZE=2048
fi

# This is an OpenSSL configuration file that has settings for creating a well
# configured CA, as well as server certificates that adhere to the strict
# standards of web browsers. This is not complete, but will have the missing
# sections dynamically assembled by the functions that need them at runtime.
openssl_cnf="
# This section is invoked when running 'openssl ca ...'
[ ca ]
default_ca              = custom_ca_settings

[ custom_ca_settings ]
private_key             = ${LOCAL_CA_KEY}
certificate             = ${LOCAL_CA_CRT}
database                = ${LOCAL_CA_DB}
serial                  = ${LOCAL_CA_SRL}
new_certs_dir           = ${LOCAL_CA_CRT_DIR}
default_days            = 30
default_md              = sha256
email_in_dn             = yes
unique_subject          = no
policy                  = custom_ca_policy

[ custom_ca_policy ]
countryName             = optional
stateOrProvinceName     = optional
localityName            = optional
organizationName        = optional
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = supplied

# This section is invoked when running 'openssl req ...'
[ req ]
default_md              = sha256
prompt                  = no
utf8                    = yes
string_mask             = utf8only
distinguished_name      = dn_section
# ^-- This needs to be defined else 'req' will fail with:
#     openssl unable to find 'distinguished_name' in config
# If the '[dn_section]' is defined, but empty, we instead get:
#     error, no objects specified in config file
# This is true even if we create a fully valid '-subj' string while using
# these commands. LibreSSL also prioritize this content over what is being
# sent in via '-subj', which is opposite to how OpenSSL works. Solution is
# to assemble this section with the help of printf when using this command.

# These extensions should be supplied when creating the CA certificate.
[ ca_cert ]
basicConstraints        = critical, CA:true
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid:always,issuer:always
keyUsage                = critical, keyCertSign, cRLSign
subjectAltName          = email:copy
issuerAltName           = issuer:copy

# These extensions should be supplied when creating a server certificate.
[ server_cert ]
basicConstraints        = critical, CA:false
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid,issuer
keyUsage                = keyEncipherment, dataEncipherment, digitalSignature
extendedKeyUsage        = serverAuth, clientAuth
issuerAltName           = issuer:copy
subjectAltName          = @alt_names
# ------------------------^
# Alt names must include all domain names/IPs the server certificate should be
# valid for. This will be populated by the script later.
"


# Helper function to create a private key and a self-signed certificate to be
# used as our local certificate authority. If the files already exist it will
# do nothing, which means that it is actually possible to host mount a
# completely custom CA here if you want to.
generate_ca() {
    # Make sure necessary folders are present.
    mkdir -vp "${LOCAL_CA_DIR}"
    mkdir -vp "${LOCAL_CA_CRT_DIR}"

    # Make sure there is a private key available for the CA.
    if [ ! -f "${LOCAL_CA_KEY}" ]; then
        info "Generating new private key for local CA"
        openssl genrsa -out "${LOCAL_CA_KEY}" "${RSA_KEY_SIZE}"
    fi

    # Make sure there exists a self-signed certificate for the CA.
    if [ ! -f "${LOCAL_CA_CRT}" ]; then
        info "Creating new self-signed certificate for local CA"
        openssl req -x509 -new -nodes \
                    -config <(printf "%s\n" \
                              "${openssl_cnf}" \
                              "[ dn_section ]" \
                              "countryName             = SE" \
                              "0.organizationName      = github.com/JonasAlfredsson" \
                              "organizationalUnitName  = docker-nginx-certbot" \
                              "commonName              = Local Debug CA" \
                              "emailAddress            = ${CERTBOT_EMAIL}" \
                              ) \
                    -extensions ca_cert \
                    -days 30 \
                    -key "${LOCAL_CA_KEY}" \
                    -out "${LOCAL_CA_CRT}"
    fi

    # If a serial file does not exist, or if it has a size of zero, we create
    # one with an initial value.
    if [ ! -f "${LOCAL_CA_SRL}" ] || [ ! -s "${LOCAL_CA_SRL}" ]; then
        info "Creating new serial file for local CA"
        openssl rand -hex 20 > "${LOCAL_CA_SRL}"
    fi

    # Make sure there is a database file.
    if [ ! -f "${LOCAL_CA_DB}" ]; then
        info "Creating new index file for local CA"
        touch "${LOCAL_CA_DB}"
    fi
}

# Helper function that use the local CA in order to create a valid signed
# certificate for the given cert name.
#
# $1: The name of the certificate (e.g. domain)
# $@: All alternate name variants, separated by space
#     (e.g. DNS.1=domain.org DNS.2=localhost IP.1=127.0.0.1)
get_certificate() {
    # Store the cert name for future use, and then `shift` so the rest of the
    # input arguments are just alt names.
    local cert_name="$1"
    shift

    # Make sure the necessary folder exists.
    mkdir -vp "/etc/letsencrypt/live/${cert_name}"

    # Make sure there is a private key available for the domain in question.
    # It is good practice to generate a new key every time a new certificate is
    # requested, in order to guard against potential key compromises.
    info "Generating new private key for '${cert_name}'"
    openssl genrsa -out "/etc/letsencrypt/live/${cert_name}/privkey.pem" "${RSA_KEY_SIZE}"

    # Create a certificate signing request from the private key.
    info "Generating certificate signing request for '${cert_name}'"
    openssl req -new -config  <(printf "%s\n" \
                                "${openssl_cnf}" \
                                "[ dn_section ]" \
                                "commonName   = ${cert_name}" \
                                "emailAddress = ${CERTBOT_EMAIL}" \
                                ) \
                -key "/etc/letsencrypt/live/${cert_name}/privkey.pem" \
                -out "${LOCAL_CA_DIR}/${cert_name}.csr"

    # Sign the certificate with all the alternative names appended to the
    # appropriate section of the config file.
    info "Using local CA to sign certificate for '${cert_name}'"
    openssl ca -batch -notext \
               -config <(printf "%s\n" \
                         "${openssl_cnf}" \
                         "[alt_names]" \
                         "$@" \
                         ) \
               -extensions server_cert \
               -in "${LOCAL_CA_DIR}/${cert_name}.csr" \
               -out "/etc/letsencrypt/live/${cert_name}/cert.pem"

    # Create the other two files necessary to match what certbot produces.
    cp "${LOCAL_CA_CRT}" "/etc/letsencrypt/live/${cert_name}/chain.pem"
    cat "/etc/letsencrypt/live/${cert_name}/cert.pem" > "/etc/letsencrypt/live/${cert_name}/fullchain.pem"
    cat "/etc/letsencrypt/live/${cert_name}/chain.pem" >> "/etc/letsencrypt/live/${cert_name}/fullchain.pem"

    # Cleanup after ourselves.
    rm "${LOCAL_CA_DIR}/${cert_name}.csr"
}

# Begin with making sure that we have all the files necessary for a local CA.
# This is really cheap to do, so I think it is fine that we check this every
# time this script is invoked.
generate_ca

# Go through all .conf files and find all cert names for which we should create
# certificate requests and have them signed.
for conf_file in /etc/nginx/conf.d/*.conf*; do
    for cert_name in $(parse_cert_names "${conf_file}"); do
        # Find all 'server_names' in this .conf file and assemble the list of
        # domains to be included in the request.
        ip_count=0
        dns_count=0
        alt_names=()
        for server_name in $(parse_server_names "${conf_file}"); do
            if [[ "${server_name}" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                # See if the alt name looks like an IPv4 address.
                ip_count=$((${ip_count} + 1))
                alt_names+=("IP.${ip_count}=${server_name}")
            elif [[ "${server_name,,}" =~ ^([a-f0-9]{1,4})?:([a-f0-9:]*):.*?$ ]]; then
                # This is a dirty check to see if it looks like an IPv6 address,
                # can easily be fooled but works for us right now.
                ip_count=$((${ip_count} + 1))
                alt_names+=("IP.${ip_count}=${server_name}")
            else
                # Else we suppose this is a valid DNS name.
                dns_count=$((${dns_count} + 1))
                alt_names+=("DNS.${dns_count}=${server_name}")
            fi
        done

        # Hand over all the info required for the certificate request, and
        # let the local CA handle the rest.
        if ! get_certificate "${cert_name}" "${alt_names[@]}"; then
            error "Local CA failed for '${cert_name}'. Check the logs for details."
        fi
    done
done

# After trying to sign all of the certificates, auto enable any configs that we
# did indeed succeed with.
auto_enable_configs

# Finally, tell Nginx to reload the configs.
nginx -s reload
