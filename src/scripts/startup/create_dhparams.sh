#!/bin/bash

# Source "util.sh" so we can have our nice tools.
. $(cd $(dirname $0); pwd)/../util.sh

# Find any mentions of Diffie-Hellman parameters and create them if missing.
files_created=0
for conf_file in /etc/nginx/conf.d/*.conf*; do
    for dh_file in $(parse_dhparams $conf_file); do
        if [ ! -f $dh_file ]; then
            echo "Couldn't find the dhparam file $dh_file; creating it..."
            create_dhparam $dh_file
            chmod 600 $dh_file
            files_created=$((files_created+1))
        fi
    done
done

if [ "$files_created" -eq "0" ]; then
    echo "There was no need to create any dhparam files"
fi
