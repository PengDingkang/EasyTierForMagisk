# EasyTier for Magisk/KernelSU/APatch

在 Android 设备上以系统级 TUN 模式运行 [EasyTier](https://github.com/EasyTier/EasyTier) VPN 组网。

## 升级注意：命令挂载默认关闭

**首次安装或从没有保存过挂载选项的旧版升级后，默认不再将命令挂载到 `/system/bin`。重启后生效。**
已经保存过挂载选择的用户会保留原值。隧道、WebUI 和开机自启使用数据目录下的工具，
无需系统目录挂载或元模块。现有配置和身份数据会保留。

在 Root shell 中使用完整路径 `/data/adb/easytier/easytier` 管理服务，
并更新自行编写的脚本中依赖短命令的调用。需要恢复短命令时，在 WebUI 的
**Shell Command Mount** 中开启挂载并重启设备；KernelSU 下需要可用的挂载元模块。

## 版本说明

- 模块版本：独立维护，用于表示本仓库自身的功能与修复更新
- EasyTier Core 版本：表示当前打包附带的 `easytier-core` / `easytier-cli` 上游版本，由仓库根目录的 `CORE_VERSION` 文件维护

例如，一个版本可以表示为：

- Module: `v1.2.0`
- Bundled EasyTier Core: `v2.6.4`

## 和官方实现的区别

官方项目已经提供了 `easytier-magisk` 与 `easytier-web-dashboard`。本仓库并不是对官方实现的替代，而是一个更偏向 Android 设备本地运维体验的实现：

- 提供内置 WebUI，可直接在 KernelSU/APatch Manager 里查看状态、Peer、日志并编辑本机配置
- 提供统一的本地命令行入口：`/data/adb/easytier/easytier {start|stop|restart|status|enable|disable|cli|mount}`
- 支持开机自启开关，且状态会同时显示在 WebUI 和命令行中
- 明确面向 Magisk、KernelSU、APatch 三种框架

相对地，官方实现更偏向原生脚本方案与官方 Dashboard 生态，例如热点/USB 共享转发、启动参数模式，以及独立的 Web Dashboard。

## 功能

- 可配置的开机自动启动（首次安装需先配置）
- 命令行管理（start/stop/restart/status/enable/disable/cli/mount）
- KernelSU/APatch WebUI 管理界面
  - 查看运行状态与节点信息
  - Peer 列表实时查看
  - 开机自启动开关
  - 可选的 Shell 命令挂载开关（默认关闭）
  - 在线编辑配置文件，支持保存并重启
  - 错误日志查看
- 兼容 Magisk、KernelSU、APatch 三大框架
- 重刷模块不会覆盖已有配置

## 安装

1. 从[本项目 Releases](../../releases) 下载模块 zip，包内已包含校验过的 ARM64 核心，安装时不需要联网下载核心
2. 在 Magisk/KSU/APatch Manager 中刷入
3. 编辑配置文件 `/data/adb/easytier/config/config.toml`（填入你的服务器地址和网络信息）
4. 在 Root shell 中运行 `/data/adb/easytier/easytier start`，安装或升级后重启设备以应用挂载设置

> ⚠ 首次安装不会自动启动服务，需要先编辑好配置。默认启用“开机自动启动”，你也可以在 WebUI 中随时关闭。
>
> 默认不挂载时，系统 PATH 中没有本模块提供的短命令。WebUI、开机启动和 CLI 始终使用 `/data/adb/easytier/` 下的工具，不依赖系统 PATH 中的同名程序。

仓库已提供 GitHub Actions，可用于自动校验脚本、打包模块，以及手动创建 Release。

## 管理

以下命令在 Root shell 中执行（先运行 `su`），完整路径不依赖命令挂载。

```bash
/data/adb/easytier/easytier start    # 启动
/data/adb/easytier/easytier stop     # 停止
/data/adb/easytier/easytier restart  # 重启
/data/adb/easytier/easytier status   # 查看运行状态和开机自启状态
/data/adb/easytier/easytier enable   # 开启开机自启
/data/adb/easytier/easytier disable  # 关闭开机自启
```

KernelSU/APatch 用户可在 Manager 中打开模块 WebUI 进行管理和配置编辑。

KernelSU 用户在模块列表中可直接看到运行状态和 IP 信息。


### 可选的 Shell 命令挂载

**Shell Command Mount** 仅控制是否将命令放进系统命令路径，方便在终端输入短命令；
关闭时 EasyTier 的现有服务和 WebUI 功能仍可用。切换后需要重启设备，升级会保留已保存的选择。
默认不生成 `system/bin` 副本；开启时从私有工具生成，关闭并重启后只保留数据目录中的一份工具。
安装升级尚未重启时修改开关，也会同步更新暂存模块中的选择和工具副本。

KernelSU 下会检查已启用、未标记移除且带有 `metamount.sh` 的元模块；缺少挂载能力时，
WebUI 开关禁用并显示原因，CLI 也会拒绝开启。Magisk/APatch 使用其内置挂载能力。
如果另外在 MMRS 中禁止了该模块挂载，还需要在那里允许挂载。

```sh
/data/adb/easytier/easytier mount status     # 下次启动的挂载设置：1 开启，0 关闭
/data/adb/easytier/easytier mount supported  # 是否有可用的挂载能力：1 支持，0 不支持
/data/adb/easytier/easytier mount enable     # 开启，重启生效
/data/adb/easytier/easytier mount disable    # 关闭，重启生效
```

`mount status` 是保存的设置，不代表当前已完成挂载。选择保存在
`/data/adb/easytier/mount_enabled` 中；默认不挂载通过模块的 `skip_mount` 标记实现。

## 配置

配置文件位于 `/data/adb/easytier/config/config.toml`，示例：

```toml
instance_name = "android"
dhcp = false
ipv4 = "10.144.144.10"
listeners = []

[network_identity]
network_name = "mynet"
network_secret = "mysecret"

[[peer]]
uri = "tcp://YOUR_SERVER_IP:11010"

[flags]
default_protocol = "udp"
enable_encryption = true
mtu = 1300
```

## 核心来源与构建

`easytier-core`、`easytier-cli` 不再作为 Git 源文件保存；本地生成文件和下载缓存均被忽略。
既有 Git 历史没有重写。构建及发布共用 `scripts/ci/fetch-core.sh`：

- 按 `CORE_VERSION` 指定的正式标签下载官方 `easytier-linux-aarch64-<版本>.zip`，不跟随 latest/nightly。
- 用仓库中的 `CORE_ASSET_SHA256` 校验整个上游包，缓存命中时仍重新校验；不匹配就重新下载，下载后仍不匹配则失败。
- 仅提取唯一的 `easytier-core`、`easytier-cli`，检查为 ARM64 静态 ELF 后才替换本地生成文件。
- 缓存在 `.cache/core/`，GitHub Actions 按版本和哈希复用下载包；安装包只包含所需的两个核心工具。

本地构建需要 `curl`、`unzip`、`file`、`sha256sum`，验证还需要 ShellCheck 和 Python 3：

```sh
sh scripts/ci/validate.sh
sh scripts/ci/fetch-core.sh
```

升级核心时，需同时审查并更新 `CORE_VERSION` 和 `CORE_ASSET_SHA256`，然后运行校验与打包。
校验值取自对应官方发布资产；仅修改版本文件无法绕过哈希检查。上游已做 UPX 压缩，脚本不再二次压缩。

## 兼容性

- Magisk ≥ v20.4
- KernelSU ≥ 0.6.7
- APatch
- Android ≥ 9 (API 28)
- arm64 设备

KernelSU 用户不强制要求安装 meta-overlayfs/元模块；安装后模块会同时在 `/data/adb/easytier/` 放置一份运行入口，用于无系统 overlay 环境下的 WebUI 和开机启动。

## 发布与更新元数据

准备新版本时更新模块版本、核心锁定文件和 changelog，**不要提前把 `update.json` 改为尚未发布的版本**。
该文件只表示最近一次已成功发布并验证的稳定版，由 Release Action 维护。

发布顺序为：构建/检查 → 创建 Release 并上传 ZIP → 无认证访问公开下载链接，核对 ZIP 大小和 SHA256
与本地发布包一致 → 从包内 `module.prop` 生成元数据 → 更新默认分支的 `update.json`。
更新日志链接固定到该 Release 标签，避免后续文档变动与已发布版本不一致。

上传失败、公开链接不可用或内容不匹配时，稳定版元数据不会更新；预发布也不会覆盖它。
元数据通过独立的最新分支检出推送，遇到并发提交会重试，不会用旧版本覆盖更高的版本号。
Release 流程按仓库串行执行。首次正式发布之前可以没有 `update.json`，首发验证成功后会自动创建。
