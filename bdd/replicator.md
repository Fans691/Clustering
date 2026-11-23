# Replicator

sudo -u postgres psql -p 5432

# Creer un utilisateur pour la réplication
CREATE ROLE replicator WITH LOGIN REPLICATION PASSWORD 'Repli2026!';

# Verification de la replication
sudo -u postgres psql -p 5432 -c "SHOW wal_level;"
sudo -u postgres psql -p 5432 -c "SHOW max_wal_senders;"

# Creation du slave
sudo pg_createcluster 16 slave --port=5433 --start-conf=manual

# Arreter le slave par securite
sudo pg_ctlcluster 16 slave stop

# Copier les donnees du master vers le slave
sudo -u postgres pg_basebackup \
    -h 127.0.0.1 \
    -p 5432 \
    -U replicator \
    -D /var/lib/postgresql/16/slave \
    -Fp \
    -Xs \
    -P \
    -R

# Demarrer le slave
sudo pg_ctlcluster 16 slave start