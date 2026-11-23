-- Base replication 
sudo -u postgres psql -p 5432

CREATE TABLE test_replication (
    id SERIAL PRIMARY KEY,
    nom VARCHAR(100),
    message VARCHAR(255)
);

CREATE TABLE patient (
    id SERIAL PRIMARY KEY,
    nom VARCHAR(100)
);

CREATE TABLE persone (
    id SERIAL PRIMARY KEY,
    nom VARCHAR(100)
);





insert into patient(nom) values('bolo');

INSERT INTO test_replication (nom, message)
VALUES ('Fanilo', 'Replication PostgreSQL Master-Slave fonctionne !');


