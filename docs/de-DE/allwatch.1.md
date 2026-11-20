% ALLWATCH(1) allwatch | Benutzerbefehle
% Ronan Davalan
% 2026-11-20

# NAME

allwatch - kleiner Prozess-Supervisor für Linux

# ÜBERSICHT

**allwatch** [*KONFIGURATION*]

**allwatch** **--version**

**allwatch** **--diagnose** [*KONFIGURATION*]

# BESCHREIBUNG

**allwatch** ist ein kleiner Prozess-Supervisor, geschrieben in Bash. Er
startet jedes konfigurierte Ziel im Vordergrund, merkt sich die vom Kernel
vergebene PID und beurteilt die Gesundheit des Ziels nur anhand von drei
Quellen: der Prozess existiert in `/proc`, sein TCP-Port nimmt eine
Verbindung an, und der Exit-Code, den er bei seinem Ende zurückgegeben hat.

Das Ziel ist eine Blackbox. Es registriert sich nicht bei AllWatch, sendet
keine Statusmeldungen und muss nicht wissen, dass AllWatch existiert. Der
Supervisor ist der Elternprozess, das Ziel ist das Kind.

# OPTIONEN

**--version**
:   `allwatch 0.1.0` ausgeben und mit Exit-Code `0` beenden.

**--diagnose** [*KONFIGURATION*]
:   Die Konfiguration lesen, Version, Konfigurationspfad, Zustandsverzeichnis,
    Journalpfad und die konfigurierten Ziele ausgeben und beenden. Startet und
    prüft kein Ziel und schreibt weder Zustand noch Journal. Exit-Code `0`,
    wenn die Konfiguration lesbar und die vorhandenen Zustands- und
    Journalverzeichnisse nutzbar sind, sonst `1`.

# KONFIGURATION

Die Konfiguration wird beim Start einmal zeilenweise gelesen. Leere Zeilen
und Zeilen, die mit `#` beginnen, werden ignoriert.

Engine-Parameter, je eine Zeile `SCHLÜSSEL=Wert`:

**POLL_SECONDS**=*SEKUNDEN*
:   Sekunden zwischen zwei Prüfungen (Standard `5`).

**PROBE_TIMEOUT**=*SEKUNDEN*
:   Sekunden, die der TCP-Port für die Sonde Zeit hat (Standard `3`).

**MAX_RESTARTS**=*ANZAHL*
:   Neustarts, die im Fenster erlaubt sind, bevor das Ziel gesperrt wird
    (Standard `5`).

**RESTART_WINDOW**=*SEKUNDEN*
:   Länge des Zeitfensters für die Neustartzählung (Standard `60`).

Ziele, eines pro Zeile:

    id port richtlinie befehl...

**id**
:   Ein kurzer, eindeutiger Name für Zustandsdateien und Journalzeilen.

**port**
:   Der TCP-Port, auf dem das Ziel lauscht, geprüft auf `127.0.0.1`.

**richtlinie**
:   `always`, `on-failure` oder `transient`.

**befehl...**
:   Der Rest der Zeile, an Leerzeichen getrennt (ohne Anführungszeichen),
    im Vordergrund aus dem Verzeichnis gestartet, in dem **allwatch**
    gestartet wurde.

Richtlinien:

**always**
:   Das Ziel nach jedem Ende neu starten, auch bei Exit-Code 0, außer eine
    Datei `id.stop` existiert im Zustandsverzeichnis.

**on-failure**
:   Nach einem Absturz oder Hänger neu starten; nach einem sauberen Ende mit
    Code 0 gestoppt lassen.

**transient**
:   Das Ziel nie neu starten.

Ein anderer Richtlinienwert als diese drei wird nicht zurückgewiesen: Das Ziel
wird dann wie `always` behandelt.

Um ein bewusstes Ende zu verlangen, vor dem Ende des Ziels eine Datei
`id.stop` im Zustandsverzeichnis anlegen (`touch /run/allwatch/id.stop` für
den Debian-Dienst). AllWatch entfernt die Datei und startet das Ziel nicht
neu. Die Datei stoppt ein laufendes Ziel nicht von selbst.

# ZUSTÄNDE

AllWatch meldet vier gewöhnliche Zustände, dazu einen Ausnahmezustand der
Sperre:

**Läuft**
:   Der Prozess existiert und sein Port nimmt eine Verbindung an.

**Hängt**
:   Der Prozess existiert, aber sein Port antwortet nicht. Nach einer
    Gnadenfrist sendet AllWatch `SIGTERM`, wartet bis zu 5 Sekunden auf das
    Ende, sendet bei Bedarf `SIGKILL` und behandelt das Ziel als fehlerhaft.

**Abgestürzt**
:   Der Prozess ist ohne bewusstes Ende verschwunden. AllWatch liest den
    Exit-Code und startet das Ziel neu, wenn seine Richtlinie es verlangt.
    Bei einem Ziel, das nach einem Neustart des Supervisors übernommen wurde,
    ist der Exit-Code nicht verfügbar; sein Verschwinden gilt als Fehler.

**Beendet**
:   Das Ziel ist zu Ende und seine Richtlinie lässt es gestoppt, oder ein
    Stopp-Flag des Betreibers wurde berücksichtigt. Die Zustandsdatei wird
    entfernt.

**Gesperrt (VERROU_CRITIQUE)**
:   Das Ziel hat `MAX_RESTARTS` Neustarts innerhalb von `RESTART_WINDOW`
    erreicht. AllWatch beendet die Neustarts, schreibt eine Warnung und
    entfernt die Zustandsdatei. Die anderen Ziele laufen weiter.

# DATEIEN

*/tmp/allwatch-runtime*
:   Standard-Zustandsverzeichnis: eine Datei `id.pid` und eine Datei
    `id.fails` pro Ziel; eine Datei `id.stop` wird vom Betreiber angelegt,
    um ein bewusstes Ende zu verlangen. AllWatch entfernt beim Stoppen seine
    eigenen Dateien `.pid`, `.stop` und `.fails`; andere Dateien bleiben. Das
    Verzeichnis lässt sich mit der Umgebungsvariable `ALLWATCH_RUNTIME`
    ändern.

*$XDG_STATE_HOME/allwatch/allwatch.log*, *$HOME/.local/state/allwatch/allwatch.log*
:   Flaches Ereignisjournal, eine Zeile pro Ereignis (`Datum id Ereignis`).
    Das Verzeichnis wird bei Bedarf angelegt. AllWatch rotiert das Journal
    nicht.

*/etc/allwatch/allwatch.conf*
:   Konfiguration des Debian-Dienstes, vom Paket `allwatch` installiert.

*/run/allwatch*
:   Zustandsverzeichnis des Debian-Dienstes (`ALLWATCH_RUNTIME`), bei jedem
    Start neu angelegt und bei jedem Stopp geleert.

*/var/lib/allwatch/allwatch/allwatch.log*
:   Journal des Debian-Dienstes (`XDG_STATE_HOME=/var/lib/allwatch`).

# DIENST

Das Debian-Paket installiert `allwatch.service`; dieser startet **allwatch**
als Systembenutzer `allwatch` mit `/etc/allwatch/allwatch.conf`. systemd
startet den Supervisor nach jedem Ende neu (`Restart=always`, ohne
Startbegrenzung); AllWatch startet danach seine Ziele gemäß ihrer Richtlinie
neu. Die Konfiguration wird nicht im laufenden Betrieb neu geladen: nach
einer Änderung ausführen:

    systemctl restart allwatch

Nützliche Befehle:

    systemctl status allwatch
    systemctl start allwatch
    systemctl stop allwatch
    systemctl restart allwatch
    journalctl -u allwatch -f

# SIGNALE

**SIGTERM**, **SIGINT**
:   Der Supervisor stoppt jedes Ziel mit `SIGTERM`, wartet auf dessen Ende,
    sendet nach 5 Sekunden bei Bedarf `SIGKILL`, entfernt seine
    Zustandsdateien und beendet sich (`130` für `SIGINT`, `143` für
    `SIGTERM`).

**SIGTERM** an ein Ziel
:   Das Ziel muss innerhalb von 5 Sekunden mit Exit-Code 0 enden. Ein Ziel,
    das nach einem Hänger neutralisiert werden musste, gilt als fehlerhaft
    und wird gemäß seiner Richtlinie neu gestartet, auch wenn es nach dem
    Signal mit Code 0 endet.

# EXIT-STATUS

**0**
:   Wird von `--version` und einem erfolgreichen `--diagnose` zurückgegeben.
    Die Überwachungsschleife endet nicht von selbst: Sie läuft bis `SIGINT`
    oder `SIGTERM` und gibt im Normalbetrieb daher nicht `0` zurück.

**1**
:   Konfigurationsdatei nicht lesbar, Zustandsverzeichnis gehört nicht dem
    aktuellen Benutzer, eine Pfadprüfung von `--diagnose` ist fehlgeschlagen,
    oder ein fataler Laufzeitfehler (ungültiger Parameterwert, nicht
    beschreibbares Zustands- oder Journalverzeichnis).

**130**
:   Unterbrochen durch `SIGINT`.

**143**
:   Beendet durch `SIGTERM`.

# BEISPIELE

Den Supervisor mit der Beispielkonfiguration aus dem Quelltext starten:

    ./allwatch.sh allwatch.conf

Konfiguration mit einem Ziel:

    POLL_SECONDS=5
    PROBE_TIMEOUT=3
    MAX_RESTARTS=5
    RESTART_WINDOW=60
    demo 9001 on-failure ./dummy-target.sh 9001

Mit dem Debian-Paket absolute Pfade verwenden, weil der Dienst aus
`/var/lib/allwatch` läuft:

    demo 9001 on-failure /usr/share/doc/allwatch/examples/dummy-target.sh 9001

# GRENZEN

- Kein Neuladen der Konfiguration im laufenden Betrieb.
- Keine Auswertung von Anwendungsjournalen für Neustarts.
- Keine Prüfung über Fenstertitel, X11 oder Wayland.
- Keine Überwachung eines Ziels, das sich im Hintergrund ablöst.
- Konfigurationswerte und Richtliniennamen werden nicht geprüft: Eine falsch
  geschriebene Richtlinie wirkt wie `always`, und ein nicht numerischer oder
  Null-Zeitwert kann die Schleife abbrechen.
- Nach einem Neustart des Supervisors ist der Exit-Code eines übernommenen
  Ziels nicht verfügbar; sein Verschwinden gilt als Fehler.
- Das flache Journal wird nicht rotiert.
- Bei mehr als vier Zielen kann ein sauberes Stoppen das `TimeoutStopSec`
  von 20 Sekunden des Dienstes überschreiten; systemd beendet dann die ganze
  Prozessgruppe.
- `--help` ist nicht implementiert; die Handbuchseite ist die Referenz.
- `--diagnose` prüft Konfiguration und Pfade; es startet und prüft kein Ziel,
  beweist also nicht, dass ein Ziel gesund ist.

# SIEHE AUCH

**systemd.service**(5), **systemd.exec**(5), **proc**(5)

# LIZENZ

MIT. Copyright (c) 2026 Ronan Davalan. Siehe
`/usr/share/doc/allwatch/LICENSE`.
