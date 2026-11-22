| Étape | Travail à effectuer | Objectif |
|---|---|---|
| 1 | Préparation des deux serveurs | Vérifier PostgreSQL et le réseau |
| 2 | Configuration du Master | Autoriser la réplication |
| 3 | Création de l'utilisateur replicator | Autoriser le Slave à se connecter |
| 4 | Configuration de pg_hba.conf | Autoriser les connexions réseau |
| 5 | Configuration du Slave | Préparer le serveur secondaire |
| 6 | pg_basebackup | Copier les données du Master |
| 7 | Streaming Replication | Activer la synchronisation |
| 8 | Tests INSERT / UPDATE / DELETE | Vérifier la réplication |
| 9 | Simulation de panne | Comprendre les limites et la disponibilité |
| 10 | Promotion du Slave | Transformer le Slave en nouveau Master |

