echo "Running certbot for domains $DOMAINS"

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
        echo "Certificates for $CERT_DOMAINS can be found in /etc/letsencrypt/live/$d"
    else
        echo "Cerbot failed for $CERT_DOMAINS. Check the logs for details."
    fi
}

set -x
for d in $DOMAINS
do
  CERT_DOMAINS=$d
  get_certificate
done

