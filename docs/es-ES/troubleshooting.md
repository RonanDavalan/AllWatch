# Solución de problemas

AllWatch no tiene comando de estado. El estado de un objetivo se lee en el proceso, el puerto TCP y el registro plano. Este capítulo da los comandos exactos de los fallos habituales.

## Leer primero el estado del servicio

```bash
sudo systemctl status allwatch
sudo journalctl -u allwatch -n 50 --no-pager
sudo tail -n 50 /var/lib/allwatch/allwatch/allwatch.log
```

Las líneas del registro son `fecha id evento`. Los eventos son `DEMARRAGE`, `DEMARRE`, `ADOPTE`, `PLANTE`, `ALERTE GEL`, `RETABLI`, `NEUTRALISE SIGTERM`, `NEUTRALISE SIGKILL`, `CRASHE code=N`, `RELANCE`, `ALERTE VERROU_CRITIQUE`, `QUITTE` y `ARRET`.

## El servicio no arranca

El programa escribe estos mensajes en el idioma del sistema (`LC_ALL`, `LC_MESSAGES` o `LANG`); el inglés es el idioma por defecto.

- `allwatch: configuración ilegible: /etc/allwatch/allwatch.conf` — falta el archivo o el usuario del servicio no puede leerlo. Compruebe `sudo -u allwatch test -r /etc/allwatch/allwatch.conf` y `sudo systemctl cat allwatch`.
- `allwatch: /run/allwatch no pertenece al usuario actual` — el directorio de ejecución pertenece a otro usuario. Compruebe `ls -ld /run/allwatch /var/lib/allwatch`; la unidad los crea para `allwatch`. Si añadió un drop-in con otro `User=`, corrija la propiedad o retire el drop-in.
- `status=203/EXEC` — falta el programa o no es ejecutable. Reinstale el paquete.
- `status=1/FAILURE` con un error de configuración — ejecute `--diagnose` como usuario del servicio (véase abajo).

## El objetivo no se reinicia

- Política `on-failure`: un objetivo que termina con código `0` queda detenido. Es el contrato, no un fallo. Use `always` si debe reiniciarse tras una parada limpia.
- Política `transient`: nunca se reinicia.
- Archivo de parada presente: `ls -l /run/allwatch/demo.stop`; retírelo si la parada no era intencionada. El archivo no detiene por sí solo un objetivo en ejecución.
- `ALERTE VERROU_CRITIQUE`: el objetivo alcanzó `MAX_RESTARTS` en `RESTART_WINDOW`. Corrija la causa y reinicie el servicio; el bloqueo dura hasta el reinicio del supervisor.
- `CRASHE code=N`: el objetivo terminó con el código N. Lea su propio registro; AllWatch solo informa del código.

## El objetivo se declara bloqueado aunque esté en marcha

- La sonda es `timeout 3 bash -c ': > /dev/tcp/127.0.0.1/9001'`. El objetivo debe escuchar en `127.0.0.1` (o `0.0.0.0`) en el puerto declarado. Un objetivo que solo escucha en otra dirección se considera bloqueado.
- Puerto equivocado en `/etc/allwatch/allwatch.conf`; compruebe con `ss -ltnp | grep 9001`.
- El objetivo es más lento que `PROBE_TIMEOUT=3`; aumente el valor en la configuración y reinicie el servicio.
- El objetivo está vivo pero su escucha está cerrada; es exactamente el estado bloqueado. Con `ON_FREEZE=restart` (por defecto), AllWatch envía `SIGTERM`, espera 5 segundos, envía `SIGKILL` y lo reinicia. Con `ON_FREEZE=alert`, registra `ALERTE GEL` una vez y deja el objetivo en ejecución; `RETABLI` se registra cuando el puerto vuelve a responder.

## `--diagnose` devuelve 0 pero el objetivo no está sano

`--diagnose` es estático. Lee la configuración y las rutas; no sondea ningún objetivo. Un código de retorno `0` solo prueba que el supervisor puede leer la configuración y usar sus directorios.

## El doble de prueba no responde

- Falta `netcat-openbsd`: `sudo apt install netcat-openbsd`.
- El comando usa una ruta relativa. El servicio se ejecuta desde `/var/lib/allwatch`; use la ruta absoluta `/usr/share/doc/allwatch/examples/dummy-target.sh`.
- El puerto ya está ocupado: `ss -ltnp | grep 9001`.
- El usuario del servicio no puede ejecutar el archivo: `sudo -u allwatch test -x /usr/share/doc/allwatch/examples/dummy-target.sh`.

## El registro crece sin límite

AllWatch no rota el registro. Use logrotate o un temporizador systemd; el archivo es `/var/lib/allwatch/allwatch/allwatch.log`.

## Objetivos duplicados tras un reinicio del supervisor

`/run/allwatch` se retira al detener el servicio. Un objetivo puede sobrevivir a un fallo del supervisor sin su archivo PID; el nuevo supervisor lanza un duplicado. Añada un drop-in:

```bash
sudo systemctl edit allwatch
```

```ini
[Service]
RuntimeDirectoryPreserve=restart
```

Luego reinicie. El directorio de ejecución se conserva entre reinicios del servicio y el nuevo supervisor puede adoptar el PID superviviente.

## Nada en el registro

El servicio se ejecuta como `allwatch` y escribe en `/var/lib/allwatch/allwatch/allwatch.log`; compruebe el entorno del servicio con `sudo systemctl show allwatch -p Environment`. Si el directorio no es escribible, el registro queda vacío; `--diagnose` lo indica.
