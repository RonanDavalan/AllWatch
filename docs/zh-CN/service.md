# 安装并运行 Debian 服务

Debian 软件包把 AllWatch 安装为 systemd 服务。服务在开机时启动，读取一次配置；
如果没有声明任何目标进程，它就等待。本章给出软件包的确切路径、文件和命令。

## 软件包安装的内容

```text
/usr/bin/allwatch                          监控器
/usr/bin/allwatch.sh                       兼容符号链接
/usr/lib/systemd/system/allwatch.service   systemd 单元
/etc/allwatch/allwatch.conf                配置
/usr/share/man/man1/allwatch.1.gz          手册页，英语
/usr/share/man/fr/man1/allwatch.1.gz       手册页，法语
/usr/share/man/de/man1/allwatch.1.gz       手册页，德语
/usr/share/man/es/man1/allwatch.1.gz       手册页，西班牙语
/usr/share/man/zh_CN/man1/allwatch.1.gz    手册页，简体中文
/usr/share/doc/allwatch/README.Debian.gz   软件包说明
/usr/share/doc/allwatch/examples/allwatch.conf.example
/usr/share/doc/allwatch/examples/allwatch.conf  源代码仓库的配置文件
/usr/share/doc/allwatch/examples/dummy-target.sh
```

软件包创建系统用户和组 `allwatch`（主目录 `/var/lib/allwatch`，
shell 为 `/usr/sbin/nologin`）。服务以该用户身份从 `/var/lib/allwatch` 运行。

## 安装

```bash
sudo apt install ./allwatch_0.1.0-7_all.deb
```

软件包安装程序和单元。当 systemd 正在运行时，它会启用并启动 `allwatch.service`。
随附的配置没有活动目标进程，因此服务启动后等待。

检查软件包状态和程序版本：

```bash
dpkg -s allwatch | grep -E '^(Status|Version):'
allwatch --version
```

`allwatch --version` 输出 `allwatch 0.1.0`；软件包版本是 `0.1.0-7`。

## 路径和文件

- `/etc/allwatch/allwatch.conf` 是由 root 拥有的 conffile，服务用户不可写。
  它是信任边界：目标进程的命令以服务用户的权限运行。
- `/var/lib/allwatch` 保存状态和日志，权限 `0700`，所有者 `allwatch:allwatch`，
  由 systemd 创建。平面日志是 `/var/lib/allwatch/allwatch/allwatch.log`。
- `/run/allwatch` 是运行时目录，权限 `0700`，在每次服务启动时创建，
  在服务停止时移除。它保存 `<id>.pid`、`<id>.fails` 和 `<id>.stop`。
- `/var/lib/allwatch` 和 `/run/allwatch` 不会在 purge 后保留；`/run/allwatch`
  不会在停止后保留。

## 声明一个目标进程

以 root 身份编辑 `/etc/allwatch/allwatch.conf`，为每个目标进程添加一行：

```text
id port policy command...
```

一个使用软件包所装测试替身的真实示例：

```bash
sudo apt install netcat-openbsd
sudo cp /usr/share/doc/allwatch/examples/allwatch.conf.example /etc/allwatch/allwatch.conf
sudo systemctl restart allwatch
```

示例声明：

```text
demo 9001 on-failure /usr/share/doc/allwatch/examples/dummy-target.sh 9001
```

检查端口：

```bash
bash -c ': > /dev/tcp/127.0.0.1/9001' && echo "port 9001 answers"
```

服务用户必须能够执行该命令。请使用绝对路径：命令按空格拆分，不支持引号，
也不经过 shell 运行。对于带空格或 shell 语法的参数，请编写一个包装脚本并调用它。

## 无响应的目标进程：重启或告警

`ON_FREEZE` 决定当目标进程仍然存活、但在宽限期后其 TCP 端口不再响应时会发生什么。
`ON_FREEZE=restart`（随附的默认值）发送 `SIGTERM`，等待约五秒，必要时发送 `SIGKILL`，
然后按目标进程的策略重启它。`ON_FREEZE=alert` 不发送信号：它记录一次 `ALERTE GEL`，
让目标进程继续运行，并在端口重新响应时记录 `RETABLI`。崩溃在两种取值下都遵循
目标进程的策略。其他任何值都会在启动时以退出码 1 拒绝。

## 服务命令

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

配置在启动时读取一次；修改后需要运行 `sudo systemctl restart allwatch`。
不支持热重载。

## 在不启动目标进程的情况下检查配置

以服务用户身份、使用服务环境运行 `--diagnose`：

```bash
sudo -u allwatch env ALLWATCH_RUNTIME=/run/allwatch \
  XDG_STATE_HOME=/var/lib/allwatch \
  allwatch --diagnose /etc/allwatch/allwatch.conf
```

它输出版本、配置路径、运行时路径、日志路径、无响应策略，以及每个目标进程的
标识、端口和策略。当配置可读、已存在的运行时目录属于当前用户、已存在的日志目录可写时，
它以 `0` 退出。配置不可读、`ON_FREEZE` 无效、`POLL_SECONDS` 不是数值、
已存在的运行时目录不属于当前用户，或已存在的日志目录不可写时，它以 `1` 退出。
它不启动任何目标进程，也不探测任何端口。

## 在不停止服务的情况下停止一个目标进程

以服务用户身份创建停止文件：

```bash
sudo -u allwatch touch /run/allwatch/demo.stop
```

AllWatch 在目标进程结束时移除该文件，并且不再重启它。该文件本身不会停止正在运行的
目标进程；请向目标进程发送 `SIGTERM`，或让它自行结束。

## 以另一个用户身份运行

服务以 `allwatch` 身份运行。如果目标进程需要 root 或另一个账户，请创建 drop-in：

```bash
sudo systemctl edit allwatch
```

添加：

```ini
[Service]
User=www-data
Group=www-data
```

然后重启：

```bash
sudo systemctl restart allwatch
```

目标进程的命令继承该身份。配置文件仍由 root 拥有。

## 升级

```bash
sudo apt install ./allwatch_0.1.0-7_all.deb
```

`/etc/allwatch/allwatch.conf` 会被保留；如果软件包中的版本发生变化，
dpkg 会询问保留哪个版本。如果服务在升级前处于活动状态，升级后会重启它。
`/var/lib/allwatch` 及其日志会保留。

## 移除和清除

```bash
sudo apt remove allwatch
sudo apt purge allwatch
```

`apt remove` 停止服务，移除程序、单元、手册页和软件包文档。它保留
`/etc/allwatch/allwatch.conf`、`/var/lib/allwatch` 以及 `allwatch` 用户和组。
它不会禁用单元；deb-systemd-helper 的启用状态会保留到 purge。

`apt purge` 还会移除 conffile、`/var/lib/allwatch`、为空时的 `/etc/allwatch`、
可移除时的 `allwatch` 用户和组，以及启用状态。如果仍有进程使用该账户，
`userdel` 或 `groupdel` 可能失败；请用以下命令检查：

```bash
getent passwd allwatch
getent group allwatch
```

## 其他发行版系列：Fedora、openSUSE Leap 和 Arch Linux

Fedora 和 openSUSE Leap 的 `.rpm` 以及 Arch Linux 的 `.pkg.tar.zst` 会把与 Debian 软件包相同的文件安装到相同的路径：`/usr/bin/allwatch`、`/usr/lib/systemd/system/allwatch.service`、`/etc/allwatch/allwatch.conf`、手册页和 `/usr/share/doc/allwatch`。安装您所用系列的文件（依次为 Fedora、openSUSE Leap、Arch Linux）；同一行命令也可升级已安装的版本：

```bash
sudo dnf install ./allwatch-0.1.0-1.fc44.noarch.rpm
sudo zypper install --allow-unsigned-rpm ./allwatch-0.1.0-1.leap160.noarch.rpm
sudo pacman -U ./allwatch-0.1.0-1-any.pkg.tar.zst
```

与 Debian 软件包的区别：服务已安装但未启动，请在声明好目标后运行一次 `sudo systemctl enable --now allwatch`；若您修改过 `/etc/allwatch/allwatch.conf`，它会被保留，并在移除软件包时保存为 `allwatch.conf.rpmsave`（Fedora、openSUSE）或 `allwatch.conf.pacsave`（Arch）；没有清除（purge）操作，因此移除会保留用户 `allwatch` 和 `/var/lib/allwatch`，软件包会显示清除它们的两条命令：

```bash
sudo userdel allwatch
sudo rm -rf /etc/allwatch /var/lib/allwatch
```

## 软件包的已知限制

- 容器验证安装软件包，检查 `--version`、`--help` 和 `--diagnose`，然后移除它。
  它不启动 systemd，因此服务虽已安装并记录，但未在容器中的 systemd 下验证。
- `--diagnose` 是静态的：它不探测目标进程。
- `/run/allwatch` 不会在服务停止后保留。监控器崩溃后，目标进程可能在没有 PID 文件的情况下
  继续存活；重启后的监控器可能启动重复实例。带有 `RuntimeDirectoryPreserve=restart`
  的 drop-in 可以在服务重启期间保留该目录。
