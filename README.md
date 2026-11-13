# AllWatch

AllWatch is a tiny process supervisor for Linux, written in a single Bash script (about one hundred lines of code). It starts each target in the foreground, remembers its PID, and judges its health only from what the kernel and the network say: is the process still in `/proc`, does its TCP port still accept a connection, and what exit code did it leave. It restarts the target according to a per-target policy and refuses to loop forever on a target that dies at once.

The target is a black box. It does not register with AllWatch, does not send it anything and does not need to know it exists.

## How it works

AllWatch is the parent, the target is the child. Every few seconds it looks at each target and puts it in one of four states:

- **Up**: the process exists and its port accepts a connection.
- **Hung**: the process exists but its port does not answer. AllWatch sends `SIGTERM`, waits for the target to stop (5 seconds), sends `SIGKILL` if needed, then treats the target as failed.
- **Crashed**: the process is gone without a deliberate stop. AllWatch reads the exit code and restarts the target if its policy says so.
- **Quit**: the target ended and its policy says to leave it alone, or the restart limit was reached.

## Requirements

- Linux (the supervisor reads `/proc`), Bash 5 or later, and `timeout` and `awk` from the usual core utilities.
- For the test double `dummy-target.sh` only: `setpriv` (util-linux) and OpenBSD `nc`.

## Repository layout

- `allwatch.sh`: the supervisor.
- `allwatch.conf`: an example configuration, one target on port 9001.
- `dummy-target.sh`: a test double that listens on a TCP port and can be made to stop cleanly, hang or crash on demand.
- `LICENSE`: MIT.

## Quick start

From the repository directory, in a first terminal, start the supervisor with the example configuration:

```bash
./allwatch.sh allwatch.conf
```

It launches `dummy-target.sh` on port 9001 under the id `demo`. In a second terminal, from any directory, look at the target:

```bash
cat /tmp/allwatch-runtime/demo.pid
: > /dev/tcp/127.0.0.1/9001 && echo "port 9001 answers"
```

Kill the target the hard way and see it come back with a new PID (the poll interval is 5 seconds):

```bash
kill -9 "$(cat /tmp/allwatch-runtime/demo.pid)"
sleep 6
cat /tmp/allwatch-runtime/demo.pid
```

Make the target hang (it stays alive but closes its port). AllWatch notices, stops it and restarts it, which takes about fifteen seconds:

```bash
kill -USR1 "$(cat /tmp/allwatch-runtime/demo.pid)"
sleep 20
cat /tmp/allwatch-runtime/demo.pid
grep ' demo ' ~/.local/state/allwatch/allwatch.log | tail -n 6
```

The log shows `DEMARRE` for the first launch, `CRASHE code=137` then `RELANCE` for the kill, then `PLANTE`, `NEUTRALISE SIGTERM` and `RELANCE` for the hang. Finally stop the supervisor with `Ctrl+C` in the first terminal (or send it `SIGTERM`); it stops its targets and empties its state directory:

```bash
ls -A /tmp/allwatch-runtime
```

The command prints nothing.

## Configuration: `allwatch.conf`

The file is read once, at startup, line by line. Empty lines and lines starting with `#` are ignored.

Engine parameters, one `KEY=value` per line:

- `POLL_SECONDS=5`: seconds between two checks.
- `PROBE_TIMEOUT=3`: seconds a port has to answer the probe.
- `MAX_RESTARTS=5`: restarts allowed inside the window below.
- `RESTART_WINDOW=60`: length of that window, in seconds.

Targets, one per line:

```
id port policy command...
```

- `id`: a short name, used for the state files and the log.
- `port`: the TCP port the target listens on (probed on `127.0.0.1`).
- `policy`: one of `always`, `on-failure`, `transient`.
- `command...`: the rest of the line, split on spaces (no quoting), run in the foreground from the directory where `allwatch.sh` was started.

Policies:

- `always`: restart the target whenever it ends, even with exit code 0, unless a file `<id>.stop` exists in the state directory.
- `on-failure`: restart it after a crash or a hang, but leave it stopped after an exit code 0.
- `transient`: never restart it.

If a target needs more than `MAX_RESTARTS` restarts within `RESTART_WINDOW` seconds, AllWatch stops restarting it, logs `ALERTE VERROU_CRITIQUE` and carries on with the other targets.

Usage: `./allwatch.sh [file.conf]` (default `allwatch.conf`). The state directory is `/tmp/allwatch-runtime` (override with `ALLWATCH_RUNTIME`); the log is a flat file, one line per event (`date id event`), in `${XDG_STATE_HOME:-$HOME/.local/state}/allwatch/allwatch.log`.

## The contract a target must respect

AllWatch adapts to nothing; a target that breaks the contract is the one at fault.

- **Foreground.** The target runs in the foreground of the process AllWatch starts. It must not daemonize or double-fork: AllWatch would see the first process end and start a duplicate.
- **Exit codes.** A clean, requested stop exits with code `0`. Any failure exits with a non-zero code.
- **A TCP port.** Each target owns one TCP port, open and accepting connections as soon as it is initialised. A target that is alive but does not accept a connection within the probe timeout is considered hung.
- **`SIGTERM`.** The target catches `SIGTERM`, releases its resources and exits with code `0` within 5 seconds. After that, AllWatch sends `SIGKILL`.

The window title, the display server and the target's own output play no part in the health check.

## Non-goals

- No registration or status push from the target: AllWatch listens to nothing the target says.
- No window, X11 or Wayland based checks.
- No parsing of logs to decide on a restart.
- No supervision of targets that detach themselves from the foreground.
- No hot reload of the configuration, no log levels, no network interface, no inter-process protocol.
- No guarantee about the internal consistency of a target's data: AllWatch guarantees that the process exists and answers, nothing more.

## License

MIT. See `LICENSE`.

## Credits

- **Ronan Davalan**: architect and arbiter. He set the vision and the scope, arbitrated the specifications and validated them.
- **Claude Sonnet 5.5** (Anthropic): sole author of the code (the supervisor and the test double), written in three coding sessions on 13 November 2026.
- **Gemini** (Google): strategic synthesis and co-writing of the specifications: detection of anti-patterns, formalisation of the four-state machine.
- **gd2**: Ronan Davalan's late brother, who taught him Git and its use as the backbone of a rigorous method. A permanent mentor of the documentation discipline, credited by Ronan's lasting decision on all his projects.

See `CONTRIBUTORS.md`.
