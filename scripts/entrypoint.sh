#!/bin/bash

trap "exit" INT TERM
trap "kill 0" EXIT
/scripts/run_certbot.sh && cron -f &
wait
