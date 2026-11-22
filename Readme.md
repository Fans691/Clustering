## Deploiement vers Tomcat

Le fichier `a.html` peut etre deploye comme page d'accueil du contexte ROOT :

```bash
./deploy.sh
```

Destination : `/opt/tomcat/webapps/ROOT/index.html`

Il est possible de fournir un autre fichier HTML :

```bash
./deploy.sh chemin/vers/page.html
```

## Page d'accueil et choix du serveur

La page d'accueil permet de choisir entre les serveurs Apache et Tomcat.

1. Deployer la page d'accueil Apache :

```bash
cd serveur-apache
./deploy.sh
```

2. Deployer la page Tomcat :

```bash
cd ../serveur-tomcat
./deploy.sh
```

3. Valider puis redemarrer HAProxy :

```bash
sudo haproxy -c -f haproxy.cfg
sudo ./haproxy.sh
```

Ouvrir ensuite `http://<adresse-du-serveur>:8082/`.