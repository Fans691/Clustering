# !/bin/bash
sudo rm -f /etc/postgresql/16/main/postgresql.conf
sudo rm -f /etc/postgresql/16/main/pg_hba.conf

# Copier les fichiers de configuration modifiés
sudo cp postgresql.conf /etc/postgresql/16/main/postgresql.conf
sudo cp pg_hba.conf /etc/postgresql/16/main/pg_hba.conf

# Redémarrer le service PostgreSQL pour appliquer les modifications
sudo systemctl restart postgresql
sudo pg_ctlcluster 16 main restart

# Verification de l'état du service PostgreSQL
pg_lsclusters