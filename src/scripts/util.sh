#!/bin/sh

# Helper function to output error messages to STDERR, with red text
error() {
    (set +x; tput -Tscreen bold
    tput -Tscreen setaf 1
    echo $*
    tput -Tscreen sgr0) >&2
}

# Helper function that sifts through /etc/nginx/conf.d/, looking for lines that
# contain ssl_certificate_key, and try to find domain names in them.  We accept
# a very restricted set of keys: Each key must map to a set of concrete domains
# (no wildcards) and each keyfile will be stored at the default location of
# /etc/letsencrypt/live/<primary_domain_name>/privkey.pem
parse_domains() {
    # For each configuration file in /etc/nginx/conf.d/*.conf*
    for conf_file in /etc/nginx/conf.d/*.conf*; do
        sed -n -e 's&^\s*ssl_certificate_key\s*\/etc/letsencrypt/live/\(.*\)/privkey.pem;&\1&p' $conf_file | xargs echo
    done
}

# Return all the "ssl_certificate_key" file paths
parse_keyfiles() {
    sed -n -e 's&^\s*ssl_certificate_key\s*\(.*\);&\1&p' "$1"
}

# Return all the "ssl_certificate" file paths
parse_fullchains() {
    sed -n -e 's&^\s*ssl_certificate \s*\(.*\);&\1&p' "$1"
}

# Return all the "ssl_trusted_certificate" file paths
parse_chains() {
    sed -n -e 's&^\s*ssl_trusted_certificate\s*\(.*\);&\1&p' "$1"
}

# Return all the "dhparam" file paths
parse_dhparams() {
    sed -n -e 's&^\s*ssl_dhparam\s*\(.*\);&\1&p' "$1"
}

# Given a config file path, return 0 if all ssl related files exist (or there 
# are no files needed to be found), return 1 otherwise.
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
                echo "Important file(s) for $conf_file are missing, disabling..."
                mv $conf_file $conf_file.nokey
            fi
        fi
    done
}

# Helper function to ask certbot for the given domain(s).  Must have defined the
# EMAIL environment variable, to register the proper support email address.
get_certificate() {
    echo "Getting certificate for domain $1 on behalf of user $2"
    PRODUCTION_URL='https://acme-v01.api.letsencrypt.org/directory'
    STAGING_URL='https://acme-staging.api.letsencrypt.org/directory'

    if [ "${IS_STAGING}" = "1" ]; then
        letsencrypt_url=$STAGING_URL
        echo "Staging ..."
    else
        letsencrypt_url=$PRODUCTION_URL
        echo "Production ..."
    fi

    echo "running certbot ... $letsencrypt_url $1 $2"
    certbot certonly --agree-tos --keep -n --text --email $2 --server \
        $letsencrypt_url -d $1 --http-01-port 1337 \
        --standalone --preferred-challenges http-01 --debug
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
