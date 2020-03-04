#!/bin/sh

# When we get killed, kill all our children (o.O)
trap "exit" INT TERM
trap "kill 0" EXIT

# Source "util.sh" so we can have our nice tools
. $(cd $(dirname $0); pwd)/util.sh

# Immediately run 'auto_enable_configs' so that Nginx is in a runnable state
# This will temporarily disable any misconfigured servers.
auto_enable_configs

# Run any startup scripts
for f in /scripts/startup/*.sh; do
    if [ -x "$f" ]; then
        echo "Running startup script $f"
        $f
    fi
done
echo "Done with startup scripts"

# Start Nginx without its daemon mode (and save its PID).
echo "Starting the Nginx service"
nginx -g "daemon off;" &
NGINX_PID=$!

# Instead of trying to run 'cron' or something like that, just sleep and
# execute the 'certbot' script.
(
sleep 5 # Give nginx a little time to start
while [ true ]; do
    echo "Run certbot!"
    /scripts/run_certbot.sh

    echo "Certbot will now sleep for 8 days..."
    sleep 8d
done
) &

# Nginx and the update process are now our children. As a parent we will wait
# for Nginx, and if it exits we do the same with its status code.
wait $NGINX_PID
exit $?
