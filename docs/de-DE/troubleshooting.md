# Fehlerbehebung

AllWatch hat keinen Statusbefehl. Der Zustand eines Ziels wird aus dem Prozess, dem TCP-Port und dem flachen Protokoll gelesen. Dieses Kapitel nennt die genauen Befehle für die häufigen Störungen.

## Zuerst den Dienstzustand lesen

```bash
sudo systemctl status allwatch
sudo journalctl -u allwatch -n 50 --no-pager
sudo tail -n 50 /var/lib/allwatch/allwatch/allwatch.log
```

Die Protokollzeilen sind `Datum id Ereignis`. Die Ereignisse sind `DEMARRAGE`, `DEMARRE`, `ADOPTE`, `PLANTE`, `NEUTRALISE SIGTERM`, `NEUTRALISE SIGKILL`, `CRASHE code=N`, `RELANCE`, `ALERTE VERROU_CRITIQUE`, `QUITTE` und `ARRET`.

## Der Dienst startet nicht

- `allwatch: configuration illisible : /etc/allwatch/allwatch.conf` — die Datei fehlt oder ist für den Dienstbenutzer nicht lesbar. Prüfen Sie `sudo -u allwatch test -r /etc/allwatch/allwatch.conf` und `sudo systemctl cat allwatch`.
- `allwatch: /run/allwatch n'appartient pas à l'utilisateur` — das Laufzeitverzeichnis gehört einem anderen Benutzer. Prüfen Sie `ls -ld /run/allwatch /var/lib/allwatch`; die Unit legt sie für `allwatch` an. Wenn Sie ein Drop-in mit einem anderen `User=` hinzugefügt haben, korrigieren Sie den Eigentümer oder entfernen Sie das Drop-in.
- `status=203/EXEC` — das Programm fehlt oder ist nicht ausführbar. Installieren Sie das Paket neu.
- `status=1/FAILURE` mit einem Konfigurationsfehler — führen Sie `--diagnose` als Dienstbenutzer aus (siehe unten).

## Das Ziel wird nicht neu gestartet

- Richtlinie `on-failure`: Ein Ziel, das mit Code `0` endet, bleibt gestoppt. Das ist der Vertrag, kein Fehler. Verwenden Sie `always`, wenn es nach einem sauberen Ende neu starten soll.
- Richtlinie `transient`: wird nie neu gestartet.
- Stoppdatei vorhanden: `ls -l /run/allwatch/demo.stop`; entfernen Sie sie, wenn der Stopp nicht gewollt war. Die Datei stoppt ein laufendes Ziel nicht von selbst.
- `ALERTE VERROU_CRITIQUE`: Das Ziel hat `MAX_RESTARTS` in `RESTART_WINDOW` erreicht. Beheben Sie die Ursache und starten Sie den Dienst neu; die Sperre gilt bis zum Neustart des Supervisors.
- `CRASHE code=N`: Das Ziel endete mit Code N. Lesen Sie sein eigenes Protokoll; AllWatch meldet nur den Code.

## Das Ziel gilt als blockiert, obwohl es läuft

- Die Sonde ist `timeout 3 bash -c ': > /dev/tcp/127.0.0.1/9001'`. Das Ziel muss auf `127.0.0.1` (oder `0.0.0.0`) am deklarierten Port lauschen. Ein Ziel, das nur auf einer anderen Adresse lauscht, gilt als blockiert.
- Falscher Port in `/etc/allwatch/allwatch.conf`; prüfen Sie mit `ss -ltnp | grep 9001`.
- Das Ziel ist langsamer als `PROBE_TIMEOUT=3`; erhöhen Sie den Wert in der Konfiguration und starten Sie den Dienst neu.
- Das Ziel lebt, aber sein Listener ist geschlossen; genau das ist der Blockierzustand. AllWatch sendet `SIGTERM`, wartet 5 Sekunden, sendet `SIGKILL` und startet das Ziel neu.

## `--diagnose` endet mit 0, aber das Ziel ist ungesund

`--diagnose` ist statisch. Es liest die Konfiguration und die Pfade; es sondiert kein Ziel. Ein Rückgabecode `0` beweist nur, dass der Supervisor die Konfiguration lesen und seine Verzeichnisse nutzen kann.

## Das Testziel antwortet nicht

- `netcat-openbsd` fehlt: `sudo apt install netcat-openbsd`.
- Der Befehl verwendet einen relativen Pfad. Der Dienst läuft ab `/var/lib/allwatch`; verwenden Sie den absoluten Pfad `/usr/share/doc/allwatch/examples/dummy-target.sh`.
- Der Port ist bereits belegt: `ss -ltnp | grep 9001`.
- Der Dienstbenutzer kann die Datei nicht ausführen: `sudo -u allwatch test -x /usr/share/doc/allwatch/examples/dummy-target.sh`.

## Das Protokoll wächst unbegrenzt

AllWatch rotiert das Protokoll nicht. Verwenden Sie logrotate oder einen systemd-Timer; die Datei ist `/var/lib/allwatch/allwatch/allwatch.log`.

## Doppelte Ziele nach einem Supervisor-Neustart

`/run/allwatch` wird beim Dienststopp entfernt. Ein Ziel kann einen Supervisor-Absturz ohne seine PID-Datei überleben; der neue Supervisor startet ein Duplikat. Fügen Sie ein Drop-in hinzu:

```bash
sudo systemctl edit allwatch
```

```ini
[Service]
RuntimeDirectoryPreserve=restart
```

Dann neu starten. Das Laufzeitverzeichnis bleibt über einen Dienstneustart erhalten, und der neue Supervisor kann die überlebende PID übernehmen.

## Nichts im Protokoll

Der Dienst läuft als `allwatch` und schreibt nach `/var/lib/allwatch/allwatch/allwatch.log`; prüfen Sie die Dienstumgebung mit `sudo systemctl show allwatch -p Environment`. Wenn das Verzeichnis nicht beschreibbar ist, bleibt das Protokoll leer; `--diagnose` meldet es.
