echo "Running certbot for domains $DOMAINS"

get_certificate() {
  # Gets the certificate for the domain(s) CERT_DOMAINS (a comma separated list)
  # The certificate will be named after the first domain in the list
  # To work, the following variables must be set:
  # - CERT_DOMAINS : comma separated list of domains
  # - EMAIL
  # - CONCAT
  # - args

  local d=${CERT_DOMAINS//,*/} # read first domain
  echo "Getting certificate for $CERT_DOMAINS"
  certbot certonly --agree-tos --renew-by-default -n \
  --text --server https://acme-v01.api.letsencrypt.org/directory \
  --email $EMAIL -d $CERT_DOMAINS $args
  ec=$?
  echo "certbot exit code $ec"
  if [ $ec -eq 0 ]
  then
    if $CONCAT
    then
      # concat the full chain with the private key (e.g. for haproxy)
      cat /etc/letsencrypt/live/$d/fullchain.pem /etc/letsencrypt/live/$d/privkey.pem > /certs/$d.pem
    else
      # keep full chain and private key in separate files (e.g. for nginx and apache)
      cp /etc/letsencrypt/live/$d/fullchain.pem /certs/$d.pem
      cp /etc/letsencrypt/live/$d/privkey.pem /certs/$d.key
    fi
    echo "Certificate obtained for $CERT_DOMAINS! Your new certificate - named $d - is in /certs"
  else
    echo "Cerbot failed for $CERT_DOMAINS. Check the logs for details."
  fi
}

args=""
if [ $WEBROOT ]
then
  args=" --webroot -w $WEBROOT"
else
  args=" --standalone --standalone-supported-challenges http-01"
fi

if $DEBUG
then
  args=$args" --debug"
fi

if $SEPARATE
then
  for d in $DOMAINS
  do
    CERT_DOMAINS=$d
    get_certificate
  done
else
  CERT_DOMAINS=${DOMAINS// /,}
  get_certificate
fi
