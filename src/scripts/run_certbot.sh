#!/bin/bash

# Source in util.sh so we can have our nice tools
. $(cd $(dirname $0); pwd)/util.sh

# We require an email to register the SSL certificate
if [ -z "$CERTBOT_EMAIL" ]; then
    error "CERTBOT_EMAIL environment variable undefined; certbot will do nothing"
    exit 1
fi

exit_code=0
# Go through the .conf files and loop over every domain we can find
for conf_file in /etc/nginx/conf.d/*.conf*; do
    for primary_domain in $(parse_primary_domains $conf_file); do
        if is_renewal_required $primary_domain; then
            # Renewal required for this domain!
            # The last one happened over a week ago (or never)

            # At minimum we will make a request for the primary domain
            domain_request="-d $primary_domain"
            
            # Find all 'server_names' in this .conf file
            for server_name in $(parse_server_names $conf_file); do
                if [ -n "$server_name" ]; then
                    # String is not empty
                    tmp="-d $server_name"
                    if [[ ! $domain_request =~ $tmp ]]; then
                        # This server name was not found in the domain request, 
                        # append it...
                        domain_request="$domain_request -d $server_name"
                    fi
                fi
            done 

            if ! get_certificate $primary_domain $CERTBOT_EMAIL "$domain_request"; then
                error "Certbot failed for $primary_domain. Check the logs for details."
                exit_code=1
            fi
        else
            echo "Not running certbot for $primary_domain; last renewal happened just recently."
        fi
    done
done

# After trying to get all our certificates, auto enable any configs that we
# did indeed get certificates for.
auto_enable_configs

# Finally, tell Nginx to reload the configs
nginx -s reload

exit $exit_code
