% ALLWATCH(1) allwatch | Benutzerbefehle
% Ronan Davalan
% 2026-11-22

# NAME

allwatch - kleiner Prozess-Supervisor für Linux

# ÜBERSICHT

**allwatch** [*KONFIGURATION*]

**allwatch** **--version**

**allwatch** **--diagnose** [*KONFIGURATION*]

**allwatch** **--help**

# BESCHREIBUNG

**allwatch** ist ein kleiner Prozess-Supervisor, geschrieben in Bash. Er
startet jedes konfigurierte Ziel als Kindprozess, merkt sich die vom Kernel
vergebene PID und beurteilt den Zustand des Ziels nur anhand von drei
Quellen: der Prozess existiert in `/proc`, sein TCP-Port nimmt eine Verbindung
an, und der Exit-Code, den er bei seinem Ende zurückgegeben hat. Das Ziel muss
im Vordergrund bleiben; ein Ziel, das sich im Hintergrund ablöst, bricht die
Eltern-Kind-Beziehung.

Das Ziel ist eine Blackbox. Es registriert sich nicht bei AllWatch, sendet
keine Statusmeldungen und muss nicht wissen, dass AllWatch existiert. Der
Supervisor ist der Elternprozess, das Ziel ist das Kind.

Die Konfiguration wird beim Start einmal gelesen. Standard ist
`allwatch.conf` im aktuellen Verzeichnis; das erste Argument ersetzt sie.

**--version**
:   `allwatch 0.1.0` ausgeben und mit Exit-Code `0` beenden.

**--help**
:   Übersicht, Optionen, Umgebungsvariablen und den Verweis auf diese
    Handbuchseite ausgeben und mit Exit-Code `0` beenden.

**--diagnose** [*KONFIGURATION*]
:   Die Konfiguration lesen, Version, Konfigurationspfad, Zustandsverzeichnis,
    Journalpfad, das Verhalten bei Hängern, die Anzahl der Ziele sowie Kennung,
    Port und Richtlinie jedes konfigurierten Ziels ausgeben und beenden. Es
    meldet außerdem, ob ein vorhandenes Zustandsverzeichnis ein dem aktuellen
    Benutzer gehörendes Verzeichnis ist und ob ein vorhandenes
    Journalverzeichnis beschreibbar ist. Startet und prüft kein Ziel und
    schreibt weder Zustand noch Journal. Ein Konfigurationsfehler wird vor
    jeder Auflistung auf der Standardfehlerausgabe gemeldet. Exit-Code `0`,
    wenn die Konfiguration lesbar ist, ein vorhandenes Zustandsverzeichnis dem
    aktuellen Benutzer gehört und ein vorhandenes Journalverzeichnis
    beschreibbar ist. Exit-Code `1` bei unlesbarer Konfiguration, ungültigem
    `ON_FREEZE`, nicht numerischem `POLL_SECONDS`, einem vorhandenen
    Zustandsverzeichnis, das kein dem aktuellen Benutzer gehörendes Verzeichnis
    ist, oder einem vorhandenen Journalverzeichnis, das nicht beschreibbar
    ist.

Die Optionen werden nur als erstes Argument erkannt.

# KONFIGURATION

Die Konfiguration wird beim Start einmal zeilenweise gelesen. Leere Zeilen
und Zeilen, die mit `#` beginnen, werden ignoriert.

Engine-Parameter, je eine Zeile `SCHLÜSSEL=Wert`:

**POLL_SECONDS**=*SEKUNDEN*
:   Sekunden zwischen zwei Prüfungen (Standard `5`). Die Gnadenfrist bei
    einem Hänger beträgt `2 * POLL_SECONDS`.

**PROBE_TIMEOUT**=*SEKUNDEN*
:   Sekunden, die der TCP-Port für die Sonde Zeit hat (Standard `3`).

**MAX_RESTARTS**=*ANZAHL*
:   Neustarts, die im Fenster erlaubt sind, bevor das Ziel gesperrt wird
    (Standard `5`).

**RESTART_WINDOW**=*SEKUNDEN*
:   Länge des Zeitfensters für die Neustartzählung (Standard `60`).

**ON_FREEZE**=*restart*|*alert*
:   Verhalten für ein Ziel, das noch lebt, dessen Port aber nach der
    Gnadenfrist nicht mehr antwortet. `restart` (Standard) sendet `SIGTERM`,
    wartet etwa 5 Sekunden, sendet bei Bedarf `SIGKILL` und behandelt das Ziel
    als fehlerhaft; `alert` sendet kein Signal, schreibt einmal `ALERTE GEL`,
    lässt das Ziel überwacht und schreibt `RETABLI`, wenn der Port wieder
    antwortet. Ein Absturz folgt in beiden Fällen der Richtlinie des Ziels.
    Jeder andere Wert wird beim Start mit Exit-Code `1` zurückgewiesen.

Die numerischen Werte und Richtliniennamen werden unverändert verwendet und
nicht geprüft; `ON_FREEZE` ist die Ausnahme und akzeptiert nur `restart` oder
`alert`.

Ziele, eines pro Zeile:

    id port richtlinie befehl...

**id**
:   Ein kurzer, eindeutiger Name für Zustandsdateien und Journalzeilen. Er
    darf weder `/` noch `..` enthalten; AllWatch prüft ihn nicht.

**port**
:   Der TCP-Port, auf dem das Ziel lauscht. Er wird auf `127.0.0.1` geprüft;
    ein Ziel, das nur auf einer anderen Adresse lauscht, gilt als hängend.

**richtlinie**
:   `always`, `on-failure` oder `transient`.

**befehl...**
:   Der Rest der Zeile, an Leerzeichen getrennt (ohne Anführungszeichen), als
    Kindprozess aus dem Verzeichnis gestartet, in dem **allwatch** gestartet
    wurde. Der Befehl wird nicht über eine Shell ausgeführt: Pipes,
    Umleitungen und Variablenexpansion werden nicht interpretiert; solche
    Logik gehört in ein ausführbares Skript. Beim Debian-Dienst absolute
    Pfade verwenden.

Richtlinien:

**always**
:   Das Ziel nach jedem Ende neu starten, auch bei Exit-Code 0, außer eine
    Datei `id.stop` existiert im Zustandsverzeichnis.

**on-failure**
:   Nach einem Absturz oder nach einem Hänger, den AllWatch neutralisiert hat
    (`ON_FREEZE=restart`), neu starten; nach einem sauberen Ende mit Code 0
    gestoppt lassen. Mit `ON_FREEZE=alert` bleibt ein hängendes Ziel am Leben
    und wird nicht neu gestartet.

**transient**
:   Das Ziel nie neu starten.

Ein anderer Richtlinienwert als diese drei wird nicht zurückgewiesen: Das Ziel
wird dann wie `always` behandelt.

Um ein bewusstes Ende zu verlangen, vor dem Ende des Ziels eine Datei
`id.stop` im Zustandsverzeichnis anlegen (`touch /run/allwatch/id.stop` für
den Debian-Dienst). AllWatch entfernt die Datei und startet das Ziel nicht
neu. Die Datei stoppt ein laufendes Ziel nicht von selbst.

# ZUSTÄNDE

Der Supervisor unterscheidet vier gewöhnliche Zustände und einen
Ausnahmezustand der Sperre. Es gibt keinen Statusbefehl: Ein Zustand ist über
den Prozess, den Port und das einfache Textjournal sichtbar.

**Läuft**
:   Der Prozess existiert und sein Port nimmt eine Verbindung an.

**Hängt**
:   Der Prozess existiert, aber sein Port antwortet nicht. AllWatch markiert
    das Ziel bei der ersten fehlgeschlagenen Sonde als verdächtig und wartet
    `2 * POLL_SECONDS` Sekunden. Ist der Port weiterhin geschlossen, hängt das
    Verhalten von `ON_FREEZE` ab: `restart` sendet `SIGTERM`, wartet etwa 5
    Sekunden auf das Ende, sendet bei Bedarf `SIGKILL` und behandelt das Ziel
    als fehlerhaft; `alert` sendet kein Signal, schreibt einmal `ALERTE GEL`,
    lässt das Ziel überwacht und schreibt `RETABLI`, wenn der Port wieder
    antwortet. Stirbt der Prozess während des Hängens, gilt das Ziel als
    abgestürzt.

**Abgestürzt**
:   Der Prozess ist ohne bewusstes Ende verschwunden. AllWatch liest den
    Exit-Code und startet das Ziel neu, wenn seine Richtlinie es verlangt. Bei
    einem Ziel, das nach einem Neustart des Supervisors übernommen wurde, ist
    der Exit-Code nicht verfügbar; sein Verschwinden gilt als Fehler.

**Beendet**
:   Das Ziel ist zu Ende und seine Richtlinie lässt es gestoppt, oder ein
    Stopp-Flag des Betreibers wurde berücksichtigt. Die PID-Datei wird
    entfernt, ebenso die Stopp-Datei, wenn eine verwendet wurde; das Ziel wird
    bis zum Neustart des Supervisors nicht mehr überwacht.

**Gesperrt (VERROU_CRITIQUE)**
:   Das Ziel hat `MAX_RESTARTS` Neustarts innerhalb von `RESTART_WINDOW`
    erreicht. AllWatch beendet die Neustarts, schreibt eine Warnung und
    entfernt die PID-Datei. Die anderen Ziele laufen weiter. Die Sperre dauert
    bis zum Neustart des Supervisors; das Ziel wird nicht automatisch erneut
    versucht.

# DATEIEN

*/tmp/allwatch-runtime*
:   Standard-Zustandsverzeichnis eines manuellen Laufs. Es enthält eine Datei
    `id.pid` und eine Datei `id.fails` pro Ziel; eine Datei `id.stop` wird vom
    Betreiber angelegt, um ein bewusstes Ende zu verlangen. Das Verzeichnis
    wird mit Modus `0700` angelegt, wenn es fehlt; ein vorhandenes Verzeichnis
    muss dem aktuellen Benutzer gehören. AllWatch entfernt beim Stoppen die
    Dateien `.pid`, `.stop` und `.fails` aus dem Verzeichnis; andere Dateien
    bleiben. Das Verzeichnis lässt sich mit der Umgebungsvariable
    `ALLWATCH_RUNTIME` ändern.

`$XDG_STATE_HOME/allwatch/allwatch.log`, `$HOME/.local/state/allwatch/allwatch.log`
:   Ereignisprotokoll als einfache Textdatei, eine Zeile pro Ereignis (`Datum id Ereignis`).
    Das Verzeichnis wird bei Bedarf angelegt. AllWatch rotiert das Journal
    nicht.

*allwatch.conf*
:   Standard-Konfigurationsdatei im aktuellen Verzeichnis, wenn kein Argument
    angegeben ist.

*/etc/allwatch/allwatch.conf*
:   Konfiguration des Debian-Dienstes, vom Paket `allwatch` als conffile
    installiert.

*/run/allwatch*
:   Zustandsverzeichnis des Debian-Dienstes (`ALLWATCH_RUNTIME`), bei jedem
    Dienststart angelegt und beim Stopp entfernt.

*/var/lib/allwatch/allwatch/allwatch.log*
:   Journal des Debian-Dienstes (`XDG_STATE_HOME=/var/lib/allwatch`). systemd
    legt `/var/lib/allwatch` an; das Skript legt sein Unterverzeichnis
    `allwatch` an.

*/usr/bin/allwatch*
:   Installiertes Programm (Debian-Paket).

*/usr/lib/systemd/system/allwatch.service*
:   Von Debian-Paket installierte systemd-Unit.

# DIENST

Das Debian-Paket installiert `allwatch.service`; dieser startet **allwatch**
als Systembenutzer `allwatch` mit `/etc/allwatch/allwatch.conf`. Mit der
ausgelieferten Konfiguration startet der Dienst ohne aktives Ziel und wartet.
systemd startet den Supervisor nach jedem Ende außer einem ausdrücklichen
`systemctl stop` neu (`Restart=always`, ohne Startbegrenzung). AllWatch
startet danach seine Ziele gemäß ihrer Richtlinie neu. Die Konfiguration wird nicht im laufenden Betrieb neu geladen: nach einer
Änderung ausführen:

    systemctl restart allwatch

Die Befehle der Ziele erben Benutzer, Gruppe und Arbeitsverzeichnis
(`/var/lib/allwatch`) des Dienstes. Um den Dienst und alle seine Ziele unter
einem anderen Benutzer auszuführen, ein Drop-in mit `systemctl edit allwatch`
anlegen und `User=` und `Group=` setzen.

Nützliche Befehle:

    systemctl status allwatch
    systemctl start allwatch
    systemctl stop allwatch
    systemctl restart allwatch
    systemctl enable allwatch
    systemctl disable allwatch
    journalctl -u allwatch -f

Die `.rpm`-Pakete für Fedora und openSUSE Leap und das Paket für Arch Linux installieren dieselbe Dienst-Unit, dieselbe Konfiguration und dasselbe Programm an denselben Pfaden. Sie starten den Dienst nicht: Führen Sie `systemctl enable --now allwatch` aus, sobald die Ziele eingetragen sind.

# SIGNALE

**SIGTERM**, **SIGINT**
:   Der Supervisor stoppt jedes noch vorhandene Ziel mit `SIGTERM`, wartet
    etwa 5 Sekunden auf dessen Ende, sendet bei Bedarf `SIGKILL`, entfernt
    die Dateien `.pid`, `.stop` und `.fails`, schreibt `allwatch ARRET` ins
    Journal und beendet sich (`130` für `SIGINT`, `143` für `SIGTERM`).

**SIGTERM** an ein Ziel
:   Das Ziel behandelt das Signal; AllWatch beobachtet den resultierenden
    Exit-Code, wenn es das Ziel gestartet hat, und wendet die Richtlinie des
    Ziels an. Bei einem nach einem Supervisor-Neustart übernommenen Ziel ist
    der Exit-Code nicht verfügbar; sein Verschwinden gilt als Fehler. Der
    Zielvertrag verlangt ein Ende innerhalb von 5 Sekunden mit Exit-Code 0.
    Wenn AllWatch ein hängendes Ziel selbst neutralisiert, gilt das Ziel als
    fehlerhaft, auch wenn es später mit Code 0 endet.

**SIGHUP**
:   Nicht abgefangen. Es lädt die Konfiguration nicht neu und beendet
    normalerweise den Supervisor; systemd startet ihn dann neu. Zum Neuladen
    der Konfiguration `systemctl restart allwatch` verwenden.

**SIGKILL**
:   Kann nicht abgefangen werden. AllWatch führt seine Bereinigung nicht aus.
    Bei einem manuellen Lauf überleben die Ziele, und das Zustandsverzeichnis
    bleibt erhalten; der nächste Supervisor kann lebende Ziele übernehmen.
    Beim Debian-Dienst verwaltet systemd die Prozessgruppe und entfernt
    `/run/allwatch` beim Stopp der Unit; dem nächsten Supervisor können die
    PID-Dateien fehlen, und er kann Doppelstarts verursachen. Nach einem
    `SIGKILL` nicht auf eine Übernahme verlassen.

# RÜCKGABEWERT

**0**
:   Wird von `--version`, `--help` und einem erfolgreichen `--diagnose`
    zurückgegeben. Die Überwachungsschleife endet nicht von selbst: Sie läuft
    bis `SIGINT` oder `SIGTERM` und gibt im Normalbetrieb daher nicht `0`
    zurück.

**1**
:   Konfigurationsdatei nicht lesbar, ungültiges `ON_FREEZE`,
    Zustandsverzeichnis gehört nicht dem aktuellen Benutzer, eine Pfadprüfung
    von `--diagnose` ist fehlgeschlagen, oder ein fataler Laufzeitfehler (zum
    Beispiel ein nicht numerischer `POLL_SECONDS` oder ein nicht
    beschreibbares Zustands- oder Journalverzeichnis).

**130**
:   Unterbrochen durch `SIGINT`.

**143**
:   Beendet durch `SIGTERM`.

Der Exit-Code eines Ziels wird vom Supervisor für die Richtlinie verwendet,
aber nicht als Exit-Code des Supervisors zurückgegeben. Andere fatale Fehler
der Shell oder eines Systemwerkzeugs geben den Exit-Code des fehlgeschlagenen
Befehls zurück, meist `1`.

# BEISPIELE

Den Supervisor mit der Beispielkonfiguration aus dem Quelltext starten:

    ./allwatch.sh allwatch.conf

Die Programmversion und die Hilfe ausgeben und eine Konfiguration prüfen,
ohne sie zu starten:

    ./allwatch.sh --version
    ./allwatch.sh --help
    ./allwatch.sh --diagnose allwatch.conf

Konfiguration mit einem Ziel:

    POLL_SECONDS=5
    PROBE_TIMEOUT=3
    MAX_RESTARTS=5
    RESTART_WINDOW=60
    ON_FREEZE=restart
    demo 9001 on-failure ./dummy-target.sh 9001

Mit dem Debian-Paket absolute Pfade verwenden, weil der Dienst aus
`/var/lib/allwatch` läuft:

    demo 9001 on-failure /usr/share/doc/allwatch/examples/dummy-target.sh 9001

Nach der Installation des Pakets die Beispielkonfiguration kopieren und den
Dienst neu starten:

    sudo cp /usr/share/doc/allwatch/examples/allwatch.conf.example \
       /etc/allwatch/allwatch.conf
    sudo systemctl restart allwatch
    systemctl status allwatch
    journalctl -u allwatch -f

Die Testmaquette benötigt `nc` (Paket `netcat-openbsd`) und `setpriv`
(`util-linux`). Sie akzeptiert `SIGUSR1` (Lauschen beenden, am Leben bleiben),
`SIGUSR2` (mit Exit-Code 1 abstürzen) und `SIGTERM` (sauberes Ende mit Code
0). Um ein bewusstes Ende eines Ziels zu verlangen, seine Stopp-Datei als
Dienstbenutzer anlegen:

    sudo -u allwatch touch /run/allwatch/demo.stop

# GRENZEN

- Kein Neuladen der Konfiguration im laufenden Betrieb.
- Keine Auswertung von Anwendungsjournalen für Neustarts.
- Keine Prüfung über Fenstertitel, X11 oder Wayland.
- Keine Überwachung eines Ziels, das sich im Hintergrund ablöst.
- Der Befehl wird nicht über eine Shell ausgeführt: keine Anführungszeichen,
  Pipes, Umleitungen oder Variablenexpansion.
- Numerische Konfigurationswerte und Richtliniennamen werden nicht geprüft.
  Ein `POLL_SECONDS` von null lässt die Schleife ohne Ruhepause drehen; ein
  nicht numerischer `POLL_SECONDS` beendet den Supervisor mit Exit-Code `1`;
  ein nicht numerischer `PROBE_TIMEOUT` lässt jede Sonde fehlschlagen; eine
  falsch geschriebene Richtlinie wirkt wie `always`; ein nicht numerischer
  `MAX_RESTARTS` lässt jede Grenzprüfung fehlschlagen, sodass ein
  `always`- oder `on-failure`-Ziel weiter neu gestartet wird; ein nicht
  numerischer `RESTART_WINDOW` beendet den Supervisor mit Exit-Code `1`,
  sobald das Fenster als Nächstes berechnet wird. `ON_FREEZE` wird geprüft:
  Ein unbekannter Wert beendet den Supervisor mit Exit-Code `1`.
- Mit `ON_FREEZE=alert` bleibt ein Ziel, dessen Port geschlossen bleibt, am
  Leben und hängt; AllWatch schreibt `ALERTE GEL` einmal und erholt es nur,
  wenn der Port wieder antwortet oder der Prozess stirbt.
- Eine `id` mit `/` oder `..` kann aus dem Zustandsverzeichnis ausbrechen;
  AllWatch prüft sie nicht.
- Nach einem Neustart des Supervisors ist der Exit-Code eines übernommenen
  Ziels nicht verfügbar; sein Verschwinden gilt als Fehler. Die Übernahme
  vergleicht eine Teilzeichenkette von `/proc/<pid>/cmdline`, nicht die
  tatsächliche ausführbare Datei; eine wiederverwendete PID mit derselben
  Befehlszeile könnte übernommen werden.
- Ein Ziel, das nur auf einer anderen Adresse als `127.0.0.1` lauscht, gilt
  als hängend; die Sonde ist eine TCP-Verbindung zu `127.0.0.1`.
- Ein `SIGKILL` des Supervisors führt die Bereinigung nicht aus. Bei einem
  manuellen Lauf bleiben die Zustandsdateien erhalten, und der nächste
  Supervisor kann lebende Ziele übernehmen; beim Dienst entfernt systemd
  `/run/allwatch` beim Stopp, sodass der nächste Supervisor sie nicht
  übernimmt und Doppelstarts verursachen kann.
- Das einfache Textjournal wird nicht rotiert.
- Bei vier oder mehr Zielen, die jeweils die vollen 5 Sekunden Gnadenfrist
  nutzen, kann ein sauberes Stoppen das `TimeoutStopSec` von 20 Sekunden des
  Dienstes überschreiten; systemd beendet dann die ganze Prozessgruppe.
- `--help` gibt die Übersicht aus und endet mit Exit-Code `0`; die Optionen
  werden nur als erstes Argument erkannt.
- `--diagnose` prüft Konfiguration und Pfade; es startet und prüft kein Ziel,
  beweist also nicht, dass ein Ziel funktionsfähig ist.
- Die Konfiguration ist vertrauenswürdige Eingabe: Die Befehle der Ziele
  laufen mit den Rechten des Dienstbenutzers. `/etc/allwatch/allwatch.conf`
  gegen nicht-root-Schreibzugriff schützen. AllWatch isoliert die Ziele nicht
  in einer Sandbox.

# SIEHE AUCH

**bash**(1), **systemctl**(1), **journalctl**(1), **systemd.service**(5),
**systemd.exec**(5), **proc**(5), **timeout**(1)

# LIZENZ

MIT. Copyright (c) 2026 Ronan Davalan. Siehe
`/usr/share/doc/allwatch/LICENSE`.
