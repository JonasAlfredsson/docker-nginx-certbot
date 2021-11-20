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

# Call other helper functions here to get an associative array of
# cert_name => server_names allowing to know which certificates need to be
# requested
#
# $1: An associative bash array that will contain cert_name => server_names
#     (space-separated) after the call to this function
find_certificates() {
    local -n found_certificates=$1

    parse_config_files_for_certs "/etc/nginx/conf.d/*.conf*" found_certificates
    remove_duplicates found_certificates
    handle_wildcard_conflicts found_certificates
    force_wildcards found_certificates
}

# Parse the configuration files given as first parameters, go through all the server
# blocks to find both the 'ssl_certificate_key' and the 'server_name' entries, and
# aggregate all the findings so a single certificate can be ordered for multiple
# domains if this is desired.
# Each keyfile much be stored at the default location of
# /etc/letsencrypt/live/<cert_name>/privkey.pem, otherwise the server block will
# be ignored. The server name(s) must only contain regular domains and prefixed
# wildcards.
#
# $1: The path (support for wildcards) to match configuration files
# $2: An associative bash array that will contain cert_name => server_names
#     (space-separated) after the call to this function
parse_config_files_for_certs() {
    local -n certs=$2

    for conf_file in $1; do
        # To follow if we are in a server block, and how to match the ending of that
        # server block (we expect equal indentation at the beginning and end)
        local in_server_block=0
        local leading_server_block_spaces=

        # The resources we're looking for, that we will reset between server blocks
        local cert_names=()
        local server_names=()

        local lineno=0
        while IFS="" read -r line || [ -n "$line" ]; do
            lineno=$((lineno + 1))
            if [[ "$line" =~ ^([[:space:]]*)server[[:space:]]*\{ ]]; then
                if [ $in_server_block -eq 1 ]; then
                    error "Matching server block while already in a server block ($conf_file:$lineno)"
                    # Do we want to go to next file, exit or keep parsing ?
                fi
                # We entered a server block, so we'll need to start checking what's up
                in_server_block=1
                leader_server_block_spaces=${BASH_REMATCH[1]}
            elif [ $in_server_block -eq 0 ]; then
                # We are not in a server block, nothing for us to do here, let's skip
                continue
            elif [[ "$line" =~ ^${leading_server_block_spaces}\} ]]; then
                # We add the found certificate names and the corresponding server names,
                # in case it already exists, this will be appended nicely as if it was
                # all in the same server block. In case there was no 'ssl_certificate_key'
                # entry, we can simply ignore it nicely.
                if [ ${#server_names[@]} -eq 0 ]; then
                    error "Missing 'server_name' for server block ($conf_file:$lineno)"
                elif [ ${#cert_names[@]} -gt 0 ]; then
                    for cert_name in "${cert_names[@]}"; do
                        certs["$cert_name"]="${certs["$cert_name"]}${certs["$cert_name"]:+ }${server_names[@]}"
                    done
                fi

                # We are leaving a server block, so we can clean-up behind us
                in_server_block=0
                leadin_server_block_spaces=

                cert_names=()
                server_names=()
            elif [[ "$line" =~ ^[[:space:]]*ssl_certificate_key[[:space:]]*/etc/letsencrypt/live/([^;]*)/privkey.pem[[:space:]]*\; ]]; then
                cert_names+=(${BASH_REMATCH[1]})
            elif [[ "$line" =~ ^[[:space:]]*server_name[[:space:]]*([^\;]*)[[:space:]]*\; ]]; then
                server_names+=(${BASH_REMATCH[1]})
            fi
        done <"$conf_file"
    done
}

# A function to remove duplicates in our associative array of
# cert_name => server_names (space-separated).
#
# $1: The associative bash array containing cert_name => server_names
#     (space-separated), that will be read and updated to remove
#     duplicates
remove_duplicates() {
    local -n certs=$1
    
    for cert_name in "${!certs[@]}"; do
        local server_names=(${certs["$cert_name"]})

        local -A already_seen=()
        local dedupped=()
        for server_name in ${server_names[@]}; do
            if [ -z "${already_seen[$server_name]}" ]; then
                already_seen[$server_name]=1
                dedupped+=($server_name)
            fi
        done

        certs["$cert_name"]="${dedupped[@]}"
    done
}

# A function to handle wildcard conflicts in our associative array of
# cert_name => server_names (space-separated).
#
# $1: The associative bash array containing cert_name => server_names
#     (space-separated), that will be read and updated to remove
#     conflicting server names when one or more wildcards are present
handle_wildcard_conflicts() {
    local -n certs=$1

    for cert_name in "${!certs[@]}"; do
        local server_names=(${certs["$cert_name"]})

        # List all the wildcards in that list, so we know which domains would be in conflict with those
        local wildcards=()
        for server_name in ${server_names[@]}; do
            if [[ "$server_name" =~ ^\*\. ]]; then
                wildcards+=("${server_name#\*.*}")
            fi
        done

        if [ ${#wildcards[@]} -eq 0 ]; then
            continue
        fi

        # Go over the list of domains, and keep only those that don't overlap with one of the wildcards
        local keep_domains=()
        for server_name in ${server_names[@]}; do
            local conflicts_with_wildcard=0
            for wildcard in ${wildcards[@]}; do
                if [[ "$server_name" =~ ^[^.]*\.${wildcard}$ ]] && [[ ! "$server_name" == "*.${wildcard}" ]]; then
                    conflicts_with_wildcard=1
                    break
                fi
            done

            if [ $conflicts_with_wildcard -eq 0 ]; then
                keep_domains+=($server_name)
            fi
        done

        certs["$cert_name"]="${keep_domains[@]}"
    done
}

# This function forces the use of wildcards in certificates when they
# are relevant if:
#  (1) No `no-wildcards` pattern is found in the cert name
# and
#  (2.a) Either the FORCE_WILDCARDS environment variable is set to 1, or
#  (2.b) the `force-wildcards` pattern is found in the cert name
#
# Wildcards will not be provisioned for domains containing less than
# FORCE_WILDCARDS_NDOTS dots (default: 2); e.g. if FORCE_WILDCARDS_NDOTS
# is set to 3, no automated wildcard will be created for *.example.com, but
# some could be created for *.something.example.com.
#
# A wildcard will not be considered relevant if less than 2 server names
# would be covered by it.
#
# $1: The associative bash array containing cert_name => server_names
#     (space-separated), that will be read and updated to remove
#     conflicting server names when one or more wildcards are present
force_wildcards() {
    local -n certs=$1

    for cert_name in "${!certs[@]}"; do
        if [[ "${cert_name,,}" =~ (^|[-.])no-wildcards([-.]|$) ]] || ( [ "${FORCE_WILDCARDS}" != "1" ] && [[ ! "${cert_name,,}" =~ (^|[-.])force-wildcards([-.]|$) ]] ); then
            continue
        fi

        local server_names=(${certs["$cert_name"]})

        # Identify all the wildcards that would be needed to cover all the
        # server names for that certificate
        local -A wildcards=()
        for server_name in ${server_names[@]}; do
            local wildcard=${server_name#*.}
            local dots=${wildcard//[^.]}

            if [ $((${#dots} + 1)) -lt ${FORCE_WILDCARDS_NDOTS:-2} ]; then
                continue
            fi

            wildcards[$wildcard]=$((${wildcards[$wildcard]} + 1))
        done

        declare -p wildcards

        # Go over all the wildcards and remove those that are not covering
        # at least two domains; we don't need to replace anything by a
        # wildcard for those. The ones we keep we will reset to 0, so we can
        # try to keep some sort of hostname ordering when we'll go over the
        # records
        for wildcard in ${!wildcards[@]}; do
            if [ ${wildcards[$wildcard]} -gt 1 ]; then
                wildcards[$wildcard]=0
            else
                unset wildcards[$wildcard]
            fi
        done

        # Now we will go over the server_names, and either keep them if
        # no wildcard will cover them, replace them if a wildcard covers
        # them and they're the first one we encounter for that wildcard,
        # or discard them otherwise
        local reduced_domains=()
        for server_name in ${server_names[@]}; do
            local wildcard=${server_name#*.}
            if [ -n "${wildcards[$wildcard]}" ]; then
                if [ ${wildcards[$wildcard]} -eq 0 ]; then
                    wildcards[$wildcard]=1
                    reduced_domains+=("*.$wildcard")
                fi
            else
                reduced_domains+=("$server_name")
            fi
        done

        certs["$cert_name"]="${reduced_domains[@]}"
    done
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
# This function call those other functions in a slightly obscured way:
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
