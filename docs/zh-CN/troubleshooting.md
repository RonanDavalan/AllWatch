# 故障排查

AllWatch 没有状态命令。目标进程的状态从进程、TCP 端口和平面日志中读取。
本章给出常见故障的确切命令。

## 先读取服务状态

```bash
sudo systemctl status allwatch
sudo journalctl -u allwatch -n 50 --no-pager
sudo tail -n 50 /var/lib/allwatch/allwatch/allwatch.log
```

日志行是 `date id event`。事件包括 `DEMARRAGE`、`DEMARRE`、`ADOPTE`、`PLANTE`、
`ALERTE GEL`、`RETABLI`、`NEUTRALISE SIGTERM`、`NEUTRALISE SIGKILL`、
`CRASHE code=N`、`RELANCE`、`ALERTE VERROU_CRITIQUE`、`QUITTE` 和 `ARRET`。

## 服务没有启动

程序按系统语言（`LC_ALL`、`LC_MESSAGES` 或 `LANG`）输出这些消息；默认语言为英语。

- `allwatch: 无法读取配置文件：/etc/allwatch/allwatch.conf`——文件缺失或服务用户无法读取。
  请检查 `sudo -u allwatch test -r /etc/allwatch/allwatch.conf` 和 `sudo systemctl cat allwatch`。
- `allwatch: /run/allwatch 不属于当前用户`——运行时目录属于另一个用户。
  请检查 `ls -ld /run/allwatch /var/lib/allwatch`；单元以 `allwatch` 身份创建它们。
  如果你添加了使用另一个 `User=` 的 drop-in，请修正所有权或移除该 drop-in。
- `status=203/EXEC`——程序缺失或不可执行。请重新安装软件包。
- 配置错误导致 `status=1/FAILURE`——以服务用户身份运行 `--diagnose`（见下文）。

## 目标进程没有被重启

- 策略 `on-failure`：以退出码 `0` 结束的目标进程会保持停止。这是约定，不是故障。
  如果它必须在干净退出后重启，请使用 `always`。
- 策略 `transient`：从不重启。
- 存在停止文件：`ls -l /run/allwatch/demo.stop`；如果停止并非本意，请移除它。
  该文件本身不会停止正在运行的目标进程。
- `ALERTE VERROU_CRITIQUE`：目标进程在 `RESTART_WINDOW` 内达到 `MAX_RESTARTS`。
  修复原因，然后重启服务；锁定会持续到监控器重启。
- `CRASHE code=N`：目标进程以退出码 N 结束。请读取它自己的日志；AllWatch 只报告退出码。

## 目标进程被报告为无响应，但它仍在运行

- 探测命令是 `timeout 3 bash -c ': > /dev/tcp/127.0.0.1/9001'`。目标进程必须在声明的端口上
  监听 `127.0.0.1`（或 `0.0.0.0`）。只在另一个地址上监听的目标进程会被视为无响应。
- `/etc/allwatch/allwatch.conf` 中的端口错误；请用 `ss -ltnp | grep 9001` 检查。
- 目标进程比 `PROBE_TIMEOUT=3` 慢；请在配置中提高该值，然后重启服务。
- 目标进程存活但其监听器已关闭；这正是无响应状态。使用 `ON_FREEZE=restart`（默认值）时，
  AllWatch 发送 `SIGTERM`，等待 5 秒，然后发送 `SIGKILL`，并重启它。使用 `ON_FREEZE=alert` 时，
  它记录一次 `ALERTE GEL`，让目标进程继续运行；端口重新响应时记录 `RETABLI`。

## `--diagnose` 返回 0，但目标进程不健康

`--diagnose` 是静态的。它读取配置和路径；它不探测目标进程。返回码 `0` 只能证明
监控器能够读取配置并使用其目录。

## 测试替身不响应

- 缺少 `netcat-openbsd`：`sudo apt install netcat-openbsd`。
- 命令使用了相对路径。服务从 `/var/lib/allwatch` 运行；请使用绝对路径
  `/usr/share/doc/allwatch/examples/dummy-target.sh`。
- 端口已被占用：`ss -ltnp | grep 9001`。
- 服务用户无法执行该文件：
  `sudo -u allwatch test -x /usr/share/doc/allwatch/examples/dummy-target.sh`。

## 日志无限增长

AllWatch 不轮转日志。请使用 logrotate 或 systemd 定时器；
文件是 `/var/lib/allwatch/allwatch/allwatch.log`。

## 监控器重启后出现重复的目标进程

服务停止时会移除 `/run/allwatch`。目标进程可能在监控器崩溃后继续存活，却没有 PID 文件；
新的监控器会启动一个重复实例。请添加 drop-in：

```bash
sudo systemctl edit allwatch
```

```ini
[Service]
RuntimeDirectoryPreserve=restart
```

然后重启。运行时目录会在服务重启期间保留，因此新的监控器可以接管仍然存活的 PID。

## 日志中没有任何内容

服务以 `allwatch` 身份运行，并写入 `/var/lib/allwatch/allwatch/allwatch.log`；
请用 `sudo systemctl show allwatch -p Environment` 检查服务环境。如果目录不可写，
日志会保持为空；`--diagnose` 会报告这一点。
