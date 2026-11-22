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