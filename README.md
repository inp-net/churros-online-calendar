# Churros online calendar

Ce projet à pour but de permettre à un utilisateur de générer une url de
calendrier en ligne à partir de la liste des événements churros auquels
un utilisateur de l'appli à accès.

Ce calendrier peut ensuite être ajouté à votre google agenda
et se mettra à jour automatiquement.

## Limitations de la bêta

- Pas de nettoyage automatique des données inutiles de la base de donnée :
    - Il faudra penser à supprimer manuellement les vieux tokens périmés au fil du temps (on peut s'aider du champs `creation_date` de la table des tokens)
    - Il faudra penser à supprimer manuellement les url de calendrier inutilisées (on peut s'aider du champs `last_access_date` de la table des calendriers qui est mis à jour à chaque fois que quelqu'un fait une requête sur cette url de calendrier)
- Risque d'évolution de l'api dans les versions futures
- On peut pas choisir l'emplacement du fichier .sql si on veut utiliser sqlite3 pour la base de donnée

## Installation

### Avec dune
(cette section sera mise à jour dans le futur)
1. Utiliser dune pour installer les dépendances du projet.
2. Compiler le projet avec `dune build`
3. Executer le projet avec `dune exec bin/main.exe`

### Avec nix
Vous pouvez télécharger, compiler et exécuter directement le projet avec nix:
`nix run git+https://git.inpt.fr/inp-net/churros-ecosystem/online-calendar.git`

vous pouvez également ajouter l'exécutable au path temporairement avec:
`nix shell git+https://git.inpt.fr/inp-net/churros-ecosystem/online-calendar.git`

## Configuration
(la configuration de la base de donnée va probablement changer dans le futur)

### Postgresql
Pour lancer le projet et utiliser une base de donnée postgresql, utiliser les variables d'environnement comme suit:
`PGHOST=localhost PGPORT=5455 PGDATABASE=postgresDB PGUSER=postgresUser PGPASSWORD=postgresPW churros_online_calendar`

Les variables `PGUSER` et `PGPASSWORD` ne doivent pas être renseignée si votre base de donnée ne nécessite pas d'authentification.

### Sqlite
Si aucune variable d'environnement n'est passée à l'exécutable, une base de donnée sqlite par défaut sera créée et sera accessible dans `/tmp/test.sql`.

L'utilisation de cette base de donnée est plutôt à réserver pour du developpement. Elle est déconseillée en production.
