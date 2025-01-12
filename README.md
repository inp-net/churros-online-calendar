# Churros online calendar

Ce projet à pour but de permettre à un utilisateur de générer une url de
calendrier en ligne à partir de la liste des événements churros auquels
un utilisateur de l'appli à accès.

Ce calendrier peut ensuite être ajouté à votre google agenda
et se mettra à jour automatiquement.

## Limitations de la bêta

- **Seuls les 10 derniers événements dans l'ordre chronologique sont affichés actuellement**
- Pas de nettoyage automatique des données inutiles de la base de donnée :
    - Il faudra penser à supprimer manuellement les vieux tokens périmés au fil du temps (on peut s'aider du champs `creation_date` de la table des tokens)
    - Il faudra penser à supprimer manuellement les url de calendrier inutilisées (on peut s'aider du champs `last_access_date` de la table des calendriers qui est mis à jour à chaque fois que quelqu'un fait une requête sur cette url de calendrier)
- Risque d'évolution de l'api dans les versions futures
- On peut pas choisir l'emplacement du fichier .sql si on veut utiliser sqlite3 pour la base de donnée

## Utilisation

L'api REST est composée de 2 requêtes:
- `GET /calendars/<calendar_uid>`: récupérer le contenu du calendrier qui a pour uid "calendar_uid" au format .ics.
C'est cette url qu'il faut ajouter à votre agenda en ligne. Si calendar_uid == public : renvoie le calendrier des événements publics
- `POST /register` data=`"<churros_token>"`: enregistrer un nouveau token churros dans la base de donnée
et renvoie l'uid du calendrier de l'utilisateur à qui appartient le token.
Si un calendrier existait déjà pour cet utilisateur, l'uid de son calendrier ne change pas.

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

Utiliser la variable d'environnement "DB_URI" pour se connecter à la base de données.

Exemple:

`DB_URI='mariadb://<user>:<password>@<serveur_sql>/<database_name>' churros_online_calendar`

Si aucune variable d'environnement n'est passée à l'exécutable, une base de donnée sqlite par défaut sera créée et sera accessible dans `/tmp/test.sql`.

L'utilisation de sqlite est plutôt à réserver pour du developpement. Elle est déconseillée en production.
