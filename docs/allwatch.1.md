% ALLWATCH(1) allwatch | User Commands
% Ronan Davalan
% 2026-11-20

# NAME

allwatch - tiny process supervisor for Linux

# SYNOPSIS

**allwatch** [*CONFIGURATION*]

**allwatch** **--version**

**allwatch** **--diagnose** [*CONFIGURATION*]

# DESCRIPTION

**allwatch** is a small process supervisor written in Bash. It starts each
configured target in the foreground, remembers the PID assigned by the
kernel, and judges the health of the target only from three sources: the
process exists in `/proc`, its TCP port accepts a connection, and the exit
code it returned when it ended.

The target is a black box. It does not register with AllWatch, does not
send it status messages, and does not need to know that AllWatch exists.
The supervisor is the parent; the target is the child.

# OPTIONS

**--version**
:   Print `allwatch 0.1.0` and exit `0`.

**--diagnose** [*CONFIGURATION*]
:   Read the configuration, print the version, the configuration path, the
    state directory, the log path and the configured targets, then exit. It
    does not start or probe a target and writes no state or log. It exits `0`
    when the configuration is readable and the existing state and log
    directories are usable, `1` otherwise.

# CONFIGURATION

The configuration is read once, at startup, line by line. Empty lines and
lines starting with `#` are ignored.

Engine parameters, one `KEY=value` per line:

**POLL_SECONDS**=*SECONDS*
:   Seconds between two checks (default `5`).

**PROBE_TIMEOUT**=*SECONDS*
:   Seconds a TCP port has to answer the probe (default `3`).

**MAX_RESTARTS**=*NUMBER*
:   Restarts allowed inside the window before the target is locked (default
    `5`).

**RESTART_WINDOW**=*SECONDS*
:   Length of the restart-counting window (default `60`).

Targets, one per line:

    id port policy command...

**id**
:   A short unique name, used for state files and log lines.

**port**
:   The TCP port the target listens on, probed on `127.0.0.1`.

**policy**
:   One of `always`, `on-failure` or `transient`.

**command...**
:   The rest of the line, split on spaces (no quoting), run in the
    foreground from the directory where **allwatch** was started.

Policies:

**always**
:   Restart the target whenever it ends, even with exit code 0, unless a
    file `id.stop` exists in the state directory.

**on-failure**
:   Restart after a crash or a hang; leave the target stopped after a clean
    exit code 0.

**transient**
:   Never restart the target.

A policy value other than these three is not rejected: the target is then
treated as `always`.

To request a deliberate stop, create `id.stop` in the state directory before
the target ends (`touch /run/allwatch/id.stop` for the Debian service).
AllWatch removes the file and does not restart the target. The file does not
stop a running target by itself.

# STATES

AllWatch reports four ordinary states, plus an exceptional locked state:

**Up**
:   The process exists and its port accepts a connection.

**Hung**
:   The process exists but its port does not answer. After a grace period,
    AllWatch sends `SIGTERM`, waits up to 5 seconds for the target to stop,
    sends `SIGKILL` if needed, and treats the target as failed.

**Crashed**
:   The process is gone without a deliberate stop. AllWatch reads the exit
    code and restarts the target if its policy says so. For a target adopted
    after a supervisor restart, the exit code is not available: its
    disappearance is treated as a failure.

**Quit**
:   The target ended and its policy says to leave it alone, or an operator
    stop flag was honored. The state file is removed.

**Locked (VERROU_CRITIQUE)**
:   The target reached `MAX_RESTARTS` restarts inside `RESTART_WINDOW`.
    AllWatch stops restarting it, logs an alert and removes the state file.
    The other targets continue.

# FILES

*/tmp/allwatch-runtime*
:   Default state directory: one `id.pid` and one `id.fails` file per target;
    an `id.stop` file is created by the operator to request a deliberate
    stop. AllWatch removes its own `.pid`, `.stop` and `.fails` files when it
    stops; other files are left. Override the directory with the
    `ALLWATCH_RUNTIME` environment variable.

*$XDG_STATE_HOME/allwatch/allwatch.log*, *$HOME/.local/state/allwatch/allwatch.log*
:   Flat event log, one line per event (`date id event`). The directory is
    created if needed. The log is not rotated by AllWatch.

*/etc/allwatch/allwatch.conf*
:   Configuration used by the Debian service, installed by the `allwatch`
    package.

*/run/allwatch*
:   State directory of the Debian service (`ALLWATCH_RUNTIME`), recreated at
    each boot and emptied at each stop.

*/var/lib/allwatch/allwatch/allwatch.log*
:   Event log of the Debian service (`XDG_STATE_HOME=/var/lib/allwatch`).

# SERVICE

The Debian package installs `allwatch.service`, which runs **allwatch** as
the system user `allwatch` with `/etc/allwatch/allwatch.conf`. systemd
restarts the supervisor after any exit (`Restart=always`, no start limit);
AllWatch in turn restarts its targets according to their policies. The
configuration is not reloaded at runtime: after editing it, run:

    systemctl restart allwatch

Useful commands:

    systemctl status allwatch
    systemctl start allwatch
    systemctl stop allwatch
    systemctl restart allwatch
    journalctl -u allwatch -f

# SIGNALS

**SIGTERM**, **SIGINT**
:   The supervisor stops each target with `SIGTERM`, waits for its exit,
    sends `SIGKILL` after 5 seconds if needed, removes its state files and
    exits (`130` for `SIGINT`, `143` for `SIGTERM`).

**SIGTERM** to a target
:   The target must stop within 5 seconds with exit code 0. A target that had
    to be neutralized after a hang is treated as failed and restarted
    according to its policy, even if it exits 0 after the signal.

# EXIT STATUS

**0**
:   Returned by `--version` and by a successful `--diagnose`. The supervision
    loop does not terminate on its own: it runs until `SIGINT` or `SIGTERM`
    and therefore does not return `0` in normal operation.

**1**
:   The configuration file is unreadable, the state directory is not owned
    by the current user, a `--diagnose` path check failed, or a fatal runtime
    error occurred (invalid parameter value, unwritable state or log
    directory).

**130**
:   Interrupted by `SIGINT`.

**143**
:   Terminated by `SIGTERM`.

# EXAMPLES

Run the supervisor with the example configuration from the source
repository:

    ./allwatch.sh allwatch.conf

Configuration with one target:

    POLL_SECONDS=5
    PROBE_TIMEOUT=3
    MAX_RESTARTS=5
    RESTART_WINDOW=60
    demo 9001 on-failure ./dummy-target.sh 9001

With the Debian package, use absolute paths for the command, because the
service runs from `/var/lib/allwatch`:

    demo 9001 on-failure /usr/share/doc/allwatch/examples/dummy-target.sh 9001

# LIMITS

- No hot reload of the configuration.
- No parsing of application logs to decide a restart.
- No checks based on window titles, X11 or Wayland.
- No supervision of a target that daemonizes or double-forks.
- Configuration values and policy names are not validated: a mistyped policy
  acts as `always`, and a non-numeric or zero timing value can break the loop.
- After a supervisor restart, an adopted target's exit code is unavailable;
  its disappearance is treated as a failure.
- The flat log is not rotated.
- With more than four targets, a clean stop can exceed the service's
  20-second `TimeoutStopSec`; systemd then kills the whole cgroup.
- `--help` is not implemented; the manual page is the reference.
- `--diagnose` checks the configuration and paths; it does not start or probe
  a target, so it does not prove that a target is healthy.

# SEE ALSO

**systemd.service**(5), **systemd.exec**(5), **proc**(5)

# LICENSE

MIT. Copyright (c) 2026 Ronan Davalan. See `/usr/share/doc/allwatch/LICENSE`.
