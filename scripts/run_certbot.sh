for d in $DOMAINS
do
 echo "Running certbot for $d"
 certbot --standalone --standalone-supported-challenges\
  http-01 --agree-tos --renew-by-default\
  --email $EMAIL -d $d certonly
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
 fi
done
