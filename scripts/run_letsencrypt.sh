for d in $DOMAINS
do
 echo "Running letsencrypt for $d"
 letsencrypt --standalone --standalone-supported-challenges\
  http-01 --agree-dev-preview --agree-tos --renew-by-default\
  --server https://acme-v01.api.letsencrypt.org/directory\
  --email $EMAIL -d $d certonly
 ec=$?
 echo "letsencrypt exit code $ec"
 if [ $ec -eq 0 ]
 then
  # For haproxy, you need to concatenate the full chain with the private key
  cat /etc/letsencrypt/live/$d/fullchain.pem /etc/letsencrypt/live/$d/privkey.pem > /certs/$d.pem
  # For nginx or apache, you need both separate files
  # cp /etc/letsencrypt/live/$d/fullchain.pem /certs/$d.pem
  # cp /etc/letsencrypt/live/$d/privkey.pem /certs/$d.key
 fi
done
