# Troubleshooting

AllWatch has no status command. The state of a target is read from the process, the TCP port and the flat log. This chapter gives the exact commands for the common failures.

## Read the service state first

```bash
sudo systemctl status allwatch
sudo journalctl -u allwatch -n 50 --no-pager
sudo tail -n 50 /var/lib/allwatch/allwatch/allwatch.log
```

The log lines are `date id event`. The events are `DEMARRAGE`, `DEMARRE`, `ADOPTE`, `PLANTE`, `ALERTE GEL`, `RETABLI`, `NEUTRALISE SIGTERM`, `NEUTRALISE SIGKILL`, `CRASHE code=N`, `RELANCE`, `ALERTE VERROU_CRITIQUE`, `QUITTE` and `ARRET`.

## The service does not start

- `allwatch: configuration illisible : /etc/allwatch/allwatch.conf` — the file is missing or not readable by the service user. Check `sudo -u allwatch test -r /etc/allwatch/allwatch.conf` and `sudo systemctl cat allwatch`.
- `allwatch: /run/allwatch n'appartient pas à l'utilisateur` — the runtime directory is owned by another user. Check `ls -ld /run/allwatch /var/lib/allwatch`; the unit creates them as `allwatch`. If you added a drop-in with another `User=`, fix the ownership or remove the drop-in.
- `status=203/EXEC` — the program is missing or not executable. Reinstall the package.
- `status=1/FAILURE` with a configuration error — run `--diagnose` as the service user (see below).

## The target is not restarted

- Policy `on-failure`: a target that exits with code `0` is left stopped. This is the contract, not a failure. Use `always` if it must restart after a clean exit.
- Policy `transient`: never restarted.
- Stop file present: `ls -l /run/allwatch/demo.stop`; remove it if the stop was not intended. The file itself does not stop a running target.
- `ALERTE VERROU_CRITIQUE`: the target reached `MAX_RESTARTS` in `RESTART_WINDOW`. Fix the cause, then restart the service; the lock lasts until the supervisor restarts.
- `CRASHE code=N`: the target exited with code N. Read its own log; AllWatch only reports the code.

## The target is reported hung but it is running

- The probe is `timeout 3 bash -c ': > /dev/tcp/127.0.0.1/9001'`. The target must listen on `127.0.0.1` (or `0.0.0.0`) on the declared port. A target that listens only on another address is considered hung.
- Wrong port in `/etc/allwatch/allwatch.conf`; check with `ss -ltnp | grep 9001`.
- The target is slower than `PROBE_TIMEOUT=3`; raise it in the configuration, then restart the service.
- The target is alive but its listener is closed; this is exactly the hang state. With `ON_FREEZE=restart` (the default), AllWatch sends `SIGTERM`, waits 5 seconds, then `SIGKILL`, and restarts it. With `ON_FREEZE=alert`, it logs `ALERTE GEL` once and leaves the target running; `RETABLI` is logged when the port answers again.

## `--diagnose` returns 0 but the target is unhealthy

`--diagnose` is static. It reads the configuration and the paths; it does not probe a target. A return code `0` only proves that the supervisor can read the configuration and use its directories.

## The test double does not answer

- `netcat-openbsd` is missing: `sudo apt install netcat-openbsd`.
- The command uses a relative path. The service runs from `/var/lib/allwatch`; use the absolute path `/usr/share/doc/allwatch/examples/dummy-target.sh`.
- The port is already used: `ss -ltnp | grep 9001`.
- The service user cannot execute the file: `sudo -u allwatch test -x /usr/share/doc/allwatch/examples/dummy-target.sh`.

## The log grows without limit

AllWatch does not rotate the log. Use logrotate or a systemd timer; the file is `/var/lib/allwatch/allwatch/allwatch.log`.

## Duplicate targets after a supervisor restart

`/run/allwatch` is removed when the service stops. A target may survive a supervisor crash without its PID file; the new supervisor starts a duplicate. Add a drop-in:

```bash
sudo systemctl edit allwatch
```

```ini
[Service]
RuntimeDirectoryPreserve=restart
```

Then restart. The runtime directory is kept across a service restart, so the new supervisor can adopt the surviving PID.

## Nothing in the log

The service runs as `allwatch` and writes to `/var/lib/allwatch/allwatch/allwatch.log`; check the service environment with `sudo systemctl show allwatch -p Environment`. If the directory is not writable, the log stays empty; `--diagnose` reports it.
