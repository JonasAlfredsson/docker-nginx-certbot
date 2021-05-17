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
