#!/usr/bin/env bash
set -euo pipefail

# Provision Ubuntu with Node.js, Nginx, and open HTTP/HTTPS ports.
# - Installs Node 20 (NodeSource), Nginx, netfilter-persistent
# - Copies example Nginx config to proxy frontend (:5173) and backend (:5174)
# - Enables and starts Nginx
# - Opens iptables ports 80 and 443 and saves rules

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  SUDO="sudo"
else
  SUDO=""
fi

echo "[+] Updating apt index"
$SUDO apt-get update -y

echo "[+] Installing dependencies (curl, gnupg, ca-certificates, lsb-release, software-properties-common)"
$SUDO apt-get install -y curl gnupg ca-certificates lsb-release software-properties-common

echo "[+] Installing Node.js 20 (NodeSource)"
curl -fsSL https://deb.nodesource.com/setup_20.x | $SUDO -E bash -
$SUDO apt-get install -y nodejs

echo "[+] Installing Nginx"
$SUDO apt-get install -y nginx

echo "[+] Installing netfilter-persistent (for saving iptables rules)"
$SUDO apt-get install -y netfilter-persistent iptables-persistent || true

echo "[+] Installing PostgreSQL"
$SUDO apt-get install -y postgresql postgresql-contrib

echo "[+] Enabling and starting PostgreSQL"
$SUDO systemctl enable --now postgresql

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SRC="$SCRIPT_DIR/../deploy/nginx/scribal.conf"
CONFIG_DST="/etc/nginx/sites-available/scribal"

if [[ ! -f "$CONFIG_SRC" ]]; then
  echo "[!] Nginx config not found at $CONFIG_SRC"
  echo "    Make sure you copied the repo or provide the path to scribal.conf"
  exit 1
fi

echo "[+] Deploying Nginx config to $CONFIG_DST"
$SUDO install -m 644 "$CONFIG_SRC" "$CONFIG_DST"
$SUDO ln -sf "$CONFIG_DST" /etc/nginx/sites-enabled/scribal
$SUDO rm -f /etc/nginx/sites-enabled/default

echo "[+] Testing Nginx configuration"
$SUDO nginx -t

echo "[+] Enabling and starting Nginx"
$SUDO systemctl enable --now nginx

echo "[+] Opening firewall ports 80 and 443 via iptables"
$SUDO iptables -I INPUT 6 -m state --state NEW -p tcp --dport 80 -j ACCEPT || true
$SUDO iptables -I INPUT 6 -m state --state NEW -p tcp --dport 443 -j ACCEPT || true

echo "[+] Saving firewall rules with netfilter-persistent"
$SUDO netfilter-persistent save || true

echo "[✓] Provisioning complete."
echo "    - Nginx proxies http://<your-host>/ to frontend (127.0.0.1:5173)"
echo "    - /api and /socket.io route to backend (127.0.0.1:5174)"
echo "    - PostgreSQL is installed and running locally (connect via unix socket by default)"
echo "    - Edit server_name in /etc/nginx/sites-available/scribal before adding SSL"
