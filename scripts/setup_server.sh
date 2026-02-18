#!/bin/bash

# NetBoltZ Server Setup Script
# Automates Caddy installation and configuration on Ubuntu
# Usage: bash setup_server.sh [your-domain.com]

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

DOMAIN=${1:-""}

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  ⚡ NetBoltZ Server Setup${NC}"
echo -e "${BLUE}======================================${NC}"

# Update system
echo -e "${GREEN}[1/6] Updating system...${NC}"
sudo apt update && sudo apt upgrade -y

# Install dependencies
echo -e "${GREEN}[2/6] Installing dependencies...${NC}"
sudo apt install -y \
    debian-keyring \
    debian-archive-keyring \
    apt-transport-https \
    curl \
    ufw \
    net-tools

# Install Caddy
echo -e "${GREEN}[3/6] Installing Caddy...${NC}"
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | \
    sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | \
    sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update
sudo apt install caddy -y

# Configure firewall
echo -e "${GREEN}[4/6] Configuring firewall...${NC}"
sudo ufw allow 22/tcp     # SSH
sudo ufw allow 80/tcp     # HTTP
sudo ufw allow 443/tcp    # HTTPS
sudo ufw allow 443/udp    # QUIC (CRITICAL)
sudo ufw --force enable

# Create Caddyfile
echo -e "${GREEN}[5/6] Creating Caddyfile...${NC}"
if [ -n "$DOMAIN" ]; then
    # Production config with real domain
    sudo tee /etc/caddy/Caddyfile > /dev/null <<EOF
$DOMAIN {
    reverse_proxy https://www.youtube.com {
        header_up Host {upstream_hostport}
    }
}
EOF
    echo -e "${GREEN}Domain configured: $DOMAIN${NC}"
else
    # Default config for IP-based access
    sudo tee /etc/caddy/Caddyfile > /dev/null <<EOF
{
    auto_https off
    admin 0.0.0.0:2019
}

:8080 {
    reverse_proxy https://www.youtube.com {
        header_up Host {upstream_hostport}
    }
}
EOF
    echo -e "${GREEN}No domain provided - using HTTP on port 8080${NC}"
    echo -e "${RED}For QUIC support, run again with domain: bash setup_server.sh your-domain.com${NC}"
fi

# Start Caddy
echo -e "${GREEN}[6/6] Starting Caddy...${NC}"
sudo systemctl daemon-reload
sudo systemctl enable caddy
sudo systemctl restart caddy
sudo systemctl status caddy --no-pager

echo ""
echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  ✅ NetBoltZ Setup Complete!${NC}"
echo -e "${BLUE}======================================${NC}"

if [ -n "$DOMAIN" ]; then
    echo -e "Access: ${GREEN}https://$DOMAIN${NC}"
    echo -e "QUIC:   ${GREEN}Enabled (automatic)${NC}"
    echo ""
    echo "Test QUIC:"
    echo "  curl --http3 https://$DOMAIN"
else
    SERVER_IP=$(curl -s ifconfig.me)
    echo -e "Access: ${GREEN}http://$SERVER_IP:8080${NC}"
    echo -e "QUIC:   ${RED}Disabled (need domain)${NC}"
    echo ""
    echo "Get a free domain at: https://freedns.afraid.org"
    echo "Then run: bash setup_server.sh your-subdomain.mooo.com"
fi

echo ""
echo "View logs: sudo journalctl -u caddy -f"
