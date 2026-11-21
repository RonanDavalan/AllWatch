# Dépannage

AllWatch n'a pas de commande d'état. L'état d'une cible se lit dans le processus, le port TCP et le journal plat. Ce chapitre donne les commandes exactes des défaillances courantes.

## Lire d'abord l'état du service

```bash
sudo systemctl status allwatch
sudo journalctl -u allwatch -n 50 --no-pager
sudo tail -n 50 /var/lib/allwatch/allwatch/allwatch.log
```

Les lignes du journal sont `date id événement`. Les événements sont `DEMARRAGE`, `DEMARRE`, `ADOPTE`, `PLANTE`, `ALERTE GEL`, `RETABLI`, `NEUTRALISE SIGTERM`, `NEUTRALISE SIGKILL`, `CRASHE code=N`, `RELANCE`, `ALERTE VERROU_CRITIQUE`, `QUITTE` et `ARRET`.

## Le service ne démarre pas

- `allwatch: configuration illisible : /etc/allwatch/allwatch.conf` — le fichier manque ou n'est pas lisible par l'utilisateur du service. Vérifiez `sudo -u allwatch test -r /etc/allwatch/allwatch.conf` et `sudo systemctl cat allwatch`.
- `allwatch: /run/allwatch n'appartient pas à l'utilisateur` — le répertoire d'exécution appartient à un autre utilisateur. Vérifiez `ls -ld /run/allwatch /var/lib/allwatch` ; l'unité les crée pour `allwatch`. Si vous avez ajouté un drop-in avec un autre `User=`, corrigez la propriété ou retirez le drop-in.
- `status=203/EXEC` — le programme manque ou n'est pas exécutable. Réinstallez le paquet.
- `status=1/FAILURE` avec une erreur de configuration — lancez `--diagnose` sous l'utilisateur du service (voir plus bas).

## La cible n'est pas relancée

- Politique `on-failure` : une cible qui se termine avec le code `0` reste arrêtée. C'est le contrat, pas une panne. Utilisez `always` si elle doit être relancée après un arrêt propre.
- Politique `transient` : jamais relancée.
- Fichier d'arrêt présent : `ls -l /run/allwatch/demo.stop` ; retirez-le si l'arrêt n'était pas voulu. Le fichier n'arrête pas à lui seul une cible en cours.
- `ALERTE VERROU_CRITIQUE` : la cible a atteint `MAX_RESTARTS` dans `RESTART_WINDOW`. Corrigez la cause, puis redémarrez le service ; le verrou dure jusqu'au redémarrage du superviseur.
- `CRASHE code=N` : la cible s'est terminée avec le code N. Lisez son propre journal ; AllWatch ne rapporte que le code.

## La cible est déclarée bloquée alors qu'elle tourne

- La sonde est `timeout 3 bash -c ': > /dev/tcp/127.0.0.1/9001'`. La cible doit écouter sur `127.0.0.1` (ou `0.0.0.0`) sur le port déclaré. Une cible qui n'écoute que sur une autre adresse est considérée comme bloquée.
- Mauvais port dans `/etc/allwatch/allwatch.conf` ; vérifiez avec `ss -ltnp | grep 9001`.
- La cible est plus lente que `PROBE_TIMEOUT=3` ; augmentez-le dans la configuration, puis redémarrez le service.
- La cible est vivante mais son écoute est fermée ; c'est exactement l'état bloqué. Avec `ON_FREEZE=restart` (le défaut), AllWatch envoie `SIGTERM`, attend 5 secondes, puis `SIGKILL`, et la relance. Avec `ON_FREEZE=alert`, il journalise `ALERTE GEL` une fois et laisse la cible vivante ; `RETABLI` est journalisé quand le port répond de nouveau.

## `--diagnose` rend 0 mais la cible est malsaine

`--diagnose` est statique. Il lit la configuration et les chemins ; il ne sonde aucune cible. Un code de retour `0` prouve seulement que le superviseur peut lire la configuration et utiliser ses répertoires.

## Le double de test ne répond pas

- `netcat-openbsd` manque : `sudo apt install netcat-openbsd`.
- La commande emploie un chemin relatif. Le service tourne depuis `/var/lib/allwatch` ; employez le chemin absolu `/usr/share/doc/allwatch/examples/dummy-target.sh`.
- Le port est déjà utilisé : `ss -ltnp | grep 9001`.
- L'utilisateur du service ne peut pas exécuter le fichier : `sudo -u allwatch test -x /usr/share/doc/allwatch/examples/dummy-target.sh`.

## Le journal grossit sans limite

AllWatch ne fait pas tourner le journal. Employez logrotate ou un minuteur systemd ; le fichier est `/var/lib/allwatch/allwatch/allwatch.log`.

## Des cibles en double après un redémarrage du superviseur

`/run/allwatch` est retiré à l'arrêt du service. Une cible peut survivre à un plantage du superviseur sans son fichier PID ; le nouveau superviseur en lance un doublon. Ajoutez un drop-in :

```bash
sudo systemctl edit allwatch
```

```ini
[Service]
RuntimeDirectoryPreserve=restart
```

Puis redémarrez. Le répertoire d'exécution est conservé à travers un redémarrage du service, et le nouveau superviseur peut adopter le PID survivant.

## Rien dans le journal

Le service tourne sous `allwatch` et écrit dans `/var/lib/allwatch/allwatch/allwatch.log` ; vérifiez l'environnement du service avec `sudo systemctl show allwatch -p Environment`. Si le répertoire n'est pas inscriptible, le journal reste vide ; `--diagnose` le signale.
