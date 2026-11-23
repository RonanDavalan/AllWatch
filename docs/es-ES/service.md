# Instalar y explotar el servicio Debian

El paquete Debian instala AllWatch como servicio systemd. El servicio arranca al inicio, lee su configuración una sola vez y espera si no se declara ningún objetivo. Este capítulo da las rutas, los archivos y los comandos exactos del paquete.

## Lo que instala el paquete

```text
/usr/bin/allwatch                          el supervisor
/usr/bin/allwatch.sh                       enlace de compatibilidad
/usr/lib/systemd/system/allwatch.service   la unidad systemd
/etc/allwatch/allwatch.conf                la configuración
/usr/share/man/man1/allwatch.1.gz          página de manual, inglés
/usr/share/man/fr/man1/allwatch.1.gz       página de manual, francés
/usr/share/man/de/man1/allwatch.1.gz       página de manual, alemán
/usr/share/man/es/man1/allwatch.1.gz       página de manual, español
/usr/share/man/zh_CN/man1/allwatch.1.gz    página de manual, chino simplificado
/usr/share/doc/allwatch/README.Debian      notas del paquete
/usr/share/doc/allwatch/examples/allwatch.conf.example
/usr/share/doc/allwatch/examples/dummy-target.sh
```

El paquete crea el usuario y el grupo de sistema `allwatch` (directorio personal `/var/lib/allwatch`, shell `/usr/sbin/nologin`). El servicio se ejecuta con esa identidad desde `/var/lib/allwatch`.

## Instalar

```bash
sudo apt install ./allwatch_0.1.0-4_all.deb
```

El paquete instala el programa y la unidad. Cuando systemd está en ejecución, activa `allwatch.service` y lo inicia. La configuración entregada no contiene ningún objetivo activo: el servicio arranca y espera.

Compruebe el estado del paquete y la versión del programa:

```bash
dpkg -s allwatch | grep -E '^(Status|Version):'
allwatch --version
```

`allwatch --version` muestra `allwatch 0.1.0`; la versión del paquete es `0.1.0-4`.

## Rutas y archivos

- `/etc/allwatch/allwatch.conf` es un archivo de configuración (conffile) propiedad de root, no escribible por el usuario del servicio. Es la frontera de confianza: los comandos de los objetivos se ejecutan con los privilegios del usuario del servicio.
- `/var/lib/allwatch` contiene el estado y el diario, modo `0700`, propietario `allwatch:allwatch`, creado por systemd. El diario plano es `/var/lib/allwatch/allwatch/allwatch.log`.
- `/run/allwatch` es el directorio de ejecución, modo `0700`, creado en cada arranque del servicio y retirado al detenerlo. Contiene `<id>.pid`, `<id>.fails` y `<id>.stop`.
- `/var/lib/allwatch` y `/run/allwatch` no sobreviven a una purga; `/run/allwatch` no sobrevive a una parada.

## Declarar un objetivo

Edite `/etc/allwatch/allwatch.conf` como root y añada una línea por objetivo:

```text
id port policy command...
```

Ejemplo real con el doble de prueba instalado por el paquete:

```bash
sudo apt install netcat-openbsd
sudo cp /usr/share/doc/allwatch/examples/allwatch.conf.example /etc/allwatch/allwatch.conf
sudo systemctl restart allwatch
```

El ejemplo declara:

```text
demo 9001 on-failure /usr/share/doc/allwatch/examples/dummy-target.sh 9001
```

Compruebe el puerto:

```bash
bash -c ': > /dev/tcp/127.0.0.1/9001' && echo "el puerto 9001 responde"
```

El usuario del servicio debe poder ejecutar el comando. Use rutas absolutas: el comando se divide por espacios, sin comillas, y no se ejecuta por un shell. Para argumentos con espacios o sintaxis de shell, escriba un script envoltorio y llámelo.

## Objetivo colgado: restart o alert

`ON_FREEZE` decide qué ocurre con un objetivo que sigue vivo pero cuyo puerto TCP ya no responde tras el plazo de gracia. `ON_FREEZE=restart` (el valor por defecto del paquete) envía `SIGTERM`, espera unos cinco segundos, envía `SIGKILL` si hace falta y reinicia el objetivo según su política. `ON_FREEZE=alert` no envía ninguna señal: registra `ALERTE GEL` una vez, deja el objetivo en ejecución y registra `RETABLI` cuando el puerto vuelve a responder. Una caída sigue la política del objetivo en ambos casos. Cualquier otro valor se rechaza al arrancar con código 1.

## Comandos del servicio

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

La configuración se lee una vez al arrancar; un cambio exige `sudo systemctl restart allwatch`. No hay recarga en caliente.

## Comprobar la configuración sin iniciar un objetivo

Ejecute `--diagnose` con el entorno del servicio y como usuario del servicio:

```bash
sudo -u allwatch env ALLWATCH_RUNTIME=/run/allwatch \
  XDG_STATE_HOME=/var/lib/allwatch \
  allwatch --diagnose /etc/allwatch/allwatch.conf
```

Muestra la versión, la ruta de configuración, la ruta de ejecución, la ruta del diario, la conducta ante un bloqueo y, para cada objetivo, su identificador, puerto y política. Devuelve `0` cuando la configuración es legible, un directorio de ejecución existente pertenece al usuario actual y un directorio de diario existente es escribible. Devuelve `1` por una configuración ilegible, un `ON_FREEZE` inválido, un `POLL_SECONDS` no numérico, un directorio de ejecución existente que no pertenece al usuario actual, o un directorio de diario existente que no es escribible. No inicia ningún objetivo ni sondea ningún puerto.

## Detener un objetivo sin detener el servicio

Cree el archivo de parada como usuario del servicio:

```bash
sudo -u allwatch touch /run/allwatch/demo.stop
```

AllWatch retira el archivo cuando el objetivo termina y no lo reinicia. El archivo no detiene por sí solo un objetivo en ejecución: envíe `SIGTERM` al objetivo o déjelo terminar.

## Ejecutar el servicio con otro usuario

El servicio se ejecuta como `allwatch`. Si los objetivos necesitan root u otra cuenta, cree un drop-in:

```bash
sudo systemctl edit allwatch
```

Añada:

```ini
[Service]
User=www-data
Group=www-data
```

Luego reinicie:

```bash
sudo systemctl restart allwatch
```

Los comandos de los objetivos heredan esa identidad. El archivo de configuración sigue siendo propiedad de root.

## Actualizar

```bash
sudo apt install ./allwatch_0.1.0-4_all.deb
```

`/etc/allwatch/allwatch.conf` se conserva; si la versión del paquete lo modifica, dpkg pregunta qué versión mantener. El servicio se reinicia tras la actualización si estaba activo. `/var/lib/allwatch` y su diario permanecen.

## Retirar y purgar

```bash
sudo apt remove allwatch
sudo apt purge allwatch
```

`apt remove` detiene el servicio, retira el programa, la unidad, las páginas de manual y la documentación del paquete. Conserva `/etc/allwatch/allwatch.conf`, `/var/lib/allwatch` y el usuario y grupo `allwatch`. No desactiva la unidad; el estado de activación de deb-systemd-helper permanece hasta la purga.

`apt purge` retira además el conffile, `/var/lib/allwatch`, `/etc/allwatch` cuando está vacío, el usuario y grupo `allwatch` cuando pueden retirarse, y el estado de activación. Si un proceso usa todavía la cuenta, `userdel` o `groupdel` pueden fallar; compruebe con:

```bash
getent passwd allwatch
getent group allwatch
```

## Límites conocidos del paquete

- La validación en contenedor instala el paquete, comprueba `--version`, `--help` y `--diagnose`, y lo retira. No arranca systemd: el servicio está instalado y documentado, pero no validado bajo systemd en el contenedor.
- `--diagnose` es estático: no sondea objetivos.
- `/run/allwatch` no sobrevive a una parada del servicio. Tras un fallo del supervisor, los objetivos pueden sobrevivir sin su archivo PID; el supervisor reiniciado puede lanzar duplicados. Un drop-in con `RuntimeDirectoryPreserve=restart` conserva el directorio entre reinicios del servicio.
