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
        sed -n -e 's&^\s*ssl_certificate_key\s*\/etc/letsencrypt/live/\(.*\)/privkey.pem;&\1&p' $conf_file | xargs echo | tr ' ' ','
    done
}

# Given a config file path, spit out all the ssl_certificate_key file paths
parse_keyfiles() {
    sed -n -e 's&^\s*ssl_certificate_key\s*\(.*\);&\1&p' "$1"
}

# Given a config file path, return 0 if all keyfiles exist (or there are no
# keyfiles), return 1 otherwise
keyfiles_exist() {
    for keyfile in $(parse_keyfiles $1); do
        if [ ! -f $keyfile ]; then
            echo "Couldn't find keyfile $keyfile for $1"
            return 1
        fi
    done
    return 0
}

# Helper function that sifts through /etc/nginx/conf.d/, looking for configs
# that don't have their keyfiles yet, and disabling them through renaming
auto_enable_configs() {
    for conf_file in /etc/nginx/conf.d/*.conf*; do
        if keyfiles_exist $conf_file; then
            if [ ${conf_file##*.} = nokey ]; then
                echo "Found all the keyfiles for $conf_file, enabling..."
                mv $conf_file ${conf_file%.*}
            fi
        else
            if [ ${conf_file##*.} = conf ]; then
                echo "Keyfile(s) missing for $conf_file, disabling..."
                mv $conf_file $conf_file.nokey
            fi
        fi
    done
}

# Helper function to ask certbot for the given domain(s).  Must have defined the
# EMAIL environment variable, to register the proper support email address.
get_certificate() {
    echo "Getting certificate for domain $1 on behalf of user $2"
    certbot certonly --agree-tos --keep -n --text --email $2 --server \
        https://acme-v01.api.letsencrypt.org/directory -d $1 --http-01-port 1337 \
        --standalone --standalone-supported-challenges http-01 --debug
}
