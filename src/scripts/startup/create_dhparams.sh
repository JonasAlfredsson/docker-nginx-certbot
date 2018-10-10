#!/bin/sh

# Source "util.sh" so we can have our nice tools
. $(cd $(dirname $0); pwd)/../util.sh

# Find any mentions of Diffie-Hellman parameters and create them if missing
handle_dhparams() {
    for file in $(parse_dhparams $1); do
        if [ ! -f $file ]; then
            echo "Couldn't find the dhparam file $file; creating it..."
            create_dhparam $file
        fi
    done
}

for conf_file in /etc/nginx/conf.d/*.conf*; do
    handle_dhparams $conf_file
done