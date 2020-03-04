#!/bin/sh

# Helper function to output error messages to STDERR, with red text.
error() {
    (set +x; tput -Tscreen bold
    tput -Tscreen setaf 1
    echo $*
    tput -Tscreen sgr0) >&2
}

# This method may take an extremely long time to complete, be patient.
# It should be possible to use the same dhparam file for all sites, just specify
# the same file path under the "ssl_dhparam" parameter in the Nginx server
# config. The file should be stored somewhere under /etc/letsencrypt/dhparams/
# to ensure persistence between restarts.
create_dhparam() {
    if [ -z "$DHPARAM_SIZE" ]; then
        echo "DHPARAM_SIZE unset, using default of 2048 bits"
        DHPARAM_SIZE=2048
    fi

    echo "
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %                        ATTENTION!                       %
    %                                                         %
    % This script will now create a $DHPARAM_SIZE bit Diffie-Hellman   %
    % parameter to use during the SSL handshake.              %
    %                                                         %
    % >>>>>      This MIGHT take a VERY long time!      <<<<< %
    %    (Took 65 minutes for 4096 bit on an old 3GHz CPU)    %
    %                                                         %
    % However, there is some randomness involved so it might  %
    % be both faster or slower for you. 2048 is secure enough %
    % for today and quite fast to generate. These files will  %
    % only have to be created once so please be patient.      %
    % A message will be displayed when this process finishes. %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    "
    echo "Output file > $1"
    openssl dhparam -out $1 $DHPARAM_SIZE
    echo "
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % >>>>>   Diffie-Hellman parameter creation done!   <<<<< %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    "
}

# Find lines that contain 'ssl_certificate_key', and try to extract a domain
# name from each of these file paths. However, there are some strict rules that
# apply for these keys:
# * Each key must map to a valid domain.
# * No wildcards (not supported by this method of authentication).
# * Each keyfile must be stored at the default location of
#   /etc/letsencrypt/live/<primary_domain_name>/privkey.pem
#
parse_primary_domains() {
    sed -n -e 's&^\s*ssl_certificate_key\s*\/etc/letsencrypt/live/\(.*\)/privkey.pem;&\1&p' "$1" | xargs -n1 echo | uniq
}

# Nginx will answer to any domain name that is written on the line which starts
# with 'server_name'. A server block may have multiple domain names defined on
# this line, and a config file may have multiple server blocks. This method will
# therefore try to extract all unique domain names and add them to the
# certificate request being sent. Some things to think about:
# * No wildcard names. They are not supported by the authentication method used
#   in this script and will most likely fail by certbot.
# * Possible overlappings. This method will find all 'server_names' in a .conf
#   file inside the conf.d/ folder and attach them to the request. If there are
#   different primary domains in the same .conf file it will cause some weird
#   certificates. Should however work fine but is not best practice.
#
parse_server_names() {
    sed -n -e 's&^\s*server_name \s*\(.*\);&\1&p' "$1" | xargs -n1 echo | uniq
}

# Return all unique "ssl_certificate_key" file paths.
parse_keyfiles() {
    sed -n -e 's&^\s*ssl_certificate_key\s*\(.*\);&\1&p' "$1" | xargs -n1 echo | uniq
}

# Return all unique "ssl_certificate" file paths.
parse_fullchains() {
    sed -n -e 's&^\s*ssl_certificate \s*\(.*\);&\1&p' "$1" | xargs -n1 echo | uniq
}

# Return all unique "ssl_trusted_certificate" file paths.
parse_chains() {
    sed -n -e 's&^\s*ssl_trusted_certificate\s*\(.*\);&\1&p' "$1" | xargs -n1 echo | uniq
}

# Return all unique "dhparam" file paths.
parse_dhparams() {
    sed -n -e 's&^\s*ssl_dhparam\s*\(.*\);&\1&p' "$1" | xargs -n1 echo | uniq
}

# Given a config file path, return 0 if all SSL related files exist (or there
# are no files needed to be found). Return 1 otherwise (i.e. error exit code).
allfiles_exist() {
    all_exist=0
    for type in keyfile fullchain chain dhparam; do
        for file in $(parse_"$type"s $1); do
            if [ ! -f $file ]; then
                error "Couldn't find $type $file for $1"
                all_exist=1
            fi
        done
    done

    return $all_exist
}

# Helper function that sifts through /etc/nginx/conf.d/, looking for configs
# that don't have their necessary files yet, and disables them until everything
# has been set up correctly. This also activates them afterwards.
auto_enable_configs() {
    for conf_file in /etc/nginx/conf.d/*.conf*; do
        if allfiles_exist $conf_file; then
            if [ ${conf_file##*.} = nokey ]; then
                echo "Found all the necessary files for $conf_file, enabling..."
                mv $conf_file ${conf_file%.*}
            fi
        else
            if [ ${conf_file##*.} = conf ]; then
                error "Important file(s) for $conf_file are missing, disabling..."
                mv $conf_file $conf_file.nokey
            fi
        fi
    done
}

# Helper function to ask certbot for the given domain(s). The CERTBOT_EMAIL
# environment variable must be defined, so that Let's Encrypt may contact you
# in case of security issues.
get_certificate() {
    echo "Getting certificate for domain $1 on behalf of user $2"
    PRODUCTION_URL='https://acme-v02.api.letsencrypt.org/directory'
    STAGING_URL='https://acme-staging-v02.api.letsencrypt.org/directory'

    if [ "${STAGING}" = "1" ]; then
        letsencrypt_url=$STAGING_URL
        echo "Using staging environment..."
    else
        letsencrypt_url=$PRODUCTION_URL
        echo "Using production environment..."
    fi

    if [ -z "$RSA_KEY_SIZE" ]; then
        echo "RSA_KEY_SIZE unset, defaulting to 2048."
        RSA_KEY_SIZE=2048
    fi

    echo "Running certbot... $letsencrypt_url $1 $2"
    certbot certonly \
        --agree-tos --keep -n --text \
        -a webroot --webroot-path=/var/www/letsencrypt \
        --rsa-key-size $RSA_KEY_SIZE \
        --preferred-challenges http-01 \
        --email $2 \
        --server $letsencrypt_url \
        --cert-name $1 \
        $3 \
        --debug
}

# Given a domain name, return true if a renewal is required (last renewal
# ran over a week ago or never happened yet), otherwise return false.
is_renewal_required() {
    # If the file does not exist assume a renewal is required
    last_renewal_file="/etc/letsencrypt/live/$1/privkey.pem"
    [ ! -e "$last_renewal_file" ] && return;

    # If the file exists, check if the last renewal was more than a week ago
    one_week_sec=604800
    now_sec=$(date -d now +%s)
    last_renewal_sec=$(stat -c %Y "$last_renewal_file")
    last_renewal_delta_sec=$(( ($now_sec - $last_renewal_sec) ))
    is_finshed_week_sec=$(( ($one_week_sec - $last_renewal_delta_sec) ))
    [ $is_finshed_week_sec -lt 0 ]
}
