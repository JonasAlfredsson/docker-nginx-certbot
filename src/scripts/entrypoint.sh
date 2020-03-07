#!/bin/bash

# Helper function to gracefully shut down our child processes when we exit.
clean_exit() {
    for PID in $NGINX_PID $CERTBOT_LOOP_PID; do
        if kill -0 $PID 2>/dev/null; then
            kill -SIGTERM "$PID"
            wait "$PID"
        fi
    done
}

# Make bash listen to the SIGTERM and SIGINT kill signals, and make them trigger
# a normal "exit" command in this script. Then we tell bash to execute the
# "clean_exit" function, seen above, in the case an "exit" command is triggered.
# This is done to give the child processes a chance to exit gracefully.
trap "exit" TERM INT
trap "clean_exit" EXIT

# Source "util.sh" so we can have our nice tools.
. $(cd $(dirname $0); pwd)/util.sh

# Immediately run 'auto_enable_configs' so that Nginx is in a runnable state
# This will temporarily disable any misconfigured servers.
auto_enable_configs

# Run any startup scripts found in the startup/ folder.
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

# Start the certbot certificate management script.
sleep 5 # Give Nginx a little time to start.
$(cd $(dirname $0); pwd)/run_certbot.sh &
CERTBOT_LOOP_PID=$!

# Nginx and the certbot update-loop process are now our children. As a parent
# we will wait for both of their PIDs, and if one of them exits we will follow
# suit and use the same status code as the program which exited first.
wait -n $NGINX_PID $CERTBOT_LOOP_PID
exit $?
