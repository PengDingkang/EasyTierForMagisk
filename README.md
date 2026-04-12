# EasyTier for Magisk/KernelSU/APatch

在 Android 设备上以系统级 TUN 模式运行 [EasyTier](https://github.com/EasyTier/EasyTier) VPN 组网。

## 功能

- 可配置的开机自动启动（首次安装需先配置）
- 命令行管理（start/stop/restart/status/enable/disable）
- KernelSU/APatch WebUI 管理界面
  - 查看运行状态与节点信息
  - Peer 列表实时查看
  - 开机自启动开关
  - 在线编辑配置文件，支持保存并重启
  - 错误日志查看
- 兼容 Magisk、KernelSU、APatch 三大框架
- 重刷模块不会覆盖已有配置

## 安装

1. 从 [EasyTier Releases](https://github.com/EasyTier/EasyTier/releases) 下载 `easytier-linux-aarch64` 包
2. 将 `easytier-core` 和 `easytier-cli` 放入模块根目录
3. 打包为 zip，在 Magisk/KSU/APatch Manager 中刷入
4. 编辑配置文件 `/data/adb/easytier/config/config.toml`（填入你的服务器地址和网络信息）
5. 手动运行 `easytier start` 或重启设备

> ⚠ 首次安装不会自动启动服务，需要先编辑好配置。默认启用“开机自动启动”，你也可以在 WebUI 中随时关闭。

## 管理

```bash
easytier start    # 启动
easytier stop     # 停止
easytier restart  # 重启
easytier status   # 查看运行状态和开机自启状态
easytier enable   # 开启开机自启
easytier disable  # 关闭开机自启
```

KernelSU/APatch 用户可在 Manager 中打开模块 WebUI 进行管理和配置编辑。

KernelSU 用户在模块列表中可直接看到运行状态和 IP 信息。

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

## 兼容性

- Magisk ≥ v20.4
- KernelSU ≥ 0.6.7
- APatch
- Android ≥ 9 (API 28)
- arm64 设备
