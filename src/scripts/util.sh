#!/bin/bash

# Helper function to output debug messages to STDOUT if the `DEBUG` environment
# variable is set to 1.
#
# $1: String to be printed.
debug() {
    if [ 1 = "${DEBUG}" ]; then
        echo "${1}"
    fi
}

# Helper function to output informational messages to STDOUT.
#
# $1: String to be printed.
info() {
    echo "${1}"
}

# Helper function to output warning messages to STDOUT, with bold yellow text.
#
# $1: String to be printed.
warning() {
    (set +x; tput -Tscreen bold
    tput -Tscreen setaf 3
    echo "${1}"
    tput -Tscreen sgr0)
}

# Helper function to output error messages to STDERR, with bold red text.
#
# $1: String to be printed.
error() {
    (set +x; tput -Tscreen bold
    tput -Tscreen setaf 1
    echo "${1}"
    tput -Tscreen sgr0) >&2
}

# Returns 0 if the parameter is an IPv4 or IPv6 address, 1 otherwise.
# Can be used as `if is_ip "$something"; then`.
#
# $1: the parameter to check if it is an IP address.
is_ip() {
    is_ipv4 "$1" || is_ipv6 "$1"
}

# Returns 0 if the parameter is an IPv4 address, 1 otherwise.
# Can be used as `if is_ipv4 "$something"; then`.
#
# $1: the parameter to check if it is an IPv4 address.
is_ipv4() {
    [[ "$1" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]
}

# Returns 0 if the parameter is an IPv6 address, 1 otherwise.
# Can be used as `if is_ipv6 "$something"; then`.
#
# This comes from the amazing answer from David M. Syzdek
# on stackoverflow: https://stackoverflow.com/a/17871737
#
# $1: the parameter to check if it is an IPv6 address.
is_ipv6() {
    [[ "${1,,}" =~ ^(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))$ ]]
}

# Find lines that contain 'ssl_certificate_key', and try to extract a name from
# each of these file paths. Each keyfile must be stored at the default location
# of /etc/letsencrypt/live/<cert_name>/privkey.pem, otherwise we ignore it since
# it is most likely not a certificate that is managed by certbot.
#
# $1: Path to a Nginx configuration file.
parse_cert_names() {
    sed -n -r -e 's&^\s*ssl_certificate_key\s+\/etc/letsencrypt/live/(.*)/privkey.pem;.*&\1&p' "$1" | xargs -n1 echo | uniq
}

# Nginx will answer to any domain name that is written on the line which starts
# with 'server_name'. A server block may have multiple domain names defined on
# this line, and a config file may have multiple server blocks. This method will
# therefore try to extract all domain names and add them to the certificate
# request being sent. Some things to think about:
# * Wildcard names must use DNS authentication, else the challenge will fail.
# * Possible overlappings. This method will find all 'server_names' in a .conf
#   file inside the conf.d/ folder and attach them to the request. If there are
#   different primary domains in the same .conf file it will cause some weird
#   certificates. Should however work fine but is not best practice.
# * If the following comment "# certbot_domain:<replacement_domain>" is present
#   the end of the line it will be printed twice in such a fashion that it
#   encapsulate the server names that should be replaced with this one instead,
#   like this:
#       1. certbot_domain:*.example.com
#       2. certbot_domain:www.example.com
#       3. certbot_domain:sub.example.com
#       4. certbot_domain:*.example.com
# * Unlike the other similar functions this one will not perform "uniq" on the
#   names, since that would prevent the feature explained above.
#
# $1: Path to a Nginx configuration file.
parse_server_names() {
    sed -n -r -e 's&^\s*server_name\s+([^;]*);\s*#?(\s*certbot_domain:[^[:space:]]+)?.*$&\2 \1 \2&p' "$1" | xargs -n1 echo
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
# This function calls the following functions in the specified order:
#  - parse_keyfiles
#  - parse_fullchains
#  - parse_chains
#  - parse_dhparams
#
# $1: Path to a Nginx configuration file.
allfiles_exist() {
    local all_exist=0
    for type in keyfile fullchain chain dhparam; do
        for path in $(parse_"${type}"s "$1"); do
            if [[ "${path}" == data:* ]]; then
                debug "Ignoring ${type} path starting with 'data:' in '${1}'"
            elif [[ "${path}" == engine:* ]]; then
                debug "Ignoring ${type} path starting with 'engine:' in '${1}'"
            elif [ ! -f "${path}" ]; then
                warning "Could not find ${type} file '${path}' in '${1}'"
                all_exist=1
            fi
        done
    done

    return ${all_exist}
}

# Parse the configuration file to find all the 'ssl_certificate_key' and the
# 'server_name' entries, and aggregate the findings so a single certificate can
# be ordered for multiple domains if this is desired. Each keyfile must be
# stored in /etc/letsencrypt/live/<cert_name>/privkey.pem, otherwise the
# certificate/file will be ignored.
#
# If you are using the same associative array between each call to this function
# it will make sure that only unique domain names are added to each specific
# key. It will also ignore domain names that start with '~', since these are
# regex and we cannot handle those.
#
# $1: The filepath to the configuration file.
# $2: An associative bash array that will contain cert_name => server_names
#     (space-separated) after the call to this function.
parse_config_file() {
    local conf_file=${1}
    local -n certs=${2} # Basically a pointer to the array sent in via $2.
    debug "Parsing config file '${conf_file}'"

    # Begin by checking if there are any certificates managed by us in the
    # config file.
    local cert_names=()
    for cert_name in $(parse_cert_names "${conf_file}"); do
        cert_names+=("${cert_name}")
    done
    if [ ${#cert_names[@]} -eq 0 ]; then
        debug "Found no valid certificate declarations in '${conf_file}'; skipping it"
        return
    fi

    # Then we look for all the possible server names present in the file.
    local server_names=()
    local replacement_domain=""
    for server_name in $(parse_server_names "${conf_file}"); do
        # Check if the current server_name line has a comment that tells us to
        # use a different domain name instead when making the request.
        if [[ "${server_name}" =~ certbot_domain:(.*) ]]; then
            if [ "${server_name}" == "certbot_domain:${replacement_domain}" ]; then
                # We found the end of the special server names.
                replacement_domain=""
                continue
            fi
            replacement_domain="${BASH_REMATCH[1]}"
            server_names+=("${replacement_domain}")
            continue
        fi
        if [ -n "${replacement_domain}" ]; then
            # Just continue in case we are substituting domains.
            debug "Substituting '${server_name}' with '${replacement_domain}'"
            continue
        fi

        # Ignore regex names, since these are not gracefully handled by this
        # code or certbot.
        if [[ "${server_name}" =~ ~(.*) ]]; then
            debug "Ignoring server name '${server_name}' since it looks like a regex and we cannot handle that"
            continue
        fi

        server_names+=("${server_name}")
    done
    debug "Found the following domain names: ${server_names[*]}"

    # Finally we add the found server names to the certificate names in
    # the associative array.
    for cert_name in "${cert_names[@]}"; do
        if ! [ ${certs["${cert_name}"]+_} ]; then
            debug "Adding new key '${cert_name}' in array"
            certs["${cert_name}"]=""
        else
            debug "Appending to already existing key '${cert_name}'"
        fi
        # Make sure we only add unique entries every time.
        # This invocation of awk works like 'sort -u', but preserves order. This
        # set the first 'server_name' entry as the first '-d' domain artgument
        # for the certbot command. This domain will be your Common Name on the
        # certificate.
        # stackoverflow on this awk usage: https://stackoverflow.com/a/45808487
        certs["${cert_name}"]="$(echo ${certs["${cert_name}"]} "${server_names[@]}" | xargs -n1 echo | awk '!a[$0]++' | tr '\n' ' ')"
    done
}

# Creates symlinks from /etc/nginx/conf.d/ to all the files found inside
# /etc/nginx/user_conf.d/. This will also remove broken links.
symlink_user_configs() {
    debug "Creating symlinks to any files found in /etc/nginx/user_conf.d/"

    # Remove any broken symlinks that point back to the user_conf.d/ folder.
    while IFS= read -r -d $'\0' symlink; do
        info "Removing broken symlink '${symlink}' to '$(realpath "${symlink}")'"
        rm "${symlink}"
    done < <(find /etc/nginx/conf.d/ -maxdepth 1 -xtype l -lname '/etc/nginx/user_conf.d/*' -print0)

    # Go through all files and directories in the user_conf.d/ folder and create
    # a symlink to them inside the conf.d/ folder.
    while IFS= read -r -d $'\0' source_file; do
        local symlinks_found=0

        # See if there already exist a symlink to this source file.
        while IFS= read -r -d $'\0' symlink; do
            debug "The file '${source_file}' is already symlinked by '${symlink}'"
            symlinks_found=$((${symlinks_found} + 1))
        done < <(find -L /etc/nginx/conf.d/ -maxdepth 1 -samefile "${source_file}" -print0)

        if [ "${symlinks_found}" -eq "1" ]; then
            # One symlink found, then we have nothing more to do.
            continue
        elif [ "${symlinks_found}" -gt "1" ]; then
            warning "Found more than one symlink to the file '${source_file}' inside '/etc/nginx/conf.d/'"
            continue
        fi

        # No symlinks to this file found, lets create one.
        local link="/etc/nginx/conf.d/$(basename -- ${source_file})"
        info "Creating symlink '${link}' to '${source_file}'"
        ln -s "${source_file}" "${link}"
    done < <(find /etc/nginx/user_conf.d/ -maxdepth 1 -type f -print0)
}

# Helper function that sifts through /etc/nginx/conf.d/, looking for configs
# that don't have their necessary files yet, and disables them until everything
# has been set up correctly. This also activates them afterwards.
auto_enable_configs() {
    for conf_file in /etc/nginx/conf.d/*.conf*; do
        if allfiles_exist "${conf_file}"; then
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
