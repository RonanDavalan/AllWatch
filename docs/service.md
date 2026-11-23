# Install and run the Debian service

The Debian package installs AllWatch as a systemd service. The service starts at boot, reads its configuration once, and waits if no target is declared. This chapter gives the exact paths, files and commands of the package.

## What the package installs

```text
/usr/bin/allwatch                          the supervisor
/usr/bin/allwatch.sh                       compatibility symlink
/usr/lib/systemd/system/allwatch.service   the systemd unit
/etc/allwatch/allwatch.conf                the configuration
/usr/share/man/man1/allwatch.1.gz          manual page, English
/usr/share/man/fr/man1/allwatch.1.gz       manual page, French
/usr/share/man/de/man1/allwatch.1.gz       manual page, German
/usr/share/man/es/man1/allwatch.1.gz       manual page, Spanish
/usr/share/man/zh_CN/man1/allwatch.1.gz    manual page, Simplified Chinese
/usr/share/doc/allwatch/README.Debian      package notes
/usr/share/doc/allwatch/examples/allwatch.conf.example
/usr/share/doc/allwatch/examples/dummy-target.sh
```

The package creates the system user and group `allwatch` (home `/var/lib/allwatch`, shell `/usr/sbin/nologin`). The service runs as that user from `/var/lib/allwatch`.

## Install

```bash
sudo apt install ./allwatch_0.1.0-4_all.deb
```

The package installs the program and the unit. When systemd is running, it
enables and starts `allwatch.service`. The shipped configuration has no active
target, so the service starts and waits.

Check the package state and the program version:

```bash
dpkg -s allwatch | grep -E '^(Status|Version):'
allwatch --version
```

`allwatch --version` prints `allwatch 0.1.0`; the package version is `0.1.0-4`.

## Paths and files

- `/etc/allwatch/allwatch.conf` is a conffile owned by root and not writable by the service user. It is the trust boundary: target commands run with the service user's privileges.
- `/var/lib/allwatch` holds the state and the log, mode `0700`, owner `allwatch:allwatch`, created by systemd. The flat log is `/var/lib/allwatch/allwatch/allwatch.log`.
- `/run/allwatch` is the runtime directory, mode `0700`, created at each service start and removed when the service stops. It holds `<id>.pid`, `<id>.fails` and `<id>.stop`.
- `/var/lib/allwatch` and `/run/allwatch` do not survive a purge; `/run/allwatch` does not survive a stop.

## Declare a target

Edit `/etc/allwatch/allwatch.conf` as root and add one line per target:

```text
id port policy command...
```

A real example with the test double installed by the package:

```bash
sudo apt install netcat-openbsd
sudo cp /usr/share/doc/allwatch/examples/allwatch.conf.example /etc/allwatch/allwatch.conf
sudo systemctl restart allwatch
```

The example declares:

```text
demo 9001 on-failure /usr/share/doc/allwatch/examples/dummy-target.sh 9001
```

Check the port:

```bash
bash -c ': > /dev/tcp/127.0.0.1/9001' && echo "port 9001 answers"
```

The service user must be able to execute the command. Use absolute paths: the command is split on spaces without quoting and is not run through a shell. For arguments with spaces or shell syntax, write a wrapper script and call it.

## Frozen target: restart or alert

`ON_FREEZE` decides what happens when a target is still alive but its TCP port no longer answers after the grace period. `ON_FREEZE=restart` (the shipped default) sends `SIGTERM`, waits about five seconds, sends `SIGKILL` if needed, and restarts the target according to its policy. `ON_FREEZE=alert` sends no signal: it logs `ALERTE GEL` once, leaves the target running and logs `RETABLI` when the port answers again. A crash follows the target policy under both values. Any other value is refused at startup with exit code 1.

## Service commands

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

The configuration is read once at startup; a change requires `sudo systemctl restart allwatch`. There is no hot reload.

## Check the configuration without starting a target

Run `--diagnose` with the service environment and as the service user:

```bash
sudo -u allwatch env ALLWATCH_RUNTIME=/run/allwatch \
  XDG_STATE_HOME=/var/lib/allwatch \
  allwatch --diagnose /etc/allwatch/allwatch.conf
```

It prints the version, the configuration path, the runtime path, the log path, the freeze policy and each target's id, port and policy. It exits `0` when the configuration is readable, an existing runtime directory is owned by the current user and an existing log directory is writable. It exits `1` for an unreadable configuration, an invalid `ON_FREEZE`, a non-numeric `POLL_SECONDS`, an existing runtime directory not owned by the current user, or an existing log directory that is not writable. It starts no target and probes no port.

## Stop a target without stopping the service

Create the stop file as the service user:

```bash
sudo -u allwatch touch /run/allwatch/demo.stop
```

AllWatch removes the file when the target ends and does not restart it. The file does not stop a running target by itself; send `SIGTERM` to the target or let it end.

## Run as another user

The service runs as `allwatch`. If the targets need root or another account,
create a drop-in:

```bash
sudo systemctl edit allwatch
```

Add:

```ini
[Service]
User=www-data
Group=www-data
```

Then restart:

```bash
sudo systemctl restart allwatch
```

The target commands inherit that identity. The configuration file remains root-owned.

## Upgrade

```bash
sudo apt install ./allwatch_0.1.0-4_all.deb
```

`/etc/allwatch/allwatch.conf` is preserved; if the packaged version changes, dpkg asks which version to keep. The service is restarted after the upgrade if it was active. `/var/lib/allwatch` and its log remain.

## Remove and purge

```bash
sudo apt remove allwatch
sudo apt purge allwatch
```

`apt remove` stops the service, removes the program, the unit, the manual pages and the package documentation. It keeps `/etc/allwatch/allwatch.conf`, `/var/lib/allwatch` and the `allwatch` user and group. It does not disable the unit; the deb-systemd-helper enablement state remains until purge.

`apt purge` also removes the conffile, `/var/lib/allwatch`, `/etc/allwatch` when empty, the `allwatch` user and group when they can be removed, and the enablement state. If a process still uses the account, `userdel` or `groupdel` may fail; check with:

```bash
getent passwd allwatch
getent group allwatch
```

## Known limits of the package

- The container validation installs the package, checks `--version`, `--help` and `--diagnose`, then removes it. It does not start systemd, so the service is installed and documented but not validated under systemd in the container.
- `--diagnose` is static: it does not probe targets.
- `/run/allwatch` does not survive a service stop. After a supervisor crash, targets may survive without PID files; the restarted supervisor can start duplicates. A drop-in with `RuntimeDirectoryPreserve=restart` keeps the directory across a service restart.
