-- Base replication 
sudo -u postgres psql -p 5432

CREATE TABLE test_replication (
    id SERIAL PRIMARY KEY,
    nom VARCHAR(100),
    message VARCHAR(255)
);

INSERT INTO test_replication (nom, message)
VALUES ('Fanilo', 'Replication PostgreSQL Master-Slave fonctionne !');

