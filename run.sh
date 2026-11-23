#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Deploiement des serveurs ==="

cd "$SCRIPT_DIR/serveur-apache"
sudo ./deploy.sh

cd "$SCRIPT_DIR/serveur-tomcat"
sudo ./deploy.sh

echo ""
echo "=== Deploiement HAProxy (Round Robin) ==="

cd "$SCRIPT_DIR"
sudo haproxy -c -f haproxy.cfg
sudo cp haproxy.cfg /etc/haproxy/haproxy.cfg
sudo haproxy -c -f /etc/haproxy/haproxy.cfg
sudo systemctl restart haproxy
sudo systemctl enable haproxy

echo ""
echo "=== Services actifs ==="
echo "  Load Balancer (Round Robin) : http://localhost:8082"
echo "  Statistiques HAProxy        : http://localhost:8083"
echo "  Admin HAProxy (web)         : http://localhost:4000  (lancer: python3 haproxy-admin/server.py)"
echo ""
echo "=== Pour tester la replication PostgreSQL ==="
echo "  sudo ./bdd/test_replication.sh"
