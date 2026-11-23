#!/usr/bin/env bash
set -euo pipefail

# ==========================================================
# Test de replication PostgreSQL Master (5432) -> Slave (5433)
# ==========================================================

MASTER_PORT=5432
SLAVE_PORT=5433
DB_NAME="postgres"
TABLE_NAME="test_replication"
TEST_ID="test_$(date +%s)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}[OK]${NC} $1"; }
fail() { echo -e "${RED}[ECHEC]${NC} $1"; }
info() { echo -e "${YELLOW}[INFO]${NC} $1"; }

echo "=========================================="
echo " Test de replication PostgreSQL"
echo " Master: port $MASTER_PORT"
echo " Slave:  port $SLAVE_PORT"
echo "=========================================="
echo ""

# ----- Test 1: Connexion au Master -----
info "Test 1/5 - Connexion au Master (port $MASTER_PORT)..."
if sudo -u postgres psql -p "$MASTER_PORT" -d "$DB_NAME" -c "SELECT 1;" > /dev/null 2>&1; then
    pass "Connexion au Master reussie."
else
    fail "Impossible de se connecter au Master."
    exit 1
fi

# ----- Test 2: Connexion au Slave -----
info "Test 2/5 - Connexion au Slave (port $SLAVE_PORT)..."
if sudo -u postgres psql -p "$SLAVE_PORT" -d "$DB_NAME" -c "SELECT 1;" > /dev/null 2>&1; then
    pass "Connexion au Slave reussie."
else
    fail "Impossible de se connecter au Slave."
    exit 1
fi

# ----- Test 3: Verification du role de replication -----
info "Test 3/5 - Verification des roles (Master=primary, Slave=standby)..."

MASTER_RECOVERY=$(sudo -u postgres psql -p "$MASTER_PORT" -d "$DB_NAME" -t -A -c "SELECT pg_is_in_recovery();")
SLAVE_RECOVERY=$(sudo -u postgres psql -p "$SLAVE_PORT" -d "$DB_NAME" -t -A -c "SELECT pg_is_in_recovery();")

if [ "$MASTER_RECOVERY" = "f" ]; then
    pass "Master est bien en mode primary."
else
    fail "Master n'est pas en mode primary (pg_is_in_recovery=$MASTER_RECOVERY)."
    exit 1
fi

if [ "$SLAVE_RECOVERY" = "t" ]; then
    pass "Slave est bien en mode standby."
else
    fail "Slave n'est pas en mode standby (pg_is_in_recovery=$SLAVE_RECOVERY)."
    exit 1
fi

# ----- Test 4: Insertion sur Master et verification sur Slave -----
info "Test 4/5 - Test de replication des donnees..."

sudo -u postgres psql -p "$MASTER_PORT" -d "$DB_NAME" -c "
    CREATE TABLE IF NOT EXISTS $TABLE_NAME (
        id SERIAL PRIMARY KEY,
        nom VARCHAR(100),
        message VARCHAR(255),
        created_at TIMESTAMP DEFAULT NOW()
    );
" > /dev/null 2>&1

sudo -u postgres psql -p "$MASTER_PORT" -d "$DB_NAME" -c "
    INSERT INTO $TABLE_NAME (nom, message)
    VALUES ('$TEST_ID', 'Replication test $(date +%Y-%m-%d\ %H:%M:%S)');
" > /dev/null 2>&1

info "Donnee inseree sur le Master. Attente de la propagation (3s)..."
sleep 3

SLAVE_COUNT=$(sudo -u postgres psql -p "$SLAVE_PORT" -d "$DB_NAME" -t -A -c "
    SELECT COUNT(*) FROM $TABLE_NAME WHERE nom = '$TEST_ID';
")

if [ "$SLAVE_COUNT" -ge 1 ]; then
    pass "Replication OK: la donnee '$TEST_ID' est presente sur le Slave."
else
    fail "Replication ECHOUEE: la donnee '$TEST_ID' n'est pas sur le Slave."
    exit 1
fi

# ----- Test 5: Verification du statut de replication WAL -----
info "Test 5/5 - Verification du streaming WAL..."

WAL_SENDERS=$(sudo -u postgres psql -p "$MASTER_PORT" -d "$DB_NAME" -t -A -c "
    SELECT count(*) FROM pg_stat_replication WHERE state = 'streaming';
")

if [ "$WAL_SENDERS" -ge 1 ]; then
    pass "Streaming WAL actif ($WAL_SENDERS sender(s) connecte(s))."
else
    fail "Aucun WAL sender en mode streaming."
    exit 1
fi

# ----- Nettoyage -----
info "Nettoyage des donnees de test..."
sudo -u postgres psql -p "$MASTER_PORT" -d "$DB_NAME" -c "
    DELETE FROM $TABLE_NAME WHERE nom = '$TEST_ID';
" > /dev/null 2>&1

echo ""
echo "=========================================="
echo -e " ${GREEN}Tous les tests sont passes avec succes.${NC}"
echo "=========================================="
