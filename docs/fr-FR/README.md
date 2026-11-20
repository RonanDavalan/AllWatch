# AllWatch

[![Version](https://img.shields.io/badge/version-0.1.0-115E67)](https://allwatch.davalan.fr/fr/telechargement/)
[![Licence](https://img.shields.io/badge/licence-MIT-115E67)](LICENSE)
[![Plateforme](https://img.shields.io/badge/plateforme-Debian%20%7C%20Ubuntu-DCA134)](https://allwatch.davalan.fr/fr/telechargement/)

[English](README.md) | [Français](docs/fr-FR/README.md) | [Deutsch](docs/de-DE/README.md) | [Español](docs/es-ES/README.md)

![Aide d'AllWatch](docs/images/allwatch-help.png)

AllWatch est un superviseur de processus minimaliste pour Linux, écrit dans un simple script Bash (une centaine de lignes de code). Il lance chaque processus au premier plan, mémorise son PID et évalue son état uniquement à partir des informations fournies par le noyau et le réseau : le processus est-il toujours dans `/proc`, son port TCP accepte-t-il toujours une connexion et quel code de sortie a-t-il renvoyé ? Il redémarre le processus selon une politique définie pour chaque cible et refuse de boucler indéfiniment sur un processus qui s'arrête brutalement.

La cible est une boîte noire. Elle ne s'enregistre pas auprès d'AllWatch, ne lui envoie rien et n'a pas besoin de savoir qu'elle existe.

## Comment ça marche

AllWatch est le parent, la cible est l'enfant. Toutes les quelques secondes, il examine chaque cible et la place dans l'un des quatre états suivants :

- **En cours** : le processus existe et son port accepte une connexion.
- **Bloqué** : le processus existe mais son port ne répond pas. AllWatch envoie `SIGTERM`, attend l’arrêt de la cible (5 secondes), envoie `SIGKILL` si nécessaire, puis considère la cible comme défaillante.
- **Plantage** : le processus s'est arrêté brutalement. AllWatch analyse le code de sortie et redémarre la cible conformément à sa politique.
- **Quitter** : la cible a atteint sa fin et sa politique indique de ne pas la modifier, ou la limite de redémarrage a été atteinte.

## Exigences

- Linux (le superviseur lit `/proc`), Bash 5 ou plus tard, et `timeout` et `awk` parmi les utilitaires de base habituels.
- Pour le double test `dummy-target.sh` uniquement : `setpriv` (util-linux) et OpenBSD `nc`.

## Installer sur Debian et Ubuntu

Le paquet Debian installe le superviseur sous `/usr/bin/allwatch`, l'unité
systemd `allwatch.service`, la configuration d'exemple et la page de manuel en
quatre langues. Téléchargez le paquet et `SHA256SUMS` depuis la [page de
téléchargement](https://allwatch.davalan.fr/fr/telechargement/), puis lancez :

```bash
sudo apt install ./allwatch_0.1.0-3_all.deb
```

Niveau annoncé : **installation et diagnostic validés en conteneur**, sur
Debian 12 et 13 et sur Ubuntu 22.04 et 24.04. Le paquet n'est pas présenté
comme testé sur un serveur physique. Le service est installé et activé, avec
une configuration qui ne déclare aucune cible ; ajoutez vos cibles dans
`/etc/allwatch/allwatch.conf`, puis lancez `sudo systemctl restart allwatch`.

Vérifiez la version installée et la configuration sans lancer de cible :

```bash
allwatch --version
allwatch --help
allwatch --diagnose /etc/allwatch/allwatch.conf
```

`--diagnose` lit la configuration, le répertoire d'état et le chemin du
journal. Il ne lance ni ne sonde aucune cible : il ne prouve pas qu'une cible
est saine, il prouve que le superviseur peut lire sa configuration et utiliser
ses chemins.

Pour retirer le paquet :

```bash
sudo apt remove allwatch
sudo apt purge allwatch
```

`apt remove` arrête le service mais le laisse activé ; `apt purge` retire
aussi la configuration et l'état du service.

## Structure du dépôt

- `allwatch.sh` : le superviseur.
- `allwatch.conf` : un exemple de configuration, une cible sur le port 9001.
- `dummy-target.sh` : un double de test qui écoute sur un port TCP et qui peut être configuré pour s’arrêter proprement, se bloquer ou planter à la demande.
- `LICENSE` : MIT.

## Démarrage rapide

Depuis le répertoire du dépôt, dans un premier terminal, démarrez le superviseur avec la configuration d'exemple :

```bash
./allwatch.sh allwatch.conf
```

Il lance `dummy-target.sh` sur le port 9001 sous l'identifiant `demo`. Dans un second terminal, depuis n'importe quel répertoire, examinez la cible :

```bash
cat /tmp/allwatch-runtime/demo.pid
: > /dev/tcp/127.0.0.1/9001 && echo "le port 9001 répond"
```

Éliminez la cible de manière radicale et observez-la revenir avec un nouveau PID (l'intervalle d'interrogation est de 5 secondes) :

```bash
kill -9 "$(cat /tmp/allwatch-runtime/demo.pid)"
sleep 6
cat /tmp/allwatch-runtime/demo.pid
```

Provoquez le blocage de la cible (elle reste active mais ferme son port). AllWatch le détecte, l'arrête et la redémarre, ce qui prend environ quinze secondes :

```bash
kill -USR1 "$(cat /tmp/allwatch-runtime/demo.pid)"
sleep 20
cat /tmp/allwatch-runtime/demo.pid
grep ' demo ' ~/.local/state/allwatch/allwatch.log | tail -n 6
```

Le journal affiche `DEMARRE` pour le premier lancement, `CRASHE code=137` puis `RELANCE` pour l'arrêt brutal, puis `PLANTE`, `NEUTRALISE SIGTERM` et `RELANCE` pour le blocage. Enfin, arrêtez le superviseur avec `Ctrl+C` dans le premier terminal (ou envoyez-lui `SIGTERM`) ; il arrête ses cibles et vide son répertoire d'état.

```bash
ls -A /tmp/allwatch-runtime
```

La commande n'affiche rien.

## Configuration : `allwatch.conf`

Le fichier est lu une seule fois, au démarrage, ligne par ligne. Les lignes vides et les lignes commençant par `#` sont ignorées.

Paramètres du moteur, une `KEY=valeur` par ligne :

- `POLL_SECONDS=5`: secondes entre deux vérifications.
- `PROBE_TIMEOUT=3`: secondes dont dispose un port pour répondre à la sonde.
- `MAX_RESTARTS=5`: redémarrages autorisés dans la fenêtre ci-dessous.
- `RESTART_WINDOW=60`: durée de cette fenêtre, en secondes.

Cibles, une par ligne :

```
id port policy command...
```

- `id` : un nom court, utilisé pour les fichiers d’état et le journal.
- `port`: le port TCP sur lequel la cible écoute (sondé sur `127.0.0.1`).
- `policy`: l'une des valeurs suivantes : `always`, `on-failure`, `transient`.
- `command...`: le reste de la ligne, séparé par des espaces (sans guillemets), exécuté au premier plan depuis le répertoire où `allwatch.sh` a été lancé.

Politiques :

- `always` : redémarrer la cible chaque fois qu’elle se termine, même avec le code de sortie 0, sauf si un fichier `<id>.stop` existe dans le répertoire d’état.
- `on-failure` : redémarrer après un plantage ou un blocage, mais laisser arrêté après un code de sortie 0.
- `transient` : ne jamais le redémarrer.

Si une cible a besoin de plus de `MAX_RESTARTS` redémarrages dans les `RESTART_WINDOW` secondes, AllWatch cesse de la redémarrer, enregistre `ALERTE VERROU_CRITIQUE` et continue avec les autres cibles.

Utilisation : `./allwatch.sh [fichier.conf]` (par défaut : `allwatch.conf`). Le répertoire d'état est `/tmp/allwatch-runtime` (à remplacer par `ALLWATCH_RUNTIME`). Le journal est un fichier plat, une ligne par événement (`date id event`), situé dans `${XDG_STATE_HOME:-$HOME/.local/state}/allwatch/allwatch.log`.

## Le contrat qu'une cible doit respecter

AllWatch ne s'adapte à rien ; la cible qui rompt le contrat est en faute.

- **Premier plan.** La cible s'exécute au premier plan du processus lancé par AllWatch. Elle ne doit pas se transformer en processus démon ni créer de double processus : AllWatch verrait alors le premier processus se terminer et en lancerait un duplicata.
- **Codes de sortie.** Un arrêt propre et demandé se termine par le code `0`. Toute erreur se termine par un code différent de zéro.
- **Un port TCP.** Chaque cible possède un port TCP, ouvert et acceptant les connexions dès son initialisation. Une cible active qui n'accepte pas de connexion dans le délai imparti est considérée comme bloquée.
- **`SIGTERM`.** La cible intercepte `SIGTERM`, libère ses ressources et se termine avec le code `0` en moins de 5 secondes. Ensuite, AllWatch envoie `SIGKILL`.

Le titre de la fenêtre, le serveur d'affichage et la sortie propre à la cible ne jouent aucun rôle dans le contrôle d'intégrité.

## Limites

- Aucune notification d'enregistrement ou de mise à jour de statut de la cible : AllWatch n'écoute rien de ce que dit la cible.
- Aucune vérification basée sur Windows, X11 ou Wayland.
- Aucune analyse des journaux n'est effectuée pour décider d'un redémarrage.
- Aucune surveillance des cibles qui se détachent du premier plan.
- Pas de rechargement à chaud de la configuration : `sudo systemctl restart allwatch`.
- Pas de niveaux de journalisation, pas d'interface réseau, pas de protocole inter-processus.
- `--diagnose` est statique : il lit la configuration et les chemins, il ne sonde aucune cible et ne prouve pas qu'une cible est saine.
- `--version`, `--help` et `--diagnose` ne sont reconnus qu'en première position.
- La commande n'est pas exécutée par un shell : ni guillemets, ni tubes, ni redirections, ni expansion de variables.
- Les valeurs de configuration et les noms de politique ne sont pas validés.
- Le journal plat n'est pas rotaté.
- Aucune garantie quant à la cohérence interne des données d'une cible : AllWatch garantit que le processus existe et répond, rien de plus.

## Licence

MIT. Voir `LICENSE`.

## Crédits

- **Ronan Davalan** : architecte et arbitre. Il a défini la vision et le périmètre du projet, arbitré les spécifications et les a validées.
- **Claude Sonnet 5.5** (Anthropic) : seul auteur du code (le superviseur et le double de test), écrit en trois sessions de codage le 13 novembre 2026.
- **Gemini** (Google) : synthèse stratégique et co-écriture des spécifications : détection des anti-modèles, formalisation de la machine à quatre états.

Voir `CONTRIBUTORS.md`.
