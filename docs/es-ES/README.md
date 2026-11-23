# AllWatch

[![Versión](https://img.shields.io/badge/versi%C3%B3n-0.1.0-115E67)](https://allwatch.davalan.fr/es/descarga/)
[![Licencia](https://img.shields.io/badge/licencia-MIT-115E67)](LICENSE)
[![Plataforma](https://img.shields.io/badge/plataforma-Debian%20%7C%20Ubuntu-DCA134)](https://allwatch.davalan.fr/es/descarga/)

[English](README.md) | [Français](docs/fr-FR/README.md) | [Deutsch](docs/de-DE/README.md) | [Español](docs/es-ES/README.md)

![Ayuda de AllWatch](docs/images/allwatch-help.png)

AllWatch es un supervisor de procesos minúsculo para Linux, escrito en un
solo script Bash (unas ciento cincuenta líneas útiles de código). Inicia cada objetivo en primer
plano, recuerda su PID y juzga su salud solo con lo que dicen el núcleo y la
red: ¿el proceso sigue en `/proc`, su puerto TCP sigue aceptando una conexión
y qué código de salida dejó? Reinicia el objetivo según una política por
objetivo y se niega a entrar en un bucle infinito con un objetivo que muere de
inmediato.

El objetivo es una caja negra. No se registra ante AllWatch, no le envía nada
y no necesita saber que existe.

## Instalación en Debian y Ubuntu

El paquete Debian instala el supervisor como `/usr/bin/allwatch`, la unidad
systemd `allwatch.service`, la configuración de ejemplo y la página de manual
en cuatro idiomas. Descargue el paquete y `SHA256SUMS` desde la [página de
descarga](https://allwatch.davalan.fr/es/descarga/) y ejecute:

```bash
sudo apt install ./allwatch_0.1.0-4_all.deb
```

Nivel anunciado: **instalación y diagnóstico validados en contenedor**, en
Debian 12 y 13 y en Ubuntu 22.04 y 24.04. El paquete no se presenta como
probado en un servidor físico. El servicio se instala activado, con una
configuración que no declara ningún objetivo; añada los suyos en
`/etc/allwatch/allwatch.conf` y ejecute `sudo systemctl restart allwatch`.

Compruebe la versión instalada y la configuración sin iniciar un objetivo:

```bash
allwatch --version
allwatch --help
allwatch --diagnose /etc/allwatch/allwatch.conf
```

`--diagnose` lee la configuración, el directorio de estado y la ruta del
diario. No inicia ni sondea ningún objetivo: no demuestra que un objetivo esté
sano, demuestra que el supervisor puede leer su configuración y usar sus
rutas.

Para retirar el paquete:

```bash
sudo apt remove allwatch
sudo apt purge allwatch
```

`apt remove` detiene el servicio pero lo deja activado; `apt purge` elimina
además la configuración y el estado del servicio.

## Ejecución desde el repositorio

Requisitos: Linux (el supervisor lee `/proc`), Bash 5 o posterior, y
`timeout` y `awk` de las utilidades básicas habituales. Solo para el doble de
prueba `dummy-target.sh`: `setpriv` (util-linux) y OpenBSD `nc`.

```bash
git clone https://github.com/RonanDavalan/AllWatch.git
cd AllWatch
./allwatch.sh --version
./allwatch.sh --help
./allwatch.sh allwatch.conf
```

La configuración de ejemplo inicia `dummy-target.sh` en el puerto 9001 con el
identificador `demo`. En una segunda terminal:

```bash
cat /tmp/allwatch-runtime/demo.pid
: > /dev/tcp/127.0.0.1/9001 && echo "el puerto 9001 responde"
```

Mate el objetivo a la fuerza y véalo volver con un PID nuevo (el intervalo de
consulta es de 5 segundos):

```bash
kill -9 "$(cat /tmp/allwatch-runtime/demo.pid)"
sleep 6
cat /tmp/allwatch-runtime/demo.pid
```

Provoque un bloqueo (el objetivo sigue vivo pero cierra su puerto). AllWatch
lo detecta, lo detiene y lo reinicia, lo que tarda unos quince segundos:

```bash
kill -USR1 "$(cat /tmp/allwatch-runtime/demo.pid)"
sleep 20
grep ' demo ' ~/.local/state/allwatch/allwatch.log | tail -n 6
```

Detenga el supervisor con `Ctrl+C` (o `SIGTERM`); detiene sus objetivos y
vacía su directorio de estado:

```bash
ls -A /tmp/allwatch-runtime
```

## Cómo funciona

AllWatch es el padre, el objetivo es el hijo. Cada pocos segundos examina cada
objetivo y lo sitúa en uno de cuatro estados:

- **En marcha**: el proceso existe y su puerto acepta una conexión.
- **Bloqueado**: el proceso existe pero su puerto no responde. Con
  `ON_FREEZE=restart` (el valor por defecto), AllWatch envía `SIGTERM`, espera
  5 segundos, envía `SIGKILL` si hace falta y considera el objetivo fallido.
  Con `ON_FREEZE=alert`, no envía ninguna señal, registra `ALERTE GEL` una vez,
  deja el objetivo vigilado y registra `RETABLI` cuando el puerto vuelve a
  responder.
- **Caído**: el proceso desapareció sin un cierre deliberado. AllWatch lee el
  código de salida y reinicia el objetivo si su política lo permite.
- **Terminado**: el objetivo terminó y su política no pide reinicio, o se
  alcanzó el límite de reinicios.

## Configuración

La configuración se lee una vez, al arrancar, línea por línea. Las líneas
vacías y las que empiezan por `#` se ignoran. Parámetros del motor, un
`KEY=value` por línea:

- `POLL_SECONDS=5`: segundos entre dos comprobaciones.
- `PROBE_TIMEOUT=3`: segundos que tiene un puerto para responder a la sonda.
- `MAX_RESTARTS=5`: reinicios permitidos en la ventana siguiente.
- `RESTART_WINDOW=60`: duración de esa ventana, en segundos.
- `ON_FREEZE=restart`: un objetivo bloqueado se neutraliza y se reinicia; `alert` lo deja intacto y registra `ALERTE GEL`. Cualquier otro valor se rechaza al arrancar con código 1.

Objetivos, uno por línea:

```text
id port policy command...
```

- `id`: un nombre corto para los archivos de estado y el diario.
- `port`: el puerto TCP del objetivo (sondeado en `127.0.0.1`).
- `policy`: `always`, `on-failure` o `transient`.
- `command...`: el resto de la línea, separado por espacios (sin comillas),
  ejecutado en primer plano desde el directorio de arranque.

Políticas:

- `always`: reiniciar el objetivo cada vez que termine, incluso con código de
  salida 0, salvo que exista un archivo `<id>.stop` en el directorio de
  estado.
- `on-failure`: reiniciar tras una caída o un bloqueo, pero dejarlo detenido
  tras un código de salida 0.
- `transient`: no reiniciarlo nunca.

Si un objetivo necesita más de `MAX_RESTARTS` reinicios dentro de
`RESTART_WINDOW` segundos, AllWatch deja de reiniciarlo, registra
`ALERTE VERROU_CRITIQUE` y sigue con los demás objetivos.

El directorio de estado es `/tmp/allwatch-runtime` (se puede cambiar con
`ALLWATCH_RUNTIME`); el diario es un archivo plano, una línea por evento
(`date id event`), en
`${XDG_STATE_HOME:-$HOME/.local/state}/allwatch/allwatch.log`.

## El contrato de un objetivo

AllWatch no se adapta a nada; el objetivo que rompe el contrato es el
culpable.

- **Primer plano.** El objetivo se ejecuta en primer plano del proceso que
  inicia AllWatch. No debe demonizarse ni hacer doble fork.
- **Códigos de salida.** Una parada limpia y solicitada termina con código
  `0`. Cualquier fallo termina con un código distinto de cero.
- **Un puerto TCP.** Cada objetivo posee un puerto TCP, abierto y aceptando
  conexiones desde su inicialización. Un objetivo vivo que no acepta una
  conexión dentro del plazo de la sonda se considera bloqueado.
- **`SIGTERM`.** El objetivo captura `SIGTERM`, libera sus recursos y termina
  con código `0` en menos de 5 segundos. Después, AllWatch envía `SIGKILL`.

El título de la ventana, el servidor gráfico y la salida propia del objetivo
no intervienen en la comprobación de salud.

## Límites

- Sin recarga en caliente de la configuración: `sudo systemctl restart
  allwatch`.
- Sin comprobación por títulos de ventana, X11 o Wayland.
- Sin análisis de diarios de aplicación para decidir un reinicio.
- Sin supervisión de objetivos que se separan del primer plano.
- `--diagnose` es estático: lee la configuración y las rutas, no sondea ningún
  objetivo y no demuestra que un objetivo esté sano.
- `--version`, `--help` y `--diagnose` solo se reconocen como primer
  argumento.
- El comando no se ejecuta por un shell: sin comillas, tuberías, redirecciones
  ni expansión de variables.
- Los valores de configuración y los nombres de política no se validan.
- El diario plano no se rota.

## Licencia

MIT. Véase `LICENSE`.

## Créditos

- **Ronan Davalan**: arquitecto y árbitro. Definió la visión y el alcance,
  arbitró las especificaciones y las validó.
- **Claude Sonnet 5.5** (Anthropic): único autor del código (el supervisor y
  el doble de prueba), escrito en tres sesiones el 13 de noviembre de 2026.
- **Gemini** (Google): síntesis estratégica y coescritura de las
  especificaciones.

Véase `CONTRIBUTORS.md`.
