echo "Running certbot for domains $DOMAINS"

# build arg string
args=""
if [ $WEBROOT ]
then
  args=" --webroot -w $WEBROOT"
else
  args=" --standalone --standalone-supported-challenges
  http-01"
fi

if $DEBUG
then
  args=$args" --debug"
fi

for d in $DOMAINS
do
  args=$args" -d $d"
done

certbot certonly --agree-tos --renew-by-default \
--text --server https://acme-v01.api.letsencrypt.org/directory \
--email $EMAIL $args
ec=$?
echo "certbot exit code $ec"
if [ $ec -eq 0 ]
then
  for d in $DOMAINS
  do
    if $CONCAT
    then
      # concat the full chain with the private key (e.g. for haproxy)
      cat /etc/letsencrypt/live/$d/fullchain.pem /etc/letsencrypt/live/$d/privkey.pem > /certs/$d.pem
    else
      # keep full chain and private key in separate files (e.g. for nginx and apache)
      cp /etc/letsencrypt/live/$d/fullchain.pem /certs/$d.pem
      cp /etc/letsencrypt/live/$d/privkey.pem /certs/$d.key
    fi
  done
  echo "Success! Your new certificates are in /certs/"
else
  echo "Cerbot failed. Check the logs for details."
fi
