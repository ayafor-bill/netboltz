#!/bin/bash

# NetBoltZ - Dynamic Target Switcher
# Changes proxy target without restarting Caddy
# Requires: Admin API enabled in Caddyfile
# Usage: ./change_target.sh <domain.com> [server-ip]

SERVER=${2:-"localhost"}
DOMAIN=$1

if [ -z "$DOMAIN" ]; then
    echo "Usage: ./change_target.sh domain.com [server-ip]"
    echo "Example: ./change_target.sh facebook.com"
    echo "Example: ./change_target.sh facebook.com 13.245.207.72"
    exit 1
fi

echo "Switching proxy target to: $DOMAIN"

curl -s -X POST http://$SERVER:2019/config/apps/http/servers/srv0/routes/0/handle/0/upstreams/0 \
    -H "Content-Type: application/json" \
    -d "{\"dial\": \"$DOMAIN:443\"}"

if [ $? -eq 0 ]; then
    echo "✅ Target changed to: $DOMAIN"
else
    echo "❌ Failed to change target"
    echo "Make sure Caddy is running with admin API enabled"
fi
