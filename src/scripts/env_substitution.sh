#!/bin/sh
echo "Running env_substitution.sh"
export ALLOWED_VARS=$(
  echo "$ENVSUBST_VARS" | 
  sed 's/[^,]\+/${&}/g' |  # Wrap each term in ${...}
  tr ',' ','               # Optional: Keep commas (or replace with spaces)
)
find /etc/nginx/user_conf.d/ -follow -type f -printf "%f\n" | while read -r file; 
do  
  FF="$file";
   envsubst "$ALLOWED_VARS" < /etc/nginx/user_conf.d/"${FF}" > /etc/nginx/user.conf.d/"${FF}"

   echo "Replacing ${FF}"
done
nginx -g "daemon off;"