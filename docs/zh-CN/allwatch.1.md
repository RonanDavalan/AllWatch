% ALLWATCH(1) allwatch | 用户命令
% Ronan Davalan
% 2026-11-23

# NOM

allwatch - 面向 Linux 的微型进程监控器

# SYNOPSIS

**allwatch** [*CONFIGURATION*]

**allwatch** **--version**

**allwatch** **--diagnose** [*CONFIGURATION*]

**allwatch** **--help**

# DESCRIPTION

**allwatch** 是用 Bash 写成的小型进程监控器。它把每个已配置的目标进程作为子进程启动，
记住内核分配的 PID，并且只从三个来源判断目标进程的健康：进程仍在 `/proc` 中，
其 TCP 端口接受连接，以及它结束时返回的退出码。目标进程必须留在前台；
转为后台守护进程的目标进程会破坏父子关系。

目标进程是一个黑盒。它不向 AllWatch 注册，不发送状态消息，也不需要知道 AllWatch 的存在。
监控器是父进程；目标进程是子进程。

配置在启动时读取一次。默认是当前目录中的 `allwatch.conf`；第一个参数会替换它。

**--version**
:   输出 `allwatch 0.1.0` 并以 `0` 退出。

**--help**
:   输出概要、选项、环境变量和指向本手册页的提示，然后以 `0` 退出。

**--diagnose** [*CONFIGURATION*]
:   读取配置，输出版本、配置路径、运行时目录、日志路径、无响应策略、目标进程数量，
    以及每个已配置目标进程的标识、端口和策略，然后退出。它还报告已存在的运行时目录
    是否为当前用户拥有的目录，以及已存在的日志目录是否可写。它不启动也不探测目标进程，
    不写状态或日志。配置错误会在任何列表之前输出到标准错误。当配置可读、已存在的状态目录
    属于当前用户且已存在的日志目录可写时，它以 `0` 退出。配置不可读、`ON_FREEZE` 无效、
    `POLL_SECONDS` 不是数值、已存在的状态目录不是当前用户拥有的目录，或已存在的日志目录
    不可写时，它以 `1` 退出。

选项只在第一个参数的位置被识别。

# CONFIGURATION

配置在启动时逐行读取一次。空行和以 `#` 开头的行会被忽略。

引擎参数，每行一个 `KEY=value`：

**POLL_SECONDS**=*SECONDS*
:   两次检查之间的秒数（默认 `5`）。无响应的宽限期是 `2 * POLL_SECONDS`。

**PROBE_TIMEOUT**=*SECONDS*
:   TCP 端口必须响应探测的秒数（默认 `3`）。

**MAX_RESTARTS**=*NUMBER*
:   在窗口内允许的重启次数，达到后目标进程被锁定（默认 `5`）。

**RESTART_WINDOW**=*SECONDS*
:   重启计数窗口的长度（默认 `60`）。

**ON_FREEZE**=*restart*|*alert*
:   对于仍然存活、但在宽限期后端口不再响应的目标进程该怎么办。`restart`（默认）
    发送 `SIGTERM`，等待约 5 秒，必要时发送 `SIGKILL`，并把目标进程视为失败；
    `alert` 不发送信号，记录一次 `ALERTE GEL`，让目标进程继续受监视，并在端口重新响应时
    记录 `RETABLI`。崩溃在两种取值下都遵循目标进程策略。其他任何值都会在启动时
    以退出码 `1` 拒绝。

数值和策略名称按原样使用，不做校验；`ON_FREEZE` 是例外，只接受 `restart` 或 `alert`。

目标进程，每行一个：

    id port policy command...

**id**
:   短的唯一名称，用于状态文件名和日志行。它不得包含 `/` 或 `..`；AllWatch 不做校验。

**port**
:   目标进程监听的 TCP 端口。它在 `127.0.0.1` 上探测；只在另一个地址上监听的目标进程
    会被视为无响应。

**policy**
:   `always`、`on-failure` 或 `transient` 之一。

**command...**
:   该行其余部分，按空白拆分（不支持引号），从启动 **allwatch** 的目录作为子进程启动。
    命令不经过 shell 运行：管道、重定向和变量展开不会被解释；请把这类逻辑放进可执行脚本。
    使用 Debian 服务时，请使用绝对路径。

策略：

**always**
:   目标进程每次结束都重启，即使退出码为 0，除非状态目录中存在 `id.stop` 文件。

**on-failure**
:   崩溃后重启，或在 AllWatch 中和了无响应之后重启（`ON_FREEZE=restart`）；
    在干净的退出码 0 后保持停止。使用 `ON_FREEZE=alert` 时，无响应的目标进程保持运行，
    不会被重启。

**transient**
:   从不重启目标进程。

这三个之外的策略值不会被拒绝：目标进程随后按 `always` 处理。

要请求主动停止，请在目标进程结束前在状态目录中创建 `id.stop`
（对于 Debian 服务，使用 `touch /run/allwatch/id.stop`）。AllWatch 会移除该文件，
并且不重启目标进程。该文件本身不会停止正在运行的目标进程。

# ÉTATS

监控器区分四种普通状态，外加一种异常的锁定状态。它没有状态命令：状态通过进程、
端口和平面日志可见。

**运行中**
:   进程存在且其端口接受连接。

**无响应**
:   进程存在但其端口不响应。AllWatch 在第一次探测失败时把目标进程标记为可疑，
    并等待 `2 * POLL_SECONDS` 秒。如果端口仍然关闭，行为取决于 `ON_FREEZE`：
    `restart` 发送 `SIGTERM`，等待约 5 秒让目标进程停止，必要时发送 `SIGKILL`，
    并把目标进程视为失败；`alert` 不发送信号，记录一次 `ALERTE GEL`，
    让目标进程继续受监视，并在端口重新响应时记录 `RETABLI`。如果进程在无响应期间死亡，
    目标进程按崩溃处理。

**崩溃**
:   进程在没有主动停止的情况下消失。AllWatch 读取退出码，如果目标进程的策略允许，
    就重启它。对于监控器重启后被接管的目标进程，退出码不可用：它的消失按失败处理。

**已退出**
:   目标进程结束且其策略要求不再处理，或操作者的停止标志得到遵守。PID 文件被移除，
    若使用过停止文件也一并移除；在监控器重启之前，目标进程不再受监视。

**锁定（VERROU_CRITIQUE）**
:   目标进程在 `RESTART_WINDOW` 内达到 `MAX_RESTARTS` 次重启。AllWatch 停止重启它，
    记录告警并移除 PID 文件。其他目标进程继续。锁定持续到监控器重启；
    目标进程不会被自动重试。

# FICHIERS

*/tmp/allwatch-runtime*
:   手动运行的默认运行时目录。它为每个目标进程保存一个 `id.pid` 和一个 `id.fails` 文件；
    操作者创建 `id.stop` 文件以请求主动停止。目录不存在时以权限 `0700` 创建；
    已存在的目录必须属于当前用户。AllWatch 停止时从目录中移除 `.pid`、`.stop` 和
    `.fails` 文件；其他文件保留。可用 `ALLWATCH_RUNTIME` 环境变量覆盖该目录。

`$XDG_STATE_HOME/allwatch/allwatch.log`, `$HOME/.local/state/allwatch/allwatch.log`
:   平面事件日志，每个事件一行（`date id event`）。目录按需创建。AllWatch 不轮转日志。

*allwatch.conf*
:   未给参数时，当前目录中的默认配置文件。

*/etc/allwatch/allwatch.conf*
:   Debian 服务使用的配置，由 `allwatch` 软件包作为 conffile 安装。

*/run/allwatch*
:   Debian 服务的运行时目录（`ALLWATCH_RUNTIME`），每次服务启动时创建，服务停止时移除。

*/var/lib/allwatch/allwatch/allwatch.log*
:   Debian 服务的事件日志（`XDG_STATE_HOME=/var/lib/allwatch`）。systemd 创建
    `/var/lib/allwatch`；脚本创建其 `allwatch` 子目录。

*/usr/bin/allwatch*
:   安装的程序（Debian 软件包）。

*/usr/lib/systemd/system/allwatch.service*
:   Debian 软件包安装的 systemd 单元。

# SERVICE

Debian 软件包安装 `allwatch.service`，它以系统用户 `allwatch` 和
`/etc/allwatch/allwatch.conf` 运行 **allwatch**。使用随附的配置时，服务启动时
不带活动目标进程并等待。systemd 在除显式 `systemctl stop` 之外的任何退出后重启监控器
（`Restart=always`，无启动限制）。AllWatch 则按目标进程的策略重启它们。
配置不会在运行时重新加载：编辑后请运行：

    systemctl restart allwatch

目标进程的命令继承服务用户、组和工作目录（`/var/lib/allwatch`）。要以另一个用户运行服务
及其所有目标进程，请用 `systemctl edit allwatch` 创建 drop-in，并设置 `User=` 和 `Group=`。

常用命令：

    systemctl status allwatch
    systemctl start allwatch
    systemctl stop allwatch
    systemctl restart allwatch
    systemctl enable allwatch
    systemctl disable allwatch
    journalctl -u allwatch -f

# SIGNAUX

**SIGTERM**, **SIGINT**
:   监控器向仍存在的每个目标进程发送 `SIGTERM`，等待约 5 秒让其退出，必要时发送
    `SIGKILL`，移除 `.pid`、`.stop` 和 `.fails` 文件，向日志写入 `allwatch ARRET`
    并退出（`SIGINT` 为 `130`，`SIGTERM` 为 `143`）。

**向目标进程发送 SIGTERM**
:   目标进程处理该信号；如果目标进程由 AllWatch 启动，AllWatch 观察由此产生的退出码，
    并应用目标进程策略。对于监控器重启后被接管的目标进程，退出码不可用，其消失按失败处理。
    目标进程约定要求它在 5 秒内以退出码 0 停止。当 AllWatch 自己中和一个无响应的目标进程时，
    即使它稍后以 0 退出，也按失败处理。

**SIGHUP**
:   不处理。它不会重新加载配置，通常会终止监控器；systemd 随后重启它。
    要重新加载配置，请使用 `systemctl restart allwatch`。

**SIGKILL**
:   无法捕获。AllWatch 不执行清理。在手动运行中，目标进程继续存活，运行时目录保留；
    下一个监控器可以接管存活的目标进程。使用 Debian 服务时，systemd 控制 cgroup，
    并在单元停止时移除 `/run/allwatch`，因此下一个监控器可能没有 PID 文件，
    并可能启动重复实例。不要依赖 `SIGKILL` 后的接管。

# CODE DE SORTIE

**0**
:   由 `--version`、`--help` 和成功的 `--diagnose` 返回。监督循环不会自行终止：
    它运行到 `SIGINT` 或 `SIGTERM`，因此在正常操作中不会返回 `0`。

**1**
:   配置文件不可读、`ON_FREEZE` 无效、运行时目录不属于当前用户、`--diagnose` 的路径检查
    失败，或发生致命的运行时错误（例如 `POLL_SECONDS` 不是数值，或状态目录、日志目录
    不可写）。

**130**
:   被 `SIGINT` 中断。

**143**
:   被 `SIGTERM` 终止。

目标进程的退出码被监控器用来应用策略，但不会作为监控器的退出状态返回。
shell 或系统工具的其他致命失败会返回该命令的非零状态，通常是 `1`。

# EXEMPLES

使用源代码仓库中的示例配置运行监控器：

    ./allwatch.sh allwatch.conf

输出版本、帮助摘要，并在不启动的情况下检查配置：

    ./allwatch.sh --version
    ./allwatch.sh --help
    ./allwatch.sh --diagnose allwatch.conf

带一个目标进程的配置：

    POLL_SECONDS=5
    PROBE_TIMEOUT=3
    MAX_RESTARTS=5
    RESTART_WINDOW=60
    ON_FREEZE=restart
    demo 9001 on-failure ./dummy-target.sh 9001

使用 Debian 软件包时，请为命令使用绝对路径，因为服务从 `/var/lib/allwatch` 运行：

    demo 9001 on-failure /usr/share/doc/allwatch/examples/dummy-target.sh 9001

安装软件包后，复制示例配置并重启服务：

    sudo cp /usr/share/doc/allwatch/examples/allwatch.conf.example \
       /etc/allwatch/allwatch.conf
    sudo systemctl restart allwatch
    systemctl status allwatch
    journalctl -u allwatch -f

测试替身需要 `nc`（`netcat-openbsd` 软件包）和 `setpriv`（`util-linux`）。
它接受 `SIGUSR1`（停止监听，保持存活）、`SIGUSR2`（以退出码 1 崩溃）和
`SIGTERM`（以 0 干净退出）。要请求主动停止某个目标进程，请以服务用户身份创建其停止文件：

    sudo -u allwatch touch /run/allwatch/demo.stop

# LIMITES

- 配置不支持热重载。
- 不解析应用程序日志来决定是否重启。
- 不依据窗口标题、X11 或 Wayland 进行检查。
- 不监视转为后台守护进程或二次 fork 的目标进程。
- 命令不经过 shell 运行：不支持引号、管道、重定向或变量展开。
- 数值配置值和策略名称不做校验。`POLL_SECONDS` 为零会让循环不停旋转；非数值的
  `POLL_SECONDS` 会让监控器以退出码 `1` 停止；非数值的 `PROBE_TIMEOUT` 会让每次探测都失败；
  拼错的策略按 `always` 处理；非数值的 `MAX_RESTARTS` 会让每次限制检查都失败，
  因此 `always` 或 `on-failure` 目标进程会不停重启；非数值的 `RESTART_WINDOW` 会在监控器
  下一次需要计算窗口时以退出码 `1` 停止。`ON_FREEZE` 会校验：未知值会让监控器以退出码 `1`
  停止。
- 使用 `ON_FREEZE=alert` 时，端口持续关闭的目标进程会保持存活并处于无响应状态；
  AllWatch 只记录一次 `ALERTE GEL`，只有在端口重新响应或进程死亡时才恢复它。
- 包含 `/` 或 `..` 的 `id` 可能逃出运行时目录；AllWatch 不做校验。
- 监控器重启后，被接管的目标进程的退出码不可用；它的消失按失败处理。接管匹配的是
  `/proc/<pid>/cmdline` 的子串，而不是真实可执行文件；一个被回收的 PID 如果带有相同的
  命令行，就可能被接管。
- 只在 `127.0.0.1` 之外的地址上监听的目标进程会被视为无响应；探测是对 `127.0.0.1` 的
  TCP 连接。
- 对监控器执行 `SIGKILL` 不会运行清理。在手动运行中，运行时文件保留，下一个监控器可以
  接管存活的目标进程；使用服务时，systemd 在停止时移除 `/run/allwatch`，因此下一个监控器
  不会接管它们，并可能启动重复实例。
- 平面日志不做轮转。
- 当四个或更多目标进程各自用满 5 秒宽限期时，一次干净停止可能超过服务的 20 秒
  `TimeoutStopSec`；systemd 随后会杀死整个 cgroup。
- `--help` 输出摘要并以 `0` 退出；选项只在第一个参数的位置被识别。
- `--diagnose` 检查配置和路径；它不启动也不探测目标进程，因此不能证明某个目标进程健康。
- 配置是受信任的输入：目标进程的命令以服务用户的权限运行。请保护
  `/etc/allwatch/allwatch.conf`，防止非 root 写入者修改。AllWatch 不对目标进程做沙箱隔离。

# VOIR AUSSI

**bash**(1), **systemctl**(1), **journalctl**(1), **systemd.service**(5),
**systemd.exec**(5), **proc**(5), **timeout**(1)

# LICENCE

MIT。Copyright (c) 2026 Ronan Davalan。参见 `/usr/share/doc/allwatch/LICENSE`。
