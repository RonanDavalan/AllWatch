% ALLWATCH(1) allwatch | Comandos de usuario
% Ronan Davalan
% 2026-11-20

# NOMBRE

allwatch - pequeño supervisor de procesos para Linux

# SINOPSIS

**allwatch** [*CONFIGURACIÓN*]

# DESCRIPCIÓN

**allwatch** es un pequeño supervisor de procesos escrito en Bash. Inicia
cada objetivo configurado en primer plano, recuerda el PID asignado por el
núcleo y juzga la salud del objetivo a partir de tres fuentes únicamente: el
proceso existe en `/proc`, su puerto TCP acepta una conexión y el código de
salida que devolvió al terminar.

El objetivo es una caja negra. No se registra ante AllWatch, no le envía
mensajes de estado y no necesita saber que AllWatch existe. El supervisor es
el padre; el objetivo es el hijo.

# CONFIGURACIÓN

La configuración se lee una vez, al arrancar, línea por línea. Las líneas
vacías y las que empiezan por `#` se ignoran.

Parámetros del motor, una línea `CLAVE=valor` cada uno:

**POLL_SECONDS**=*SEGUNDOS*
:   Segundos entre dos comprobaciones (por defecto `5`).

**PROBE_TIMEOUT**=*SEGUNDOS*
:   Segundos que el puerto TCP tiene para responder a la sonda (por defecto
    `3`).

**MAX_RESTARTS**=*NÚMERO*
:   Reinicios permitidos dentro de la ventana antes de bloquear el objetivo
    (por defecto `5`).

**RESTART_WINDOW**=*SEGUNDOS*
:   Duración de la ventana de recuento de reinicios (por defecto `60`).

Objetivos, uno por línea:

    id puerto política comando...

**id**
:   Un nombre corto y único, usado para los archivos de estado y el diario.

**puerto**
:   El puerto TCP en el que escucha el objetivo, sondeado en `127.0.0.1`.

**política**
:   `always`, `on-failure` o `transient`.

**comando...**
:   El resto de la línea, dividido por espacios (sin comillas), ejecutado en
    primer plano desde el directorio donde se inició **allwatch**.

Políticas:

**always**
:   Reiniciar el objetivo tras cualquier final, incluso con código 0, salvo
    que exista un archivo `id.stop` en el directorio de estado.

**on-failure**
:   Reiniciar tras un fallo o un bloqueo; dejar el objetivo detenido tras un
    final limpio con código 0.

**transient**
:   No reiniciar nunca el objetivo.

Un valor de política distinto de estos tres no se rechaza: el objetivo se
trata entonces como `always`.

Para pedir una parada deliberada, crear `id.stop` en el directorio de estado
antes de que termine el objetivo (`touch /run/allwatch/id.stop` para el
servicio Debian). AllWatch elimina el archivo y no reinicia el objetivo. El
archivo no detiene por sí solo un objetivo en ejecución.

# ESTADOS

AllWatch informa cuatro estados ordinarios, más un estado excepcional de
bloqueo:

**Activo**
:   El proceso existe y su puerto acepta una conexión.

**Bloqueado**
:   El proceso existe pero su puerto no responde. Tras un plazo de gracia,
    AllWatch envía `SIGTERM`, espera hasta 5 segundos a que el objetivo
    termine, envía `SIGKILL` si hace falta y lo considera fallido.

**Caído**
:   El proceso desapareció sin una parada deliberada. AllWatch lee el código
    de salida y reinicia el objetivo si su política lo permite. En un
    objetivo adoptado tras un reinicio del supervisor, el código de salida no
    está disponible; su desaparición se trata como un fallo.

**Terminado**
:   El objetivo terminó y su política indica dejarlo detenido, o se atendió
    una marca de parada del operador. El archivo de estado se elimina.

**Bloqueado (VERROU_CRITIQUE)**
:   El objetivo alcanzó `MAX_RESTARTS` reinicios dentro de `RESTART_WINDOW`.
    AllWatch deja de reiniciarlo, registra una alerta y elimina el archivo de
    estado. Los demás objetivos siguen.

# ARCHIVOS

*/tmp/allwatch-runtime*
:   Directorio de estado por defecto: un archivo `id.pid` y un archivo
    `id.fails` por objetivo; el operador crea un archivo `id.stop` para pedir
    una parada deliberada. AllWatch elimina sus propios archivos `.pid`,
    `.stop` y `.fails` al detenerse; los demás archivos permanecen. El
    directorio se cambia con la variable de entorno `ALLWATCH_RUNTIME`.

*$XDG_STATE_HOME/allwatch/allwatch.log*, *$HOME/.local/state/allwatch/allwatch.log*
:   Diario plano, una línea por evento (`fecha id evento`). El directorio se
    crea si hace falta. AllWatch no rota el diario.

*/etc/allwatch/allwatch.conf*
:   Configuración del servicio Debian, instalada por el paquete `allwatch`.

*/run/allwatch*
:   Directorio de estado del servicio Debian (`ALLWATCH_RUNTIME`), recreado
    en cada arranque y vaciado en cada parada.

*/var/lib/allwatch/allwatch/allwatch.log*
:   Diario del servicio Debian (`XDG_STATE_HOME=/var/lib/allwatch`).

# SERVICIO

El paquete Debian instala `allwatch.service`, que inicia **allwatch** con el
usuario de sistema `allwatch` y `/etc/allwatch/allwatch.conf`. systemd
reinicia el supervisor tras cualquier final (`Restart=always`, sin límite de
arranques); AllWatch reinicia después sus objetivos según su política. La
configuración no se recarga en caliente: tras modificarla, ejecutar:

    systemctl restart allwatch

Comandos útiles:

    systemctl status allwatch
    systemctl start allwatch
    systemctl stop allwatch
    systemctl restart allwatch
    journalctl -u allwatch -f

# SEÑALES

**SIGTERM**, **SIGINT**
:   El supervisor detiene cada objetivo con `SIGTERM`, espera su final, envía
    `SIGKILL` tras 5 segundos si hace falta, elimina sus archivos de estado y
    termina (`130` para `SIGINT`, `143` para `SIGTERM`).

**SIGTERM** a un objetivo
:   El objetivo debe terminar en 5 segundos con código de salida 0. Un
    objetivo que tuvo que ser neutralizado tras un bloqueo se considera
    fallido y se reinicia según su política, aunque termine con código 0
    después de la señal.

# CÓDIGO DE SALIDA

El supervisor no termina por sí solo: se ejecuta hasta `SIGINT` o `SIGTERM`.
Por tanto, no devuelve `0` en funcionamiento normal.

**1**
:   Archivo de configuración ilegible, directorio de estado que no pertenece
    al usuario actual, o error fatal (valor de parámetro inválido, directorio
    de estado o de diario no escribible).

**130**
:   Interrumpido por `SIGINT`.

**143**
:   Terminado por `SIGTERM`.

# EJEMPLOS

Iniciar el supervisor con la configuración de ejemplo del repositorio:

    ./allwatch.sh allwatch.conf

Configuración con un objetivo:

    POLL_SECONDS=5
    PROBE_TIMEOUT=3
    MAX_RESTARTS=5
    RESTART_WINDOW=60
    demo 9001 on-failure ./dummy-target.sh 9001

Con el paquete Debian, usar rutas absolutas para el comando, porque el
servicio se ejecuta desde `/var/lib/allwatch`:

    demo 9001 on-failure /usr/share/doc/allwatch/examples/dummy-target.sh 9001

# LÍMITES

- Sin recarga de la configuración en caliente.
- Sin análisis de diarios de la aplicación para decidir un reinicio.
- Sin comprobaciones por título de ventana, X11 o Wayland.
- Sin supervisión de un objetivo que se separe en segundo plano.
- Los valores de configuración y los nombres de política no se validan: una
  política mal escrita actúa como `always`, y un valor de tiempo no numérico
  o cero puede romper el bucle.
- Tras un reinicio del supervisor, el código de salida de un objetivo
  adoptado no está disponible; su desaparición se trata como un fallo.
- El diario plano no se rota.
- Con más de cuatro objetivos, una parada limpia puede superar el
  `TimeoutStopSec` de 20 segundos del servicio; systemd mata entonces todo el
  grupo de procesos.
- Sin opción `--version` ni `--help` en esta versión. La versión del paquete
  se lee con `dpkg -s allwatch`; una versión futura añadirá estas opciones.

# VÉASE TAMBIÉN

**systemd.service**(5), **systemd.exec**(5), **proc**(5)

# LICENCIA

MIT. Copyright (c) 2026 Ronan Davalan. Véase
`/usr/share/doc/allwatch/LICENSE`.
