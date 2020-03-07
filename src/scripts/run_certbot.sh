#!/bin/bash

# Source in util.sh so we can have our nice tools.
. $(cd $(dirname $0); pwd)/util.sh

# Make sure a renewal interval is set before continuing.
if [ -z "$RENEWAL_INTERVAL" ]; then
    echo "RENEWAL_INTERVAL unset, using default of '8d'"
    RENEWAL_INTERVAL='8d'
fi

# Instead of trying to run 'cron' or something like that, just sleep and
# call on certbot after the defined interval.
while [ true ]; do
    # We require an email to be able to request a certificate.
    if [ -z "$CERTBOT_EMAIL" ]; then
        error "CERTBOT_EMAIL environment variable undefined; certbot will do nothing!"
        exit 1
    fi

    echo "Run certbot!"
    # Go through all .conf files and find all domain names that should be added
    # to the certificate request.
    for conf_file in /etc/nginx/conf.d/*.conf*; do
        for primary_domain in $(parse_primary_domains $conf_file); do
            # At minimum we will make a request for the primary domain.
            domain_request="-d $primary_domain"

            # Find all 'server_names' in this .conf file and add them to the
            # same request.
            for server_name in $(parse_server_names $conf_file); do
                domain_request="$domain_request -d $server_name"
            done

            # Hand over all the info required for the certificate request, and
            # let certbot decide if it is necessary to update the certificate.
            if ! get_certificate $primary_domain $CERTBOT_EMAIL "$domain_request"; then
                error "Certbot failed for $primary_domain. Check the logs for details."
            fi
        done
    done

    # After trying to get all our certificates, auto enable any configs that we
    # did indeed get certificates for.
    auto_enable_configs

    # Finally, tell Nginx to reload the configs.
    nginx -s reload

    # Finally we sleep for the defined time interval before checking the
    # certificates again.
    echo "Certbot will now sleep..."
    sleep "$RENEWAL_INTERVAL"
done

exit 0
