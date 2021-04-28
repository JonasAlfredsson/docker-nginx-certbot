#!/bin/bash

# Helper function to output informational messages to STDOUT.
#
# $1: String to be printed.
debug() {
    if [ 1 = "${DEBUG}" ]; then
        echo "${1}"
    fi
}

# Helper function to output debug messages to STDOUT if the `DEBUG` environment
# variable is set to 1.
#
# $1: String to be printed.
info() {
    echo "${1}"
}

# Helper function to output error messages to STDERR, with red text.
#
# $1: String to be printed.
error() {
    (set +x; tput -Tscreen bold
    tput -Tscreen setaf 1
    echo "${1}"
    tput -Tscreen sgr0) >&2
}

# Find lines that contain 'ssl_certificate_key', and try to extract a domain
# name from each of these file paths. However, there are some strict rules that
# apply for these keys:
# * Each key must map to a valid domain.
# * No wildcards (not supported by this method of authentication).
# * Each keyfile must be stored at the default location of
#   /etc/letsencrypt/live/<primary_domain_name>/privkey.pem
#
# $1: Path to a Nginx configuration file.
parse_primary_domains() {
    sed -n -r -e 's&^\s*ssl_certificate_key\s+\/etc/letsencrypt/live/(.*)/privkey.pem;.*&\1&p' "$1" | xargs -n1 echo | uniq
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
# $1: Path to a Nginx configuration file.
parse_server_names() {
    sed -n -r -e 's&^\s*server_name\s+(.*);.*&\1&p' "$1" | xargs -n1 echo | uniq
}

# Return all unique "ssl_certificate_key" file paths.
#
# $1: Path to a Nginx configuration file.
parse_keyfiles() {
    sed -n -r -e 's&^\s*ssl_certificate_key\s+(.*);.*&\1&p' "$1" | xargs -n1 echo | uniq
}

# Return all unique "ssl_certificate" file paths.
#
# $1: Path to a Nginx configuration file.
parse_fullchains() {
    sed -n -r -e 's&^\s*ssl_certificate\s+(.*);.*&\1&p' "$1" | xargs -n1 echo | uniq
}

# Return all unique "ssl_trusted_certificate" file paths.
#
# $1: Path to a Nginx configuration file.
parse_chains() {
    sed -n -r -e 's&^\s*ssl_trusted_certificate\s+(.*);.*&\1&p' "$1" | xargs -n1 echo | uniq
}

# Return all unique "dhparam" file paths.
#
# $1: Path to a Nginx configuration file.
parse_dhparams() {
    sed -n -r -e 's&^\s*ssl_dhparam\s+(.*);.*&\1&p' "$1" | xargs -n1 echo | uniq
}

# Given a config file path, return 0 if all SSL related files exist (or there
# are no files needed to be found). Return 1 otherwise (i.e. error exit code).
#
# $1: Path to a Nginx configuration file.
allfiles_exist() {
    local all_exist=0
    for type in keyfile fullchain chain dhparam; do
        for path in $(parse_"${type}"s $1); do
            if [[ "${path}" == data:* ]]; then
                debug "Ignoring ${type} path starting with 'data:' in '${1}'"
            elif [[ "${path}" == engine:* ]]; then
                debug "Ignoring ${type} path starting with 'engine:' in '${1}'"
            elif [ ! -f "${path}" ]; then
                error "Could not find ${type} file '${path}' in '${1}'"
                all_exist=1
            fi
        done
    done

    return ${all_exist}
}

# Helper function that sifts through /etc/nginx/conf.d/, looking for configs
# that don't have their necessary files yet, and disables them until everything
# has been set up correctly. This also activates them afterwards.
auto_enable_configs() {
    for conf_file in /etc/nginx/conf.d/*.conf*; do
        if allfiles_exist ${conf_file}; then
            if [ "${conf_file##*.}" = "nokey" ]; then
                info "Found all the necessary files for '${conf_file}', enabling..."
                mv "${conf_file}" "${conf_file%.*}"
            fi
        else
            if [ "${conf_file##*.}" = "conf" ]; then
                error "Important file(s) for '${conf_file}' are missing, disabling..."
                mv "${conf_file}" "${conf_file}.nokey"
            fi
        fi
    done
}
