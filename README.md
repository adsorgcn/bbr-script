# BBR 一键加速脚本

<div align="center">

![Version](https://img.shields.io/badge/version-1.0.3-blue.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)
![System](https://img.shields.io/badge/system-CentOS%20|%20Ubuntu%20|%20Debian-orange.svg)

**一键全自动优化加速你的Linux服务器**

适合Linux新手，自动检测依赖，智能优化配置

[快速开始](#-快速开始) · [功能特性](#-功能特性) · [常见问题](#-常见问题) · [技术支持](#-技术支持)

</div>

---

## 📖 项目介绍

这是一个经过深度优化的BBR一键加速脚本，基于 [ylx2016/Linux-NetSpeed](https://github.com/ylx2016/Linux-NetSpeed) 项目改进而来。

**主要改进：**
- ✅ 修复所有已知BUG（CentOS源失败、GitHub依赖等）
- ✅ 代码精简75%，从2337行优化到571行
- ✅ 新增自动依赖检查和安装
- ✅ 智能检测内核版本，避免重复升级
- ✅ 完善的错误提示和重试机制
- ✅ 针对国内VPS优化（阿里云Vault源、CDN镜像）

## ✨ 功能特性

### 🚀 核心功能

| 功能 | 说明 |
|------|------|
| **BBR加速** | 启用Google BBR拥塞控制算法，提升网络速度 |
| **内核升级** | 自动升级到最新稳定内核（支持原生BBR） |
| **智能检测** | 自动检测系统、内核版本、虚拟化类型 |
| **旧内核清理** | 清理多余旧内核，释放/boot空间 |
| **系统优化** | TCP参数优化、网络栈调优 |

### 🛡️ 安全特性

- ✅ Root权限检查
- ✅ 虚拟化类型检测（OpenVZ警告）
- ✅ /boot空间检查
- ✅ 网络连接验证
- ✅ CA证书自动更新

### 🌐 系统支持

| 系统 | 版本 | 状态 |
|------|------|------|
| **CentOS** | 6 / 7 / 8 | ✅ 完美支持（自动修复停服源） |
| **Ubuntu** | 16.04 / 18.04 / 20.04 / 22.04 / 24.04 | ✅ 完美支持 |
| **Debian** | 8 / 9 / 10 / 11 / 12 / 13 | ✅ 完美支持 |

**虚拟化支持：**
- ✅ KVM
- ✅ Xen
- ✅ VMware
- ❌ OpenVZ（无法更换内核）

## 🚀 快速开始

### 一键安装命令

```bash
bash <(curl -sL https://raw.githubusercontent.com/adsorgcn/bbr-script/main/newbbr.sh)
```

使用 wget：

```bash
wget -O newbbr.sh https://raw.githubusercontent.com/adsorgcn/bbr-script/main/newbbr.sh && bash newbbr.sh
```

### 使用步骤

**对于新手用户（推荐）：**

1. **首次运行**：选择 `1` - 安装/启用 BBR
   - 如果内核支持BBR → 直接启用（30秒完成）
   - 如果内核不支持 → 提示需要升级内核

2. **升级内核**（如果需要）：
   - Ubuntu/Debian 系统 → 选择 `2`
   - CentOS 系统 → 选择 `3`
   - 等待下载安装（3-10分钟）
   - 重启VPS

3. **启用BBR**：重启后再次运行脚本，选择 `1`

4. **验证效果**：
   ```bash
   lsmod | grep bbr
   sysctl net.ipv4.tcp_congestion_control
   ```

## 📋 菜单说明

```
╔═════════════════════════════════════════════════╗
║       BBR一键加速脚本 v1.0.3 (优化版)        ║
║       适用于Linux新手，自动检测依赖            ║
║                                                 ║
║       作者: 静水流深    QQ群: 615298           ║
╚═════════════════════════════════════════════════╝

==================== 系统状态 ====================
系统: centos 8
架构: x86_64
内核: 4.18.0-553.6.1.el8.x86_64
BBR状态: ❌ 未启用
BBR模块: ❌ 未加载
队列算法: pfifo_fast
拥塞算法: cubic
=================================================

1. 安装/启用 BBR (推荐先选此项)
2. 升级内核（Ubuntu/Debian）
3. 升级内核（CentOS）
4. 清理旧内核 (释放/boot空间)
5. 查看状态
-------------
0. 退出

请选择操作 [0-5]:
```

## 🎯 优化亮点

### 相比原版的改进

| 项目 | 原版 | 优化版 |
|------|------|--------|
| **代码行数** | 2337行 | 571行（精简75%） |
| **CentOS源** | ❌ 未修复 | ✅ 自动切换Vault源 |
| **内核检测** | ❌ 不检测5.4+ | ✅ 智能检测原生BBR |
| **依赖安装** | ❌ 需手动 | ✅ 自动检测安装 |
| **错误提示** | ❌ 简陋 | ✅ 详细友好 |
| **重试机制** | ❌ 无 | ✅ 自动重试3次 |
| **国内优化** | ❌ 无 | ✅ 阿里云镜像优先 |

### 已修复的问题

1. ✅ CentOS 6/7/8 官方源停服问题
2. ✅ CentOS 8 升级内核卡住问题
3. ✅ Ubuntu HWE包名变更问题
4. ✅ 内核5.4+重复升级问题
5. ✅ 缺少CA证书导致下载失败
6. ✅ OpenVZ虚拟化误操作问题
7. ✅ /boot空间不足导致失败

## ❓ 常见问题

<details>
<summary><b>Q1: 什么系统可以使用？</b></summary>

**支持：**
- CentOS 6/7/8
- Ubuntu 16.04+
- Debian 8+

**不支持：**
- OpenVZ虚拟化（无法更换内核）

检查虚拟化类型：
```bash
systemd-detect-virt
```
</details>

<details>
<summary><b>Q2: BBR有什么用？</b></summary>

BBR（Bottleneck Bandwidth and RTT）是Google开发的拥塞控制算法。

**优势：**
- 高延迟环境下提升30-50%速度
- 丢包场景下表现优异
- 特别适合国际网络连接

**适用场景：**
- VPS连接国外服务
- 代理服务器
- 高延迟网络环境
</details>

<details>
<summary><b>Q3: 升级内核安全吗？</b></summary>

- ✅ 脚本使用官方源（ELRepo/官方仓库）
- ✅ 保留旧内核，出问题可回退
- 升级前备份重要数据
- 确保/boot空间充足（>100MB）
</details>

<details>
<summary><b>Q4: 启用BBR后怎么验证？</b></summary>

```bash
# 查看BBR模块，应看到 tcp_bbr
lsmod | grep bbr

# 查看拥塞控制算法，应显示 bbr
sysctl net.ipv4.tcp_congestion_control
```

或运行脚本选择 `5` 查看状态。
</details>

<details>
<summary><b>Q5: 可以在生产环境使用吗？</b></summary>

可以，建议：
- 先在测试环境验证
- 选择业务低峰期操作
- 备份重要数据和配置

风险评估：内核升级低风险（可回退），BBR启用几乎无风险。
</details>

## 📊 性能提升

**实测数据（仅供参考）：**

| 场景 | 未启用BBR | 启用BBR | 提升 |
|------|-----------|---------|------|
| 国内访问国外 | 2.5 MB/s | 3.8 MB/s | +52% |
| 高延迟环境（200ms+） | 1.2 MB/s | 2.1 MB/s | +75% |
| 丢包环境（5%） | 800 KB/s | 1.5 MB/s | +88% |

*具体效果取决于网络环境*

## 🔄 更新日志

### v1.0.3 (2026-02-21)
- 🔧 修复 `ca-certificates` 依赖误判问题
- 🔧 修复 Debian 硬编码 `linux-image-amd64`，改为动态架构检测，兼容 ARM
- 🔧 修复 `yum.conf` 重复追加 timeout/retries 配置问题
- 🔧 修复 CentOS 8 预检查阶段依赖安装卡住问题
- ✅ 新增 CentOS 8 阿里云 Vault 源支持（BaseOS / AppStream / Extras）
- ✅ Debian/Ubuntu 升级内核前自动切换阿里云 apt 镜像
- ✅ 网络检测新增 163、清华镜像备用检测点

### v1.0.2 (2026-02-19)
- 🔧 修复CentOS 8升级内核卡住问题
- ✅ 添加yum超时配置和自动重试

### v1.0.1 (2026-02-19)
- ✅ 添加作者和QQ群信息到菜单

### v1.0.0 (2026-02-19)
- 🎉 首次发布，基于ylx2016/Linux-NetSpeed深度优化
- ✅ 代码精简75%，修复所有已知BUG

## 📞 技术支持

- **QQ群：** 615298
- **作者：** 静水流深
- **网站：** [中国站长](https://cnwebmasters.com)
- **问题反馈：** [GitHub Issues](https://github.com/adsorgcn/bbr-script/issues)

## 📜 开源协议

本项目采用 MIT 协议开源

## 🙏 致谢

- 原始项目：[ylx2016/Linux-NetSpeed](https://github.com/ylx2016/Linux-NetSpeed)

---

<div align="center">

**如果这个项目对你有帮助，请给个 ⭐ Star 支持一下！**

👉 [GitHub](https://github.com/adsorgcn/bbr-script) · [Gitee](https://gitee.com/palmmedia/bbr-script)

Made with ❤️ by 静水流深

</div>
