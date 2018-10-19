#!/bin/sh

# Source "util.sh" so we can have our nice tools
. $(cd $(dirname $0); pwd)/util.sh

# Immediately run 'auto_enable_configs' so that nginx is in a runnable state
# This will temporarily disable any misconfigured servers.
auto_enable_configs

# Run any startup scripts
for f in /scripts/startup/*.sh; do
    if [ -x "$f" ]; then
        echo "Running startup script $f"
        $f
    fi
done
echo "Done with startup"

# Instead of trying to run 'cron' or something like that, just sleep and run 'certbot'.
(
sleep 5 # give nginx time to start
while [ true ]; do
    echo "Run certbot!"
    /scripts/run_certbot.sh

    echo "Certbot will now sleep for 1 week..."
    sleep 7d
done
) &

# Start nginx as PID 1
exec nginx -g "daemon off;"
