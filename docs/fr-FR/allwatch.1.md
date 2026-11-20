% ALLWATCH(1) allwatch | Commandes utilisateur
% Ronan Davalan
% 2026-11-20

# NOM

allwatch - micro-superviseur de processus pour Linux

# SYNOPSIS

**allwatch** [*CONFIGURATION*]

# DESCRIPTION

**allwatch** est un petit superviseur de processus écrit en Bash. Il lance
chaque cible configurée au premier plan, mémorise le PID attribué par le
noyau et juge la santé de la cible à partir de trois sources seulement : le
processus existe dans `/proc`, son port TCP accepte une connexion, et le
code de sortie qu'il a renvoyé à sa fin.

La cible est une boîte noire. Elle ne s'enregistre pas auprès d'AllWatch, ne
lui envoie aucun message d'état et n'a pas besoin de savoir qu'AllWatch
existe. Le superviseur est le parent ; la cible est l'enfant.

# CONFIGURATION

La configuration est lue une fois, au démarrage, ligne par ligne. Les lignes
vides et celles qui commencent par `#` sont ignorées.

Paramètres du moteur, une ligne `CLE=valeur` chacun :

**POLL_SECONDS**=*SECONDES*
:   Secondes entre deux contrôles (défaut `5`).

**PROBE_TIMEOUT**=*SECONDES*
:   Secondes accordées au port TCP pour répondre à la sonde (défaut `3`).

**MAX_RESTARTS**=*NOMBRE*
:   Relances autorisées dans la fenêtre avant le verrouillage de la cible
    (défaut `5`).

**RESTART_WINDOW**=*SECONDES*
:   Durée de la fenêtre de comptage des relances (défaut `60`).

Cibles, une par ligne :

    id port politique commande...

**id**
:   Un nom court et unique, utilisé pour les fichiers d'état et le journal.

**port**
:   Le port TCP écouté par la cible, sondé sur `127.0.0.1`.

**politique**
:   `always`, `on-failure` ou `transient`.

**commande...**
:   Le reste de la ligne, découpé aux espaces (sans guillemets), lancé au
    premier plan depuis le répertoire où **allwatch** a été démarré.

Politiques :

**always**
:   Relancer la cible à chaque fin, même avec le code 0, sauf si un fichier
    `id.stop` existe dans le répertoire d'état.

**on-failure**
:   Relancer après un plantage ou un blocage ; laisser la cible arrêtée
    après une fin propre avec le code 0.

**transient**
:   Ne jamais relancer la cible.

# ÉTATS

**Allumé**
:   Le processus existe et son port accepte une connexion.

**Planté**
:   Le processus existe mais son port ne répond pas. Après un délai de
    grâce, AllWatch envoie `SIGTERM`, attend jusqu'à 5 secondes l'arrêt de la
    cible, envoie `SIGKILL` si nécessaire, puis considère la cible comme
    défaillante.

**Crashé**
:   Le processus a disparu sans arrêt volontaire. AllWatch lit le code de
    sortie et relance la cible si sa politique le demande.

**Quitté**
:   La cible s'est terminée et sa politique dit de la laisser arrêtée, ou la
    limite de relances est atteinte. Le fichier d'état est retiré.

# FICHIERS

*/tmp/allwatch-runtime*
:   Répertoire d'état par défaut : un fichier `id.pid`, `id.stop` ou
    `id.fails` par cible. Il est vidé à l'arrêt du superviseur. Le changer
    avec la variable d'environnement `ALLWATCH_RUNTIME`.

*$XDG_STATE_HOME/allwatch/allwatch.log*, *$HOME/.local/state/allwatch/allwatch.log*
:   Journal plat, une ligne par événement (`date id événement`). Le
    répertoire est créé si besoin. AllWatch ne fait pas tourner le journal.

*/etc/allwatch/allwatch.conf*
:   Configuration utilisée par le service Debian, installée par le paquet
    `allwatch`.

*/run/allwatch*
:   Répertoire d'état du service Debian (`ALLWATCH_RUNTIME`), recréé à chaque
    démarrage et vidé à chaque arrêt.

*/var/lib/allwatch/allwatch/allwatch.log*
:   Journal du service Debian (`XDG_STATE_HOME=/var/lib/allwatch`).

# SERVICE

Le paquet Debian installe `allwatch.service`, qui lance **allwatch** sous
l'utilisateur système `allwatch` avec `/etc/allwatch/allwatch.conf`. systemd
relance le superviseur après toute fin (`Restart=always`, sans plafond de
démarrage) ; AllWatch relance ensuite ses cibles selon leur politique. La
configuration n'est pas rechargée à chaud : après une modification, lancer :

    systemctl restart allwatch

Commandes utiles :

    systemctl status allwatch
    systemctl start allwatch
    systemctl stop allwatch
    systemctl restart allwatch
    journalctl -u allwatch -f

# SIGNAUX

**SIGTERM**, **SIGINT**
:   Le superviseur arrête chaque cible avec `SIGTERM`, attend sa fin, envoie
    `SIGKILL` après 5 secondes si nécessaire, retire ses fichiers d'état et
    sort (`130` pour `SIGINT`, `143` pour `SIGTERM`).

**SIGTERM** à une cible
:   La cible doit s'arrêter en 5 secondes avec le code de sortie 0.

# CODE DE SORTIE

**0**
:   Arrêt normal.

**1**
:   Fichier de configuration illisible, ou répertoire d'état qui
    n'appartient pas à l'utilisateur courant.

**130**
:   Interruption par `SIGINT`.

**143**
:   Terminaison par `SIGTERM`.

# EXEMPLES

Lancer le superviseur avec la configuration d'exemple du dépôt de code :

    ./allwatch.sh allwatch.conf

Configuration avec une cible :

    POLL_SECONDS=5
    PROBE_TIMEOUT=3
    MAX_RESTARTS=5
    RESTART_WINDOW=60
    demo 9001 on-failure ./dummy-target.sh 9001

Avec le paquet Debian, utiliser un chemin absolu pour la commande, car le
service s'exécute depuis `/var/lib/allwatch` :

    demo 9001 on-failure /usr/share/doc/allwatch/examples/dummy-target.sh 9001

# LIMITES

- Pas de rechargement à chaud de la configuration.
- Pas d'analyse des journaux applicatifs pour décider d'une relance.
- Pas de contrôle par le titre des fenêtres, X11 ou Wayland.
- Pas de supervision d'une cible qui se détache en arrière-plan.
- Pas d'option `--version` ni `--help` dans cette version. La version du
  paquet se lit avec `dpkg -s allwatch` ; une version future ajoutera ces
  options.

# VOIR AUSSI

**systemd.service**(5), **systemd.exec**(5), **proc**(5)

# LICENCE

MIT. Copyright (c) 2026 Ronan Davalan. Voir `/usr/share/doc/allwatch/LICENSE`.
