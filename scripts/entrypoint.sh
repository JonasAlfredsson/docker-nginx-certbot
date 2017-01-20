#!/bin/bash
/bin/bash /scripts/run_certbot.sh
exec cron -f
