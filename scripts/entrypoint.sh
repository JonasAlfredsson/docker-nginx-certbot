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

# Next, run certbot to request all the ssl certs we can find
/scripts/run_certbot.sh

# Lastly, run startup scripts
for f in /scripts/startup/*.sh; do
    if [[ -x "$f" ]]; then
        echo "Running startup script $f"
        $f
    fi
done
echo "Done with startup"

now=$(date)
last_sync_file="/etc/letsencrypt/last_sync.txt"

if [[ ! -e "$last_sync_file" ]]; then
    mkdir -p /Scripts
    touch "$last_sync_file"
fi

last_sync=$(stat -c %y "$last_sync_file")
updated_days=$(( ($(date -d now +%s) - $(date -d last_sync +%s) )/(60*60*24) ))

# Instead of trying to run `cron` or something like that, just leep and run `certbot`.
while [ true ]; do
    # Sleep for 1 week
    sleep 604800 &
    SLEEP_PID=$!

    # re-run certbot
    /scripts/run_certbot.sh

    # Wait on sleep so that when we get ctrl-c'ed it kills everything due to our trap
    wait "$SLEEP_PID"
done
