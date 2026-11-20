% ALLWATCH(1) allwatch | Comandos de usuario
% Ronan Davalan
% 2026-11-20

# NOMBRE

allwatch - pequeño supervisor de procesos para Linux

# SINOPSIS

**allwatch** [*CONFIGURACIÓN*]

**allwatch** **--version**

**allwatch** **--diagnose** [*CONFIGURACIÓN*]

**allwatch** **--help**

# DESCRIPCIÓN

**allwatch** es un pequeño supervisor de procesos escrito en Bash. Inicia
cada objetivo configurado como proceso hijo, recuerda el PID asignado por el
núcleo y juzga la salud del objetivo a partir de tres fuentes únicamente: el
proceso existe en `/proc`, su puerto TCP acepta una conexión y el código de
salida que devolvió al terminar. El objetivo debe permanecer en primer plano;
un objetivo que se separa en segundo plano rompe el vínculo padre-hijo.

El objetivo es una caja negra. No se registra ante AllWatch, no le envía
mensajes de estado y no necesita saber que AllWatch existe. El supervisor es
el padre; el objetivo es el hijo.

La configuración se lee una vez, al arrancar. El archivo por defecto es
`allwatch.conf` en el directorio actual; el primer argumento lo reemplaza.

**--version**
:   Mostrar `allwatch 0.1.0` y salir con el código `0`.

**--help**
:   Mostrar el resumen, las opciones, las variables de entorno y la referencia
    a esta página de manual, y salir con el código `0`.

**--diagnose** [*CONFIGURACIÓN*]
:   Leer la configuración, mostrar la versión, la ruta de la configuración, el
    directorio de estado, la ruta del diario y el identificador, puerto y
    política de cada objetivo configurado, y salir. También indica si un
    directorio de estado y un directorio de diario existentes son utilizables.
    No inicia ni sondea ningún objetivo y no escribe estado ni diario. Sale
    con `0` si la configuración es legible y los directorios de estado y
    diario existentes son utilizables, `1` en caso contrario.

Las opciones solo se reconocen como primer argumento.

# CONFIGURACIÓN

La configuración se lee una vez, al arrancar, línea por línea. Las líneas
vacías y las que empiezan por `#` se ignoran.

Parámetros del motor, una línea `CLAVE=valor` cada uno:

**POLL_SECONDS**=*SEGUNDOS*
:   Segundos entre dos comprobaciones (por defecto `5`). El plazo de gracia
    de un bloqueo es `2 * POLL_SECONDS`.

**PROBE_TIMEOUT**=*SEGUNDOS*
:   Segundos que el puerto TCP tiene para responder a la sonda (por defecto
    `3`).

**MAX_RESTARTS**=*NÚMERO*
:   Reinicios permitidos dentro de la ventana antes de bloquear el objetivo
    (por defecto `5`).

**RESTART_WINDOW**=*SEGUNDOS*
:   Duración de la ventana de recuento de reinicios (por defecto `60`).

Los valores se usan tal cual y no se validan.

Objetivos, uno por línea:

    id puerto política comando...

**id**
:   Un nombre corto y único, usado para los archivos de estado y las líneas
    del diario. No debe contener `/` ni `..`; AllWatch no lo valida.

**puerto**
:   El puerto TCP en el que escucha el objetivo. Se sondea en `127.0.0.1`; un
    objetivo que solo escucha en otra dirección se considera colgado.

**política**
:   `always`, `on-failure` o `transient`.

**comando...**
:   El resto de la línea, dividido por espacios (sin comillas), iniciado como
    proceso hijo desde el directorio donde se inició **allwatch**. El comando
    no se ejecuta mediante un shell: no se interpretan tuberías, redirecciones
    ni expansión de variables; esa lógica debe ir en un script ejecutable.
    Con el servicio Debian, usar rutas absolutas.

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

El supervisor distingue cuatro estados ordinarios, más un estado excepcional
de bloqueo. No tiene comando de estado: un estado se lee a través del proceso,
el puerto y el diario plano.

**Activo**
:   El proceso existe y su puerto acepta una conexión.

**Colgado**
:   El proceso existe pero su puerto no responde. AllWatch marca el objetivo
    como sospechoso en la primera sonda fallida y espera `2 * POLL_SECONDS`
    segundos. Si el puerto sigue cerrado, envía `SIGTERM`, espera unos 5
    segundos a que termine, envía `SIGKILL` si hace falta y lo considera
    fallido.

**Caído**
:   El proceso desapareció sin una parada deliberada. AllWatch lee el código
    de salida y reinicia el objetivo si su política lo permite. En un objetivo
    adoptado tras un reinicio del supervisor, el código de salida no está
    disponible; su desaparición se trata como un fallo.

**Terminado**
:   El objetivo terminó y su política indica dejarlo detenido, o se atendió
    una marca de parada del operador. El archivo PID y el archivo de parada se
    eliminan, y el objetivo deja de vigilarse hasta el reinicio del
    supervisor.

**Bloqueado (VERROU_CRITIQUE)**
:   El objetivo alcanzó `MAX_RESTARTS` reinicios dentro de `RESTART_WINDOW`.
    AllWatch deja de reiniciarlo, registra una alerta y elimina el archivo PID.
    Los demás objetivos siguen. El bloqueo dura hasta el reinicio del
    supervisor; el objetivo no se reintenta automáticamente.

# ARCHIVOS

*/tmp/allwatch-runtime*
:   Directorio de estado por defecto de una ejecución manual. Contiene un
    archivo `id.pid` y un archivo `id.fails` por objetivo; el operador crea un
    archivo `id.stop` para pedir una parada deliberada. El directorio se crea
    con modo `0700` si no existe; un directorio existente debe pertenecer al
    usuario actual. AllWatch elimina sus propios archivos `.pid`, `.stop` y
    `.fails` al detenerse; los demás archivos permanecen. El directorio se
    cambia con la variable de entorno `ALLWATCH_RUNTIME`.

`$XDG_STATE_HOME/allwatch/allwatch.log`, `$HOME/.local/state/allwatch/allwatch.log`
:   Diario plano, una línea por evento (`fecha id evento`). El directorio se
    crea si hace falta. AllWatch no rota el diario.

*allwatch.conf*
:   Archivo de configuración por defecto en el directorio actual cuando no se
    da ningún argumento.

*/etc/allwatch/allwatch.conf*
:   Configuración del servicio Debian, instalada por el paquete `allwatch`
    como conffile.

*/run/allwatch*
:   Directorio de estado del servicio Debian (`ALLWATCH_RUNTIME`), creado en
    cada arranque del servicio y eliminado al detenerse.

*/var/lib/allwatch/allwatch/allwatch.log*
:   Diario del servicio Debian (`XDG_STATE_HOME=/var/lib/allwatch`). systemd
    crea `/var/lib/allwatch`; el script crea su subdirectorio `allwatch`.

*/usr/bin/allwatch*
:   Programa instalado (paquete Debian).

*/usr/lib/systemd/system/allwatch.service*
:   Unidad systemd instalada por el paquete Debian.

# SERVICIO

El paquete Debian instala `allwatch.service`, que inicia **allwatch** con el
usuario de sistema `allwatch` y `/etc/allwatch/allwatch.conf`. Con la
configuración entregada, el servicio arranca sin objetivo activo y espera.
systemd reinicia el supervisor tras cualquier final distinto de un
`systemctl stop` explícito (`Restart=always`, sin límite de arranques).
AllWatch reinicia después sus objetivos según su política. La
configuración no se recarga en caliente: tras modificarla, ejecutar:

    systemctl restart allwatch

Los comandos de los objetivos heredan el usuario, el grupo y el directorio de
trabajo (`/var/lib/allwatch`) del servicio. Para ejecutar un objetivo con otro
usuario, crear un drop-in con `systemctl edit allwatch` y definir `User=` y
`Group=`.

Comandos útiles:

    systemctl status allwatch
    systemctl start allwatch
    systemctl stop allwatch
    systemctl restart allwatch
    systemctl enable allwatch
    systemctl disable allwatch
    journalctl -u allwatch -f

# SEÑALES

**SIGTERM**, **SIGINT**
:   El supervisor detiene cada objetivo que siga presente con `SIGTERM`,
    espera unos 5 segundos su final, envía `SIGKILL` si hace falta, elimina
    sus archivos `.pid`, `.stop` y `.fails`, escribe `allwatch ARRET` en el
    diario y termina (`130` para `SIGINT`, `143` para `SIGTERM`).

**SIGTERM** a un objetivo
:   El objetivo trata la señal; AllWatch observa el código de salida
    resultante cuando inició el objetivo, y aplica la política del objetivo.
    En un objetivo adoptado tras un reinicio del supervisor, el código de
    salida no está disponible y su desaparición se trata como un fallo. El
    contrato de objetivo pide un final en 5 segundos con código 0. Cuando
    AllWatch neutraliza él mismo un objetivo colgado, el objetivo se considera
    fallido aunque luego termine con código 0.

**SIGHUP**
:   No se intercepta. No recarga la configuración y normalmente termina el
    supervisor; systemd lo reinicia entonces. Para recargar la configuración,
    usar `systemctl restart allwatch`.

**SIGKILL**
:   No se puede interceptar. AllWatch no ejecuta su limpieza. En una ejecución
    manual, los objetivos sobreviven y el directorio de estado persiste; el
    siguiente supervisor puede adoptar los objetivos vivos. Con el servicio
    Debian, systemd gestiona el grupo de procesos y elimina `/run/allwatch`
    al detenerse la unidad; el siguiente supervisor puede no tener los
    archivos PID y puede iniciar duplicados. No confiar en la adopción tras
    un `SIGKILL`.

# CÓDIGO DE SALIDA

**0**
:   Lo devuelven `--version`, `--help` y un `--diagnose` correcto. El bucle de
    supervisión no termina por sí solo: se ejecuta hasta `SIGINT` o `SIGTERM`
    y, por tanto, no devuelve `0` en funcionamiento normal.

**1**
:   Archivo de configuración ilegible, directorio de estado que no pertenece
    al usuario actual, una comprobación de ruta de `--diagnose` fallida, o
    error fatal (por ejemplo un `POLL_SECONDS` no numérico, o un directorio de
    estado o de diario no escribible).

**130**
:   Interrumpido por `SIGINT`.

**143**
:   Terminado por `SIGTERM`.

El código de salida de un objetivo lo usa el supervisor para aplicar la
política, pero no se devuelve como código de salida del supervisor.

# EJEMPLOS

Iniciar el supervisor con la configuración de ejemplo del repositorio:

    ./allwatch.sh allwatch.conf

Mostrar la versión y la ayuda del programa e inspeccionar una configuración
sin iniciarla:

    ./allwatch.sh --version
    ./allwatch.sh --help
    ./allwatch.sh --diagnose allwatch.conf

Configuración con un objetivo:

    POLL_SECONDS=5
    PROBE_TIMEOUT=3
    MAX_RESTARTS=5
    RESTART_WINDOW=60
    demo 9001 on-failure ./dummy-target.sh 9001

Con el paquete Debian, usar rutas absolutas para el comando, porque el
servicio se ejecuta desde `/var/lib/allwatch`:

    demo 9001 on-failure /usr/share/doc/allwatch/examples/dummy-target.sh 9001

Tras instalar el paquete, copiar la configuración de ejemplo y reiniciar el
servicio:

    sudo cp /usr/share/doc/allwatch/examples/allwatch.conf.example \
       /etc/allwatch/allwatch.conf
    sudo systemctl restart allwatch
    systemctl status allwatch
    journalctl -u allwatch -f

La maqueta acepta `SIGUSR1` (dejar de escuchar, seguir vivo), `SIGUSR2` (caer
con código 1) y `SIGTERM` (final limpio con código 0). Para pedir la parada
deliberada de un objetivo, crear su archivo de parada como usuario del
servicio:

    sudo -u allwatch touch /run/allwatch/demo.stop

# LÍMITES

- Sin recarga de la configuración en caliente.
- Sin análisis de diarios de la aplicación para decidir un reinicio.
- Sin comprobaciones por título de ventana, X11 o Wayland.
- Sin supervisión de un objetivo que se separe en segundo plano.
- El comando no se ejecuta mediante un shell: sin comillas, tuberías,
  redirecciones ni expansión de variables.
- Los valores de configuración y los nombres de política no se validan. Un
  `POLL_SECONDS` cero hace girar el bucle sin descanso; un `POLL_SECONDS` no
  numérico detiene el supervisor con código `1`; un `PROBE_TIMEOUT` no
  numérico hace fallar todas las sondas; una política mal escrita actúa como
  `always`; un `MAX_RESTARTS` o `RESTART_WINDOW` no numérico puede impedir
  alcanzar el límite de reinicios.
- Un `id` con `/` o `..` puede salir del directorio de estado; AllWatch no lo
  valida.
- Tras un reinicio del supervisor, el código de salida de un objetivo
  adoptado no está disponible; su desaparición se trata como un fallo. La
  adopción compara una subcadena de `/proc/<pid>/cmdline`, no el ejecutable
  real; un PID reutilizado con la misma línea de comandos podría adoptarse.
- Un objetivo que solo escucha en una dirección distinta de `127.0.0.1` se
  considera colgado; la sonda es una conexión TCP a `127.0.0.1`.
- Un `SIGKILL` del supervisor no ejecuta la limpieza. En una ejecución manual
  los archivos de estado permanecen y el siguiente supervisor puede adoptar
  los objetivos vivos; con el servicio, systemd elimina `/run/allwatch` al
  detenerse, así que el siguiente supervisor no los adopta y puede iniciar
  duplicados.
- El diario plano no se rota.
- Con cuatro o más objetivos que usen cada uno los 5 segundos completos de
  plazo de gracia, una parada limpia puede superar el `TimeoutStopSec` de 20
  segundos del servicio; systemd mata entonces todo el grupo de procesos.
- `--help` muestra el resumen y sale con el código `0`; las opciones solo se
  reconocen como primer argumento.
- `--diagnose` comprueba la configuración y las rutas; no inicia ni sondea
  ningún objetivo, así que no demuestra que un objetivo esté sano.
- La configuración es una entrada de confianza: los comandos de los objetivos
  se ejecutan con los privilegios del usuario del servicio. Proteger
  `/etc/allwatch/allwatch.conf` contra escrituras que no sean de root.
  AllWatch no aísla los objetivos en un entorno sandbox.

# VÉASE TAMBIÉN

**bash**(1), **systemctl**(1), **journalctl**(1), **systemd.service**(5),
**systemd.exec**(5), **proc**(5), **timeout**(1)

# LICENCIA

MIT. Copyright (c) 2026 Ronan Davalan. Véase
`/usr/share/doc/allwatch/LICENSE`.
