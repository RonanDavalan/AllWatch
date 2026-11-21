# Den Debian-Dienst installieren und betreiben

Das Debian-Paket installiert AllWatch als systemd-Dienst. Der Dienst startet beim Booten, liest seine Konfiguration einmal und wartet, wenn kein Ziel deklariert ist. Dieses Kapitel nennt die genauen Pfade, Dateien und Befehle des Pakets.

## Was das Paket installiert

```text
/usr/bin/allwatch                          der Supervisor
/usr/bin/allwatch.sh                       Kompatibilitäts-Symlink
/usr/lib/systemd/system/allwatch.service   die systemd-Unit
/etc/allwatch/allwatch.conf                die Konfiguration
/usr/share/man/man1/allwatch.1.gz          Handbuchseite, Englisch
/usr/share/man/fr/man1/allwatch.1.gz       Handbuchseite, Französisch
/usr/share/man/de/man1/allwatch.1.gz       Handbuchseite, Deutsch
/usr/share/man/es/man1/allwatch.1.gz       Handbuchseite, Spanisch
/usr/share/doc/allwatch/README.Debian      Pakethinweise
/usr/share/doc/allwatch/examples/allwatch.conf.example
/usr/share/doc/allwatch/examples/dummy-target.sh
```

Das Paket legt den Systembenutzer und die Gruppe `allwatch` an (Home `/var/lib/allwatch`, Shell `/usr/sbin/nologin`). Der Dienst läuft unter dieser Kennung ab `/var/lib/allwatch`.

## Installieren

```bash
sudo apt install ./allwatch_0.1.0-4_all.deb
```

Das Paket installiert das Programm und die Unit, aktiviert `allwatch.service`, startet ihn und liefert eine Konfiguration ohne aktives Ziel.

Prüfen Sie Paketzustand und Programmversion:

```bash
dpkg -s allwatch | grep -E '^(Status|Version):'
allwatch --version
```

`allwatch --version` gibt `allwatch 0.1.0` aus; die Paketversion ist `0.1.0-4`.

## Pfade und Dateien

- `/etc/allwatch/allwatch.conf` ist eine Conffile von root und für den Dienstbenutzer nicht beschreibbar. Sie ist die Vertrauensgrenze: Zielbefehle laufen mit den Rechten des Dienstbenutzers.
- `/var/lib/allwatch` enthält Zustand und Protokoll, Modus `0700`, Eigentümer `allwatch:allwatch`, von systemd angelegt. Das flache Protokoll ist `/var/lib/allwatch/allwatch/allwatch.log`.
- `/run/allwatch` ist das Laufzeitverzeichnis, Modus `0700`, bei jedem Dienststart angelegt und beim Stoppen entfernt. Es enthält `<id>.pid`, `<id>.fails` und `<id>.stop`.
- `/var/lib/allwatch` und `/run/allwatch` überleben keine Purge; `/run/allwatch` überlebt keinen Stopp.

## Ein Ziel deklarieren

Bearbeiten Sie `/etc/allwatch/allwatch.conf` als root und fügen Sie eine Zeile pro Ziel hinzu:

```text
id port policy command...
```

Ein echtes Beispiel mit dem vom Paket installierten Testziel:

```bash
sudo apt install netcat-openbsd
sudo cp /usr/share/doc/allwatch/examples/allwatch.conf.example /etc/allwatch/allwatch.conf
sudo systemctl restart allwatch
```

Das Beispiel deklariert:

```text
demo 9001 on-failure /usr/share/doc/allwatch/examples/dummy-target.sh 9001
```

Prüfen Sie den Port:

```bash
bash -c ': > /dev/tcp/127.0.0.1/9001' && echo "Port 9001 antwortet"
```

Der Dienstbenutzer muss den Befehl ausführen können. Verwenden Sie absolute Pfade: Der Befehl wird an Leerzeichen getrennt, ohne Anführungszeichen, und nicht über eine Shell gestartet. Für Argumente mit Leerzeichen oder Shell-Syntax schreiben Sie ein Wrapper-Skript und rufen es auf.

## Hängendes Ziel: restart oder alert

`ON_FREEZE` entscheidet, was mit einem Ziel geschieht, das noch lebt, dessen TCP-Port aber nach der Gnadenfrist nicht mehr antwortet. `ON_FREEZE=restart` (der ausgelieferte Standard) sendet `SIGTERM`, wartet etwa fünf Sekunden, sendet bei Bedarf `SIGKILL` und startet das Ziel gemäß seiner Richtlinie neu. `ON_FREEZE=alert` sendet kein Signal: Es schreibt einmal `ALERTE GEL`, lässt das Ziel laufen und schreibt `RETABLI`, wenn der Port wieder antwortet. Ein Absturz folgt in beiden Fällen der Richtlinie des Ziels. Jeder andere Wert wird beim Start mit Exit-Code 1 zurückgewiesen.

## Dienstbefehle

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

Die Konfiguration wird einmal beim Start gelesen; eine Änderung erfordert `sudo systemctl restart allwatch`. Es gibt kein Hot-Reload.

## Die Konfiguration prüfen, ohne ein Ziel zu starten

Führen Sie `--diagnose` mit der Dienstumgebung und als Dienstbenutzer aus:

```bash
sudo -u allwatch env ALLWATCH_RUNTIME=/run/allwatch \
  XDG_STATE_HOME=/var/lib/allwatch \
  allwatch --diagnose /etc/allwatch/allwatch.conf
```

Es zeigt Version, Konfigurationspfad, Laufzeitpfad, Protokollpfad, das Verhalten bei Hängern und für jedes Ziel Kennung, Port und Richtlinie. Es endet mit `0`, wenn die Konfiguration lesbar und die vorhandenen Laufzeit- und Protokollverzeichnisse nutzbar sind, sonst mit `1`. Es startet kein Ziel und sondiert keinen Port.

## Ein Ziel stoppen, ohne den Dienst zu stoppen

Legen Sie die Stoppdatei als Dienstbenutzer an:

```bash
sudo -u allwatch touch /run/allwatch/demo.stop
```

AllWatch entfernt die Datei, wenn das Ziel endet, und startet es nicht neu. Die Datei stoppt ein laufendes Ziel nicht von selbst; senden Sie `SIGTERM` an das Ziel oder lassen Sie es enden.

## Den Dienst unter einem anderen Benutzer betreiben

Der Dienst läuft als `allwatch`. Wenn ein Ziel root oder ein anderes Konto braucht, legen Sie ein Drop-in an:

```bash
sudo systemctl edit allwatch
```

Fügen Sie hinzu:

```ini
[Service]
User=www-data
Group=www-data
```

Dann neu starten:

```bash
sudo systemctl restart allwatch
```

Die Zielbefehle erben diese Identität. Die Konfigurationsdatei bleibt Eigentum von root.

## Aktualisieren

```bash
sudo apt install ./allwatch_0.1.0-4_all.deb
```

`/etc/allwatch/allwatch.conf` bleibt erhalten; wenn die Paketversion sie ändert, fragt dpkg, welche Version behalten werden soll. Der Dienst wird nach der Aktualisierung neu gestartet, wenn er aktiv war. `/var/lib/allwatch` und sein Protokoll bleiben.

## Entfernen und purgen

```bash
sudo apt remove allwatch
sudo apt purge allwatch
```

`apt remove` stoppt den Dienst, entfernt Programm, Unit, Handbuchseiten und Paketdokumentation. Es behält `/etc/allwatch/allwatch.conf`, `/var/lib/allwatch` sowie Benutzer und Gruppe `allwatch`. Die Unit wird nicht deaktiviert; der Aktivierungszustand von deb-systemd-helper bleibt bis zur Purge.

`apt purge` entfernt zusätzlich die Conffile, `/var/lib/allwatch`, `/etc/allwatch` wenn leer, Benutzer und Gruppe `allwatch` wenn möglich sowie den Aktivierungszustand. Wenn ein Prozess das Konto noch nutzt, können `userdel` oder `groupdel` scheitern; prüfen Sie mit:

```bash
getent passwd allwatch
getent group allwatch
```

## Bekannte Grenzen des Pakets

- Die Containervalidierung installiert das Paket, prüft `--version`, `--help` und `--diagnose` und entfernt es wieder. Sie startet systemd nicht; der Dienst ist installiert und dokumentiert, aber im Container nicht unter systemd validiert.
- `--diagnose` ist statisch: Es sondiert keine Ziele.
- `/run/allwatch` überlebt einen Dienststopp nicht. Nach einem Supervisor-Absturz können Ziele ohne PID-Datei überleben; der neu gestartete Supervisor kann Duplikate starten. Ein Drop-in mit `RuntimeDirectoryPreserve=restart` behält das Verzeichnis über einen Dienstneustart hinweg.
