#!/bin/sh

# When we get killed, kill all our children
trap "exit" INT TERM
trap "kill 0" EXIT

# Source in util.sh so we can have our nice tools
. $(cd $(dirname $0); pwd)/util.sh

# Immediately run auto_enable_configs so that nginx is in a runnable state
auto_enable_configs

# Start up nginx, save PID so we can reload config inside of run_certbot.sh
nginx -g "daemon off;" &
export NGINX_PID=$!

# Lastly, run startup scripts
for f in /scripts/startup/*.sh; do
    if [ -x "$f" ]; then
        echo "Running startup script $f"
        $f
    fi
done
echo "Done with startup"

last_renewal_file="/etc/letsencrypt/last_renewal.txt"

# Instead of trying to run `cron` or something like that, just sleep and run `certbot`.
while [ true ]; do
    if is_renewal_required $last_renewal_file; then
        # Recreate the file to persist the last renewal timestamp
        touch "$last_renewal_file"

        # Run certbot to request all the ssl certs we can find
        echo "Run certbot"
        /scripts/run_certbot.sh
    else
        echo "Not run certbot"
    fi

    # Sleep for 1 week
    sleep 604810 &
    SLEEP_PID=$!

    # Wait on sleep so that when we get ctrl-c'ed it kills everything due to our trap
    wait "$SLEEP_PID"
done
