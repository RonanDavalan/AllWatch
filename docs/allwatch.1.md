% ALLWATCH(1) allwatch | User Commands
% Ronan Davalan
% 2026-11-22

# NAME

allwatch - tiny process supervisor for Linux

# SYNOPSIS

**allwatch** [*CONFIGURATION*]

**allwatch** **--version**

**allwatch** **--diagnose** [*CONFIGURATION*]

**allwatch** **--help**

# DESCRIPTION

**allwatch** is a small process supervisor written in Bash. It starts each
configured target as a child process, remembers the PID assigned by the
kernel, and judges the health of the target from three sources only: the
process exists in `/proc`, its TCP port accepts a connection, and the exit
code it returned when it ended. The target must stay in the foreground; a
target that daemonizes breaks the parent-child link.

The target is a black box. It does not register with AllWatch, does not send
it status messages, and does not need to know that AllWatch exists. The
supervisor is the parent; the target is the child.

The configuration is read once at startup. The default is `allwatch.conf` in
the current directory; the first argument replaces it.

**--version**
:   Print `allwatch 0.1.0` and exit `0`.

**--help**
:   Print the synopsis, the options, the environment variables and a pointer
    to this manual page, then exit `0`.

**--diagnose** [*CONFIGURATION*]
:   Read the configuration, print the version, the configuration path, the
    runtime directory, the log path, the freeze policy, the number of targets
    and the identifier, port and policy of each configured target, then exit.
    It also reports whether an existing runtime directory is a directory owned
    by the current user and whether an existing log directory is writable. It
    does not start or probe a target and writes no state or log.
    A configuration error is reported on standard error before any listing. It
    exits `0` when the configuration is readable, an existing state directory
    is owned by the current user and an existing log directory is writable. It
    exits `1` for an unreadable configuration, an invalid `ON_FREEZE`, a
    non-numeric `POLL_SECONDS`, an existing state directory that is not a
    directory owned by the current user, or an existing log directory that is
    not writable.

The options are recognized only as the first argument.

# CONFIGURATION

The configuration is read once, at startup, line by line. Empty lines and
lines starting with `#` are ignored.

Engine parameters, one `KEY=value` per line:

**POLL_SECONDS**=*SECONDS*
:   Seconds between two checks (default `5`). The hang grace period is
    `2 * POLL_SECONDS`.

**PROBE_TIMEOUT**=*SECONDS*
:   Seconds a TCP port has to answer the probe (default `3`).

**MAX_RESTARTS**=*NUMBER*
:   Restarts allowed inside the window before the target is locked (default
    `5`).

**RESTART_WINDOW**=*SECONDS*
:   Length of the restart-counting window (default `60`).

**ON_FREEZE**=*restart*|*alert*
:   What to do with a target that is still alive but whose port no longer
    answers after the grace period. `restart` (default) sends `SIGTERM`, waits
    about 5 seconds, sends `SIGKILL` if needed, and treats the target as
    failed; `alert` sends no signal, logs `ALERTE GEL` once and leaves the
    target under watch, then logs `RETABLI` when the port answers again. A
    crash follows the target policy under both values. Any other value is
    refused at startup with exit code `1`.

The numeric values and policy names are used as written and are not
validated; `ON_FREEZE` is the exception and only accepts `restart` or `alert`.

Targets, one per line:

    id port policy command...

**id**
:   A short unique name, used for the state file names and log lines. It must
    not contain `/` or `..`; AllWatch does not validate it.

**port**
:   The TCP port the target listens on. It is probed on `127.0.0.1`; a target
    that listens only on another address is considered hung.

**policy**
:   One of `always`, `on-failure` or `transient`.

**command...**
:   The rest of the line, split on whitespace (no quoting), started as a child
    process from the directory where **allwatch** was started. The command is
    not run through a shell: pipes, redirections and variable expansion are
    not interpreted; put such logic in an executable script. With the Debian
    service, use absolute paths.

Policies:

**always**
:   Restart the target whenever it ends, even with exit code 0, unless a
    file `id.stop` exists in the state directory.

**on-failure**
:   Restart after a crash, or after a hang that AllWatch has neutralized
    (`ON_FREEZE=restart`); leave the target stopped after a clean exit code 0.
    With `ON_FREEZE=alert`, a hung target is left running and is not restarted.

**transient**
:   Never restart the target.

A policy value other than these three is not rejected: the target is then
treated as `always`.

To request a deliberate stop, create `id.stop` in the state directory before
the target ends (`touch /run/allwatch/id.stop` for the Debian service).
AllWatch removes the file and does not restart the target. The file does not
stop a running target by itself.

# STATES

The supervisor distinguishes four ordinary states, plus an exceptional
locked state. It has no status command: a state is visible through the
process, the port and the flat log.

**Up**
:   The process exists and its port accepts a connection.

**Hung**
:   The process exists but its port does not answer. AllWatch marks the
    target suspect at the first failed probe and waits `2 * POLL_SECONDS`
    seconds. If the port is still closed, the behavior depends on
    `ON_FREEZE`: `restart` sends `SIGTERM`, waits about 5 seconds for the
    target to stop, sends `SIGKILL` if needed, and treats the target as
    failed; `alert` sends no signal, logs `ALERTE GEL` once, keeps the target
    under watch and logs `RETABLI` when the port answers again. If the process
    dies while hung, the target is treated as crashed.

**Crashed**
:   The process is gone without a deliberate stop. AllWatch reads the exit
    code and restarts the target if its policy says so. For a target adopted
    after a supervisor restart, the exit code is not available: its
    disappearance is treated as a failure.

**Quit**
:   The target ended and its policy says to leave it alone, or an operator
    stop flag was honored. The PID file is removed, and the stop file if one
    was used; the target is no longer monitored until the supervisor restarts.

**Locked (VERROU_CRITIQUE)**
:   The target reached `MAX_RESTARTS` restarts inside `RESTART_WINDOW`.
    AllWatch stops restarting it, logs an alert and removes the PID file. The
    other targets continue. The lock lasts until the supervisor is restarted;
    the target is not retried automatically.

# FILES

*/tmp/allwatch-runtime*
:   Default runtime directory for a manual run. It holds one `id.pid` and one
    `id.fails` file per target; an `id.stop` file is created by the operator
    to request a deliberate stop. The directory is created with mode `0700`
    if absent; an existing directory must be owned by the current user.
    AllWatch removes the `.pid`, `.stop` and `.fails` files from the directory
    when it stops; other files are left. Override the directory with the
    `ALLWATCH_RUNTIME` environment variable.

`$XDG_STATE_HOME/allwatch/allwatch.log`, `$HOME/.local/state/allwatch/allwatch.log`
:   Flat event log, one line per event (`date id event`). The directory is
    created if needed. The log is not rotated by AllWatch.

*allwatch.conf*
:   Default configuration file in the current directory when no argument is
    given.

*/etc/allwatch/allwatch.conf*
:   Configuration used by the Debian service, installed by the `allwatch`
    package as a conffile.

*/run/allwatch*
:   Runtime directory of the Debian service (`ALLWATCH_RUNTIME`), created at
    each service start and removed when the service stops.

*/var/lib/allwatch/allwatch/allwatch.log*
:   Event log of the Debian service (`XDG_STATE_HOME=/var/lib/allwatch`).
    systemd creates `/var/lib/allwatch`; the script creates its `allwatch`
    subdirectory.

*/usr/bin/allwatch*
:   Installed program (Debian package).

*/usr/lib/systemd/system/allwatch.service*
:   systemd unit installed by the Debian package.

# SERVICE

The Debian package installs `allwatch.service`, which runs **allwatch** as
the system user `allwatch` with `/etc/allwatch/allwatch.conf`. With the
shipped configuration, the service starts with no active target and waits.
systemd restarts the supervisor after any exit other than an explicit
`systemctl stop` (`Restart=always`, no start limit). AllWatch in turn restarts
its targets according to their policies. The configuration is not
reloaded at runtime: after editing it, run:

    systemctl restart allwatch

The target commands inherit the service user, group and working directory
(`/var/lib/allwatch`). To run the service and all its targets as another user,
create a drop-in with `systemctl edit allwatch` and set `User=` and `Group=`.

Useful commands:

    systemctl status allwatch
    systemctl start allwatch
    systemctl stop allwatch
    systemctl restart allwatch
    systemctl enable allwatch
    systemctl disable allwatch
    journalctl -u allwatch -f

The Fedora and openSUSE Leap `.rpm` packages and the Arch Linux package install the same service unit, configuration and program at the same paths. They do not start the service: run `systemctl enable --now allwatch` once the targets are declared.

# SIGNALS

**SIGTERM**, **SIGINT**
:   The supervisor stops each target that is still present with `SIGTERM`,
    waits about 5 seconds for it to exit, sends `SIGKILL` if needed, removes
    the `.pid`, `.stop` and `.fails` files, writes `allwatch ARRET` to the log
    and exits (`130` for `SIGINT`, `143` for `SIGTERM`).

**SIGTERM to a target**
:   The target handles the signal; AllWatch observes the resulting exit code
    when it started the target, and applies the target policy. For a target
    adopted after a supervisor restart, the exit code is unavailable and its
    disappearance is treated as a failure. The target contract asks for a
    stop within 5 seconds with exit code 0. When AllWatch itself neutralizes
    a hung target, the target is treated as failed even if it later exits 0.

**SIGHUP**
:   Not handled. It does not reload the configuration and normally terminates
    the supervisor; systemd then restarts it. Use `systemctl restart allwatch`
    to reload the configuration.

**SIGKILL**
:   Cannot be caught. AllWatch does not run its cleanup. In a manual run,
    targets survive and the runtime directory persists; the next supervisor
    can adopt live targets. With the Debian service, systemd controls the
    cgroup and removes `/run/allwatch` when the unit stops, so the next
    supervisor may have no PID files and may start duplicates. Do not rely on
    adoption after `SIGKILL`.

# EXIT STATUS

**0**
:   Returned by `--version`, `--help` and by a successful `--diagnose`. The
    supervision loop does not terminate on its own: it runs until `SIGINT` or
    `SIGTERM` and therefore does not return `0` in normal operation.

**1**
:   The configuration file is unreadable, `ON_FREEZE` is invalid, the runtime
    directory is not owned by the current user, a `--diagnose` path check
    failed, or a fatal runtime error occurred (for example a non-numeric
    `POLL_SECONDS`, or an unwritable state or log directory).

**130**
:   Interrupted by `SIGINT`.

**143**
:   Terminated by `SIGTERM`.

The target's exit code is used by the supervisor to apply the policy, but it
is not returned as the supervisor's exit status. Other fatal failures of the
shell or of a system utility return that command's non-zero status, usually
`1`.

# EXAMPLES

Run the supervisor with the example configuration from the source
repository:

    ./allwatch.sh allwatch.conf

Print the program version, the help summary and inspect a configuration
without starting it:

    ./allwatch.sh --version
    ./allwatch.sh --help
    ./allwatch.sh --diagnose allwatch.conf

Configuration with one target:

    POLL_SECONDS=5
    PROBE_TIMEOUT=3
    MAX_RESTARTS=5
    RESTART_WINDOW=60
    ON_FREEZE=restart
    demo 9001 on-failure ./dummy-target.sh 9001

With the Debian package, use absolute paths for the command, because the
service runs from `/var/lib/allwatch`:

    demo 9001 on-failure /usr/share/doc/allwatch/examples/dummy-target.sh 9001

After installing the package, copy the example configuration and restart the
service:

    sudo cp /usr/share/doc/allwatch/examples/allwatch.conf.example \
       /etc/allwatch/allwatch.conf
    sudo systemctl restart allwatch
    systemctl status allwatch
    journalctl -u allwatch -f

The test double needs `nc` (the `netcat-openbsd` package) and `setpriv`
(`util-linux`). It accepts `SIGUSR1` (stop listening, stay alive), `SIGUSR2`
(crash with exit code 1) and `SIGTERM` (clean exit 0). To request a
deliberate stop of a target, create its stop file as the service user:

    sudo -u allwatch touch /run/allwatch/demo.stop

# LIMITS

- No hot reload of the configuration.
- No parsing of application logs to decide a restart.
- No checks based on window titles, X11 or Wayland.
- No supervision of a target that daemonizes or double-forks.
- The command is not run through a shell: no quoting, pipes, redirections or
  variable expansion.
- Numeric configuration values and policy names are not validated. A zero
  `POLL_SECONDS` makes the loop spin without resting; a non-numeric
  `POLL_SECONDS` stops the supervisor with exit `1`; a non-numeric
  `PROBE_TIMEOUT` makes every probe fail; a mistyped policy acts as `always`;
  a non-numeric `MAX_RESTARTS` makes every limit check fail, so an `always` or
  `on-failure` target keeps restarting; a non-numeric `RESTART_WINDOW` stops
  the supervisor with exit `1` when it next has to compute the window. `ON_FREEZE` is validated:
  an unknown value stops the supervisor with exit `1`.
- With `ON_FREEZE=alert`, a target whose port stays closed is left alive and
  hung; AllWatch logs `ALERTE GEL` once and recovers it only if the port
  answers again or the process dies.
- An `id` containing `/` or `..` can escape the runtime directory; AllWatch
  does not validate it.
- After a supervisor restart, an adopted target's exit code is unavailable;
  its disappearance is treated as a failure. Adoption matches a substring of
  `/proc/<pid>/cmdline`, not the real executable; a recycled PID with the same
  command line could be adopted.
- A target that listens only on an address other than `127.0.0.1` is
  considered hung; the probe is a TCP connection to `127.0.0.1`.
- A `SIGKILL` of the supervisor does not run the cleanup. In a manual run the
  runtime files remain and the next supervisor can adopt live targets; with
  the service, systemd removes `/run/allwatch` at stop, so the next
  supervisor does not adopt them and may start duplicates.
- The flat log is not rotated.
- With four or more targets that each use the full 5-second grace period, a
  clean stop can exceed the service's 20-second `TimeoutStopSec`; systemd then
  kills the whole cgroup.
- `--help` prints the summary and exits `0`; the options are recognized only
  as the first argument.
- `--diagnose` checks the configuration and paths; it does not start or probe
  a target, so it does not prove that a target is healthy.
- The configuration is trusted input: target commands run with the privileges
  of the service user. Protect `/etc/allwatch/allwatch.conf` from non-root
  writers. AllWatch does not sandbox the targets.

# SEE ALSO

**bash**(1), **systemctl**(1), **journalctl**(1), **systemd.service**(5),
**systemd.exec**(5), **proc**(5), **timeout**(1)

# LICENSE

MIT. Copyright (c) 2026 Ronan Davalan. See `/usr/share/doc/allwatch/LICENSE`.
