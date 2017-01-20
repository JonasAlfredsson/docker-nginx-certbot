error() {
    (set +x; tput -Tscreen bold
    tput -Tscreen setaf 1
    echo $*
    tput -Tscreen sgr0) >&2
}

if [ -z "$DOMAINS" ]; then
    error "DOMAINS environment variable undefined; certbot will do nothing"
    exit 1
fi
if [ -z "$EMAIL" ]; then
    error "EMAIL environment variable undefined; certbot will do nothing"
    exit 1
fi
echo "Running certbot for domains $DOMAINS for user $EMAIL..."

get_certificate() {
    # Gets the certificate for the domain(s) CERT_DOMAINS (a comma separated list)
    # The certificate will be named after the first domain in the list
    # To work, the following variables must be set:
    # - CERT_DOMAINS : comma separated list of domains
    # - EMAIL

    local d=${CERT_DOMAINS//,*/} # read first domain
    echo "Getting certificate for $CERT_DOMAINS"
    certbot certonly --agree-tos --keep -n --text --email $EMAIL --server \
        https://acme-v01.api.letsencrypt.org/directory -d $CERT_DOMAINS \
        --standalone --standalone-supported-challenges http-01 --debug
    ec=$?
    echo "certbot exit code $ec"
    if [ $ec -eq 0 ]; then
        error "Certificates for $CERT_DOMAINS can be found in /etc/letsencrypt/live/$d"
    else
        error "Cerbot failed for $CERT_DOMAINS. Check the logs for details."
        exit 1
    fi
}

exit_code=0
set -x
for d in $DOMAINS; do
    CERT_DOMAINS=$d
    if ! get_certificate; then
        exit_code=1
    fi
done
exit $exit_code
