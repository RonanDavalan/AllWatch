% ALLWATCH(1) allwatch | Commandes utilisateur
% Ronan Davalan
% 2026-11-22

# NOM

allwatch - micro-superviseur de processus pour Linux

# SYNOPSIS

**allwatch** [*CONFIGURATION*]

**allwatch** **--version**

**allwatch** **--diagnose** [*CONFIGURATION*]

**allwatch** **--help**

# DESCRIPTION

**allwatch** est un petit superviseur de processus écrit en Bash. Il lance
chaque cible configurée comme processus enfant, mémorise le PID attribué par
le noyau et juge la santé de la cible à partir de trois sources seulement : le
processus existe dans `/proc`, son port TCP accepte une connexion, et le code
de sortie qu'il a renvoyé à sa fin. La cible doit rester au premier plan ;
une cible qui se détache en arrière-plan rompt le lien parent-enfant.

La cible est une boîte noire. Elle ne s'enregistre pas auprès d'AllWatch, ne
lui envoie aucun message d'état et n'a pas besoin de savoir qu'AllWatch
existe. Le superviseur est le parent ; la cible est l'enfant.

La configuration est lue une fois au démarrage. Le fichier par défaut est
`allwatch.conf` dans le répertoire courant ; le premier argument le remplace.

**--version**
:   Afficher `allwatch 0.1.0` et sortir avec le code `0`.

**--help**
:   Afficher le synopsis, les options, les variables d'environnement et le
    renvoi vers cette page de manuel, puis sortir avec le code `0`.

**--diagnose** [*CONFIGURATION*]
:   Lire la configuration, afficher la version, le chemin de la configuration,
    le répertoire d'état, le chemin du journal, la conduite sur gel, le nombre
    de cibles et l'identifiant, le port et la politique de chaque cible
    configurée, puis sortir. Il indique aussi si un répertoire d'état existant
    est un répertoire appartenant à l'utilisateur courant et si un répertoire
    de journal existant est inscriptible. Ne lance ni ne sonde aucune cible et
    n'écrit ni état ni journal. Une erreur de configuration est signalée sur la
    sortie d'erreur avant tout listing. Sort avec `0` si la configuration est
    lisible, qu'un répertoire d'état existant appartient à l'utilisateur
    courant et qu'un répertoire de journal existant est inscriptible. Sort avec
    `1` pour une configuration illisible, un `ON_FREEZE` invalide, un
    `POLL_SECONDS` non numérique, un répertoire d'état existant qui n'est pas
    un répertoire appartenant à l'utilisateur courant, ou un répertoire de
    journal existant qui n'est pas inscriptible.

Les options ne sont reconnues qu'en première position.

# CONFIGURATION

La configuration est lue une fois, au démarrage, ligne par ligne. Les lignes
vides et celles qui commencent par `#` sont ignorées.

Paramètres du moteur, une ligne `CLE=valeur` chacun :

**POLL_SECONDS**=*SECONDES*
:   Secondes entre deux contrôles (défaut `5`). Le délai de grâce d'un
    blocage vaut `2 * POLL_SECONDS`.

**PROBE_TIMEOUT**=*SECONDES*
:   Secondes accordées au port TCP pour répondre à la sonde (défaut `3`).

**MAX_RESTARTS**=*NOMBRE*
:   Relances autorisées dans la fenêtre avant le verrouillage de la cible
    (défaut `5`).

**RESTART_WINDOW**=*SECONDES*
:   Durée de la fenêtre de comptage des relances (défaut `60`).

**ON_FREEZE**=*restart*|*alert*
:   Conduite à tenir devant une cible encore vivante dont le port ne répond
    plus après le délai de grâce. `restart` (défaut) envoie `SIGTERM`, attend
    environ 5 secondes, envoie `SIGKILL` si nécessaire et considère la cible
    comme défaillante ; `alert` n'envoie aucun signal, journalise `ALERTE GEL`
    une fois, laisse la cible surveillée et journalise `RETABLI` quand le port
    répond de nouveau. Un plantage suit la politique de la cible dans les deux
    cas. Toute autre valeur est refusée au démarrage avec le code `1`.

Les valeurs numériques et les noms de politique sont utilisés tels quels et ne
sont pas validés ; `ON_FREEZE` fait exception et n'accepte que `restart` ou
`alert`.

Cibles, une par ligne :

    id port politique commande...

**id**
:   Un nom court et unique, utilisé pour les fichiers d'état et les lignes du
    journal. Il ne doit contenir ni `/` ni `..` ; AllWatch ne le valide pas.

**port**
:   Le port TCP écouté par la cible. Il est sondé sur `127.0.0.1` ; une cible
    qui n'écoute que sur une autre adresse est considérée comme plantée.

**politique**
:   `always`, `on-failure` ou `transient`.

**commande...**
:   Le reste de la ligne, découpé aux espaces (sans guillemets), lancé comme
    processus enfant depuis le répertoire où **allwatch** a été démarré. La
    commande n'est pas exécutée par un shell : les tubes, les redirections et
    l'expansion des variables ne sont pas interprétés ; placer cette logique
    dans un script exécutable. Avec le service Debian, utiliser des chemins
    absolus.

Politiques :

**always**
:   Relancer la cible à chaque fin, même avec le code 0, sauf si un fichier
    `id.stop` existe dans le répertoire d'état.

**on-failure**
:   Relancer après un plantage, ou après un blocage qu'AllWatch a neutralisé
    (`ON_FREEZE=restart`) ; laisser la cible arrêtée après une fin propre avec
    le code 0. Avec `ON_FREEZE=alert`, une cible plantée est laissée vivante et
    n'est pas relancée.

**transient**
:   Ne jamais relancer la cible.

Une valeur de politique autre que ces trois n'est pas refusée : la cible est
alors traitée comme `always`.

Pour demander un arrêt volontaire, créer `id.stop` dans le répertoire d'état
avant la fin de la cible (`touch /run/allwatch/id.stop` pour le service
Debian). AllWatch retire le fichier et ne relance pas la cible. Ce fichier
n'arrête pas une cible vivante par lui-même.

# ÉTATS

Le superviseur distingue quatre états ordinaires, plus un état exceptionnel de
verrouillage. Il n'a pas de commande d'état : un état se lit à travers le
processus, le port et le journal plat.

**Allumé**
:   Le processus existe et son port accepte une connexion.

**Planté**
:   Le processus existe mais son port ne répond pas. AllWatch marque la cible
    suspecte au premier échec de sonde et attend `2 * POLL_SECONDS` secondes.
    Si le port est toujours fermé, la conduite dépend d'`ON_FREEZE` :
    `restart` envoie `SIGTERM`, attend environ 5 secondes l'arrêt de la cible,
    envoie `SIGKILL` si nécessaire, puis considère la cible comme défaillante ;
    `alert` n'envoie aucun signal, journalise `ALERTE GEL` une fois, laisse la
    cible surveillée et journalise `RETABLI` quand le port répond de nouveau.
    Si le processus meurt pendant le gel, la cible est traitée comme crashée.

**Crashé**
:   Le processus a disparu sans arrêt volontaire. AllWatch lit le code de
    sortie et relance la cible si sa politique le demande. Pour une cible
    adoptée après un redémarrage du superviseur, le code de sortie n'est pas
    disponible : sa disparition est traitée comme un échec.

**Quitté**
:   La cible s'est terminée et sa politique dit de la laisser arrêtée, ou un
    drapeau d'arrêt de l'opérateur a été pris en compte. Le fichier PID est
    retiré, ainsi que le fichier d'arrêt s'il a été utilisé ; la cible n'est
    plus surveillée jusqu'au redémarrage du superviseur.

**Verrouillé (VERROU_CRITIQUE)**
:   La cible a atteint `MAX_RESTARTS` relances dans `RESTART_WINDOW`.
    AllWatch cesse de la relancer, consigne une alerte et retire le fichier
    PID. Les autres cibles continuent. Le verrou dure jusqu'au redémarrage du
    superviseur ; la cible n'est pas réessayée automatiquement.

# FICHIERS

*/tmp/allwatch-runtime*
:   Répertoire d'état par défaut d'un lancement manuel. Il contient un fichier
    `id.pid` et un fichier `id.fails` par cible ; un fichier `id.stop` est
    créé par l'opérateur pour demander un arrêt volontaire. Le répertoire est
    créé avec le mode `0700` s'il est absent ; un répertoire existant doit
    appartenir à l'utilisateur courant. AllWatch retire les fichiers `.pid`,
    `.stop` et `.fails` du répertoire à l'arrêt ; les autres fichiers restent.
    Le changer avec la variable d'environnement `ALLWATCH_RUNTIME`.

`$XDG_STATE_HOME/allwatch/allwatch.log`, `$HOME/.local/state/allwatch/allwatch.log`
:   Journal plat, une ligne par événement (`date id événement`). Le
    répertoire est créé si besoin. AllWatch ne fait pas tourner le journal.

*allwatch.conf*
:   Fichier de configuration par défaut dans le répertoire courant lorsqu'aucun
    argument n'est donné.

*/etc/allwatch/allwatch.conf*
:   Configuration utilisée par le service Debian, installée par le paquet
    `allwatch` comme conffile.

*/run/allwatch*
:   Répertoire d'état du service Debian (`ALLWATCH_RUNTIME`), créé à chaque
    démarrage du service et supprimé à son arrêt.

*/var/lib/allwatch/allwatch/allwatch.log*
:   Journal du service Debian (`XDG_STATE_HOME=/var/lib/allwatch`). systemd
    crée `/var/lib/allwatch` ; le script crée son sous-répertoire `allwatch`.

*/usr/bin/allwatch*
:   Programme installé (paquet Debian).

*/usr/lib/systemd/system/allwatch.service*
:   Unité systemd installée par le paquet Debian.

# SERVICE

Le paquet Debian installe `allwatch.service`, qui lance **allwatch** sous
l'utilisateur système `allwatch` avec `/etc/allwatch/allwatch.conf`. Avec la
configuration livrée, le service démarre sans cible active et attend. systemd
relance le superviseur après toute fin autre qu'un `systemctl stop` explicite
(`Restart=always`, sans plafond de démarrage). AllWatch relance ensuite ses
cibles selon leur politique. La configuration n'est pas
rechargée à chaud : après une modification, lancer :

    systemctl restart allwatch

Les commandes des cibles héritent de l'utilisateur, du groupe et du répertoire
de travail (`/var/lib/allwatch`) du service. Pour exécuter le service et toutes
ses cibles sous un autre utilisateur, créer un drop-in avec
`systemctl edit allwatch` et renseigner `User=` et `Group=`.

Commandes utiles :

    systemctl status allwatch
    systemctl start allwatch
    systemctl stop allwatch
    systemctl restart allwatch
    systemctl enable allwatch
    systemctl disable allwatch
    journalctl -u allwatch -f

Les paquets `.rpm` de Fedora et d'openSUSE Leap et le paquet d'Arch Linux installent la même unité de service, la même configuration et le même programme aux mêmes chemins. Ils ne démarrent pas le service : lancez `systemctl enable --now allwatch` une fois les cibles déclarées.

# SIGNAUX

**SIGTERM**, **SIGINT**
:   Le superviseur arrête chaque cible encore présente avec `SIGTERM`, attend
    environ 5 secondes sa fin, envoie `SIGKILL` si nécessaire, retire les
    fichiers `.pid`, `.stop` et `.fails`, écrit `allwatch ARRET` dans le
    journal et sort (`130` pour `SIGINT`, `143` pour `SIGTERM`).

**SIGTERM** à une cible
:   La cible traite le signal ; AllWatch observe le code de sortie qui en
    résulte lorsqu'il a démarré la cible, et applique la politique de la
    cible. Pour une cible adoptée après un redémarrage du superviseur, le code
    de sortie n'est pas disponible et sa disparition est traitée comme un
    échec. Le contrat de cible demande un arrêt en 5 secondes avec le code 0.
    Lorsque AllWatch neutralise lui-même une cible plantée, la cible est
    considérée comme défaillante même si elle sort ensuite avec le code 0.

**SIGHUP**
:   Non intercepté. Il ne recharge pas la configuration et termine normalement
    le superviseur ; systemd le relance alors. Utiliser
    `systemctl restart allwatch` pour recharger la configuration.

**SIGKILL**
:   Ne peut pas être intercepté. AllWatch n'exécute pas son nettoyage. Lors
    d'un lancement manuel, les cibles survivent et le répertoire d'état
    persiste ; le superviseur suivant peut adopter les cibles vivantes. Avec
    le service Debian, systemd gère le groupe de processus et supprime
    `/run/allwatch` à l'arrêt de l'unité : le superviseur suivant peut ne plus
    avoir les fichiers PID et lancer des doublons. Ne pas compter sur
    l'adoption après un `SIGKILL`.

# CODE DE SORTIE

**0**
:   Renvoyé par `--version`, `--help` et par un `--diagnose` réussi. La boucle
    de supervision ne se termine pas d'elle-même : elle s'exécute jusqu'à
    `SIGINT` ou `SIGTERM` et ne renvoie donc pas `0` en fonctionnement normal.

**1**
:   Fichier de configuration illisible, `ON_FREEZE` invalide, répertoire
    d'état qui n'appartient pas à l'utilisateur courant, contrôle de chemin de
    `--diagnose` en échec, ou erreur fatale (par exemple un `POLL_SECONDS` non
    numérique, ou un répertoire d'état ou de journal non inscriptible).

**130**
:   Interruption par `SIGINT`.

**143**
:   Terminaison par `SIGTERM`.

Le code de sortie d'une cible sert au superviseur à appliquer la politique,
mais il n'est pas renvoyé comme code de sortie du superviseur. Les autres
échecs fatals du shell ou d'un utilitaire système renvoient le code non nul de
cette commande, le plus souvent `1`.

# EXEMPLES

Lancer le superviseur avec la configuration d'exemple du dépôt de code :

    ./allwatch.sh allwatch.conf

Afficher la version du programme, le résumé de l'aide et inspecter une
configuration sans la lancer :

    ./allwatch.sh --version
    ./allwatch.sh --help
    ./allwatch.sh --diagnose allwatch.conf

Configuration avec une cible :

    POLL_SECONDS=5
    PROBE_TIMEOUT=3
    MAX_RESTARTS=5
    RESTART_WINDOW=60
    ON_FREEZE=restart
    demo 9001 on-failure ./dummy-target.sh 9001

Avec le paquet Debian, utiliser un chemin absolu pour la commande, car le
service s'exécute depuis `/var/lib/allwatch` :

    demo 9001 on-failure /usr/share/doc/allwatch/examples/dummy-target.sh 9001

Après l'installation du paquet, copier la configuration d'exemple et
redémarrer le service :

    sudo cp /usr/share/doc/allwatch/examples/allwatch.conf.example \
       /etc/allwatch/allwatch.conf
    sudo systemctl restart allwatch
    systemctl status allwatch
    journalctl -u allwatch -f

La maquette exige `nc` (paquet `netcat-openbsd`) et `setpriv`
(`util-linux`). Elle accepte `SIGUSR1` (cesser d'écouter, rester vivante),
`SIGUSR2` (planter avec le code 1) et `SIGTERM` (fin propre avec le code 0).
Pour demander l'arrêt volontaire d'une cible, créer son fichier d'arrêt sous
l'utilisateur du service :

    sudo -u allwatch touch /run/allwatch/demo.stop

# LIMITES

- Pas de rechargement à chaud de la configuration.
- Pas d'analyse des journaux applicatifs pour décider d'une relance.
- Pas de contrôle par le titre des fenêtres, X11 ou Wayland.
- Pas de supervision d'une cible qui se détache en arrière-plan.
- La commande n'est pas exécutée par un shell : ni guillemets, ni tubes, ni
  redirections, ni expansion des variables.
- Les valeurs numériques de configuration et les noms de politique ne sont pas
  validés. Un `POLL_SECONDS` nul fait tourner la boucle sans repos ; un
  `POLL_SECONDS` non numérique arrête le superviseur avec le code `1` ; un
  `PROBE_TIMEOUT` non numérique fait échouer toutes les sondes ; une politique
  mal orthographiée agit comme `always` ; un `MAX_RESTARTS` non numérique fait
  échouer chaque contrôle de limite, donc une cible `always` ou `on-failure`
  continue d'être relancée ; un `RESTART_WINDOW` non numérique arrête le
  superviseur avec le code `1` au prochain calcul de la fenêtre. `ON_FREEZE`
  est validé : une valeur inconnue arrête le superviseur avec le code `1`.
- Avec `ON_FREEZE=alert`, une cible dont le port reste fermé est laissée
  vivante et gelée ; AllWatch journalise `ALERTE GEL` une fois et ne la
  rétablit que si le port répond de nouveau ou si le processus meurt.
- Un `id` contenant `/` ou `..` peut sortir du répertoire d'état ; AllWatch ne
  le valide pas.
- Après un redémarrage du superviseur, le code de sortie d'une cible adoptée
  n'est pas disponible ; sa disparition est traitée comme un échec. L'adoption
  compare une sous-chaîne de `/proc/<pid>/cmdline`, pas l'exécutable réel ; un
  PID recyclé avec la même ligne de commande pourrait être adopté.
- Une cible qui n'écoute que sur une adresse autre que `127.0.0.1` est
  considérée comme plantée ; la sonde est une connexion TCP à `127.0.0.1`.
- Un `SIGKILL` du superviseur n'exécute pas le nettoyage. Lors d'un lancement
  manuel, les fichiers d'état restent et le superviseur suivant peut adopter
  les cibles vivantes ; avec le service, systemd supprime `/run/allwatch` à
  l'arrêt, donc le superviseur suivant ne les adopte pas et peut lancer des
  doublons.
- Le journal plat n'est pas rotaté.
- Avec quatre cibles ou plus qui utilisent chacune les 5 secondes de délai de
  grâce, un arrêt propre peut dépasser le `TimeoutStopSec` de 20 secondes du
  service ; systemd tue alors tout le groupe de processus.
- `--help` affiche le résumé et sort avec le code `0` ; les options ne sont
  reconnues qu'en première position.
- `--diagnose` contrôle la configuration et les chemins ; il ne lance ni ne
  sonde aucune cible, donc il ne prouve pas qu'une cible est saine.
- La configuration est une entrée de confiance : les commandes des cibles
  s'exécutent avec les privilèges de l'utilisateur du service. Protéger
  `/etc/allwatch/allwatch.conf` contre toute écriture non root. AllWatch
  n'isole pas les cibles dans un bac à sable.

# VOIR AUSSI

**bash**(1), **systemctl**(1), **journalctl**(1), **systemd.service**(5),
**systemd.exec**(5), **proc**(5), **timeout**(1)

# LICENCE

MIT. Copyright (c) 2026 Ronan Davalan. Voir
`/usr/share/doc/allwatch/LICENSE`.
