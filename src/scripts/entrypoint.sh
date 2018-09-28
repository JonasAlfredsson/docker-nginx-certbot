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

last_sync_file="/etc/letsencrypt/last_sync.txt"

if [ ! -e "$last_sync_file" ]; then
    touch "$last_sync_file"

    # run certbot to request all the ssl certs we can find
    echo "Run first time certbot"
    /scripts/run_certbot.sh
fi

one_week_sec=604800

# Instead of trying to run `cron` or something like that, just leep and run `certbot`.
while [ true ]; do
    # Sleep for 1 week
    sleep 604810 &
    SLEEP_PID=$!

    last_sync_sec=$(stat -c %Y "$last_sync_file")
    now_sec=$(date -d now +%s)
    runned_sec=$(( ($now_sec - $last_sync_sec) ))
    is_finshed_week_sec=$(( ($one_week_sec - $runned_sec) ))

    echo "Not run_certbot.sh"
    if [ $is_finshed_week_sec -lt 0 ]; then
        # recreate the file
        touch "$last_sync_file"

        # re-run certbot
        echo "Run certbot"
        /scripts/run_certbot.sh
    fi

    # Wait on sleep so that when we get ctrl-c'ed it kills everything due to our trap
    wait "$SLEEP_PID"
done
