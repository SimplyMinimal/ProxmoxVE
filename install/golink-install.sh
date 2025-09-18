#!/usr/bin/env bash

# Copyright (c) 2021-2025 community-scripts ORG
# Author: SimplyMinimal
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/tailscale/golink

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y \
  git \
  ca-certificates \
  sqlite3
msg_ok "Installed Dependencies"

setup_go

msg_info "Cloning Golink Repository"
$STD git clone https://github.com/tailscale/golink.git /opt/golink
msg_ok "Cloned Golink Repository"

msg_info "Building Golink"
cd /opt/golink || exit
$STD go mod tidy
$STD go build -o golink ./cmd/golink
chmod +x golink
RELEASE=$(git describe --tags --always 2>/dev/null || echo "main-$(git rev-parse --short HEAD)")
echo "${RELEASE}" >"/opt/${APPLICATION}_version.txt"
msg_ok "Built Golink"

msg_info "Configuring Golink"
mkdir -p /opt/golink/data
cat <<EOF >/opt/golink/.env
# Golink configuration
# Set TS_AUTHKEY environment variable for Tailscale authentication
# Example: TS_AUTHKEY=tskey-auth-your-key-here
# For development/testing without Tailscale, the service will use -dev-listen :8080
EOF
{
  echo "Golink Configuration"
  echo "===================="
  echo "1. For production use with Tailscale:"
  echo "   - Set TS_AUTHKEY in /opt/golink/.env"
  echo "   - Restart the service: systemctl restart golink"
  echo "   - Access via Tailscale network at http://go/"
  echo ""
  echo "2. For development/testing:"
  echo "   - Service runs on port 8080 by default"
  echo "   - Access at http://$(hostname -I | awk '{print $1}'):8080"
  echo ""
  echo "Database location: /opt/golink/data/golink.db"
} >~/golink.creds
msg_ok "Configured Golink"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/golink.service
[Unit]
Description=Golink Private Shortlink Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/golink
ExecStart=/opt/golink/golink -sqlitedb /opt/golink/data/golink.db -dev-listen :8080
EnvironmentFile=-/opt/golink/.env
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now golink
msg_ok "Created Service"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
