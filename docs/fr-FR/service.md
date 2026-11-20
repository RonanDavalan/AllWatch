# Installer et exploiter le service Debian

Le paquet Debian installe AllWatch comme service systemd. Le service démarre au boot, lit sa configuration une seule fois et attend si aucune cible n'est déclarée. Ce chapitre donne les chemins, les fichiers et les commandes exactes du paquet.

## Ce que le paquet installe

```text
/usr/bin/allwatch                          le superviseur
/usr/bin/allwatch.sh                       lien de compatibilité
/usr/lib/systemd/system/allwatch.service   l'unité systemd
/etc/allwatch/allwatch.conf                la configuration
/usr/share/man/man1/allwatch.1.gz          page de manuel, anglais
/usr/share/man/fr/man1/allwatch.1.gz       page de manuel, français
/usr/share/man/de/man1/allwatch.1.gz       page de manuel, allemand
/usr/share/man/es/man1/allwatch.1.gz       page de manuel, espagnol
/usr/share/doc/allwatch/README.Debian      notes du paquet
/usr/share/doc/allwatch/examples/allwatch.conf.example
/usr/share/doc/allwatch/examples/dummy-target.sh
```

Le paquet crée l'utilisateur et le groupe système `allwatch` (domicile `/var/lib/allwatch`, shell `/usr/sbin/nologin`). Le service tourne sous cette identité depuis `/var/lib/allwatch`.

## Installer

```bash
sudo apt install ./allwatch_0.1.0-3_all.deb
```

Le paquet installe le programme et l'unité, active `allwatch.service`, le démarre et livre une configuration sans cible active.

Vérifiez l'état du paquet et la version du programme :

```bash
dpkg -s allwatch | grep -E '^(Status|Version):'
allwatch --version
```

`allwatch --version` affiche `allwatch 0.1.0` ; la version du paquet est `0.1.0-3`.

## Chemins et fichiers

- `/etc/allwatch/allwatch.conf` est un fichier de configuration (conffile) appartenant à root, non inscriptible par l'utilisateur du service. C'est la frontière de confiance : les commandes des cibles s'exécutent avec les privilèges de l'utilisateur du service.
- `/var/lib/allwatch` porte l'état et le journal, mode `0700`, propriétaire `allwatch:allwatch`, créé par systemd. Le journal plat est `/var/lib/allwatch/allwatch/allwatch.log`.
- `/run/allwatch` est le répertoire d'exécution, mode `0700`, créé à chaque démarrage du service et retiré à l'arrêt. Il porte `<id>.pid`, `<id>.fails` et `<id>.stop`.
- `/var/lib/allwatch` et `/run/allwatch` ne survivent pas à une purge ; `/run/allwatch` ne survit pas à un arrêt.

## Déclarer une cible

Éditez `/etc/allwatch/allwatch.conf` en root et ajoutez une ligne par cible :

```text
id port policy command...
```

Exemple réel avec le double de test installé par le paquet :

```bash
sudo apt install netcat-openbsd
sudo cp /usr/share/doc/allwatch/examples/allwatch.conf.example /etc/allwatch/allwatch.conf
sudo systemctl restart allwatch
```

L'exemple déclare :

```text
demo 9001 on-failure /usr/share/doc/allwatch/examples/dummy-target.sh 9001
```

Vérifiez le port :

```bash
bash -c ': > /dev/tcp/127.0.0.1/9001' && echo "le port 9001 répond"
```

L'utilisateur du service doit pouvoir exécuter la commande. Employez des chemins absolus : la commande est découpée aux espaces, sans guillemets, et n'est pas exécutée par un shell. Pour des arguments contenant des espaces ou de la syntaxe shell, écrivez un script d'enveloppe et appelez-le.

## Commandes du service

```bash
sudo systemctl status allwatch
sudo systemctl start allwatch
sudo systemctl stop allwatch
sudo systemctl restart allwatch
sudo systemctl enable allwatch
sudo systemctl disable allwatch
sudo journalctl -u allwatch -f
sudo tail -f /var/lib/allwatch/allwatch/allwatch.log
```

La configuration est lue une fois au démarrage ; une modification exige `sudo systemctl restart allwatch`. Il n'y a pas de rechargement à chaud.

## Contrôler la configuration sans lancer de cible

Lancez `--diagnose` avec l'environnement du service et sous l'utilisateur du service :

```bash
sudo -u allwatch env ALLWATCH_RUNTIME=/run/allwatch \
  XDG_STATE_HOME=/var/lib/allwatch \
  allwatch --diagnose /etc/allwatch/allwatch.conf
```

Il affiche la version, le chemin de la configuration, le chemin d'exécution, le chemin du journal et, pour chaque cible, son identifiant, son port et sa politique. Il rend `0` quand la configuration est lisible et que les répertoires d'exécution et de journal existants sont utilisables, `1` sinon. Il ne lance aucune cible et ne sonde aucun port.

## Arrêter une cible sans arrêter le service

Créez le fichier d'arrêt sous l'utilisateur du service :

```bash
sudo -u allwatch touch /run/allwatch/demo.stop
```

AllWatch retire le fichier quand la cible se termine et ne la relance pas. Le fichier n'arrête pas à lui seul une cible en cours : envoyez `SIGTERM` à la cible ou laissez-la se terminer.

## Faire tourner le service sous un autre utilisateur

Le service tourne sous `allwatch`. Si une cible a besoin de root ou d'un autre compte, créez un fichier de dépassement (drop-in) :

```bash
sudo systemctl edit allwatch
```

Ajoutez :

```ini
[Service]
User=monutilisateur
Group=mon_groupe
```

Puis redémarrez :

```bash
sudo systemctl restart allwatch
```

Les commandes des cibles héritent de cette identité. Le fichier de configuration reste la propriété de root.

## Mettre à jour

```bash
sudo apt install ./allwatch_0.1.0-3_all.deb
```

`/etc/allwatch/allwatch.conf` est conservé ; si la version du paquet le modifie, dpkg demande quelle version garder. Le service est redémarré après la mise à jour s'il était actif. `/var/lib/allwatch` et son journal restent.

## Retirer et purger

```bash
sudo apt remove allwatch
sudo apt purge allwatch
```

`apt remove` arrête le service, retire le programme, l'unité, les pages de manuel et la documentation du paquet. Il conserve `/etc/allwatch/allwatch.conf`, `/var/lib/allwatch` et l'utilisateur et le groupe `allwatch`. Il ne désactive pas l'unité ; l'état d'activation de deb-systemd-helper reste jusqu'à la purge.

`apt purge` retire aussi le conffile, `/var/lib/allwatch`, `/etc/allwatch` quand il est vide, l'utilisateur et le groupe `allwatch` quand ils peuvent l'être, et l'état d'activation. Si un processus utilise encore le compte, `userdel` ou `groupdel` peut échouer ; vérifiez avec :

```bash
getent passwd allwatch
getent group allwatch
```

## Limites connues du paquet

- La validation en conteneur installe le paquet, contrôle `--version`, `--help` et `--diagnose`, puis le retire. Elle ne démarre pas systemd : le service est installé et documenté, mais non validé sous systemd dans le conteneur.
- `--diagnose` est statique : il ne sonde aucune cible.
- `/run/allwatch` ne survit pas à un arrêt du service. Après un plantage du superviseur, des cibles peuvent survivre sans fichier PID ; le superviseur redémarré peut en lancer des doublons. Un drop-in avec `RuntimeDirectoryPreserve=restart` conserve le répertoire à travers un redémarrage du service.
