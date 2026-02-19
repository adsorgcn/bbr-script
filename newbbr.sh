#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

#=================================================
#	System: CentOS 6/7, Debian 8+, Ubuntu 16+
#	Description: 一键全自动优化加速你的服务器
#	Version: 1.0.2
#	Author: 静水流深
#	QQ群: 615298
#=================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;36m'
PLAIN='\033[0m'

sh_ver="1.0.2"

# 检查root权限
[[ $EUID -ne 0 ]] && echo -e "${RED}错误：请使用root用户运行此脚本${PLAIN}" && exit 1

# 系统信息
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS=$ID
    VER=$VERSION_ID
elif [[ -f /etc/redhat-release ]]; then
    OS="centos"
    VER=$(grep -oE '[0-9]+' /etc/redhat-release | head -1)
else
    echo -e "${RED}不支持的系统${PLAIN}"
    exit 1
fi

# 架构检测
ARCH=$(uname -m)
[[ $ARCH == "x86_64" ]] && ARCH_NAME="amd64" || ARCH_NAME=$ARCH

echo -e "${BLUE}检测到系统: $OS $VER ($ARCH)${PLAIN}"

# 检查必要依赖并自动安装
check_dependencies() {
    echo -e "${BLUE}检查系统依赖...${PLAIN}"
    
    # 检测包管理器
    if [[ "$OS" =~ centos|rhel|fedora ]]; then
        PKG_MANAGER="yum"
        PKG_INSTALL="yum install -y"
        DEPS="ca-certificates wget curl"
    elif [[ "$OS" =~ debian|ubuntu ]]; then
        PKG_MANAGER="apt-get"
        PKG_INSTALL="apt-get install -y"
        DEPS="ca-certificates wget curl"
    else
        echo -e "${YELLOW}未知包管理器，跳过依赖检查${PLAIN}"
        return 0
    fi
    
    # 检查并安装依赖
    local need_install=()
    for dep in $DEPS; do
        if ! command -v $dep &>/dev/null && ! rpm -q $dep &>/dev/null && ! dpkg -l | grep -q "^ii  $dep"; then
            need_install+=($dep)
        fi
    done
    
    if [[ ${#need_install[@]} -gt 0 ]]; then
        echo -e "${YELLOW}缺少依赖: ${need_install[*]}${PLAIN}"
        echo -e "${BLUE}正在自动安装依赖...${PLAIN}"
        
        if [[ "$OS" =~ centos|rhel|fedora ]]; then
            $PKG_INSTALL ${need_install[*]}
            # 更新CA证书
            update-ca-trust force-enable 2>/dev/null
        elif [[ "$OS" =~ debian|ubuntu ]]; then
            apt-get update -qq
            $PKG_INSTALL ${need_install[*]}
            # 更新CA证书
            update-ca-certificates 2>/dev/null
        fi
        
        if [[ $? -eq 0 ]]; then
            echo -e "${GREEN}依赖安装完成${PLAIN}"
        else
            echo -e "${RED}依赖安装失败，可能影响脚本运行${PLAIN}"
        fi
    else
        echo -e "${GREEN}所有依赖已安装${PLAIN}"
    fi
}

# 检查虚拟化类型
check_virt() {
    echo -e "${BLUE}检查虚拟化类型...${PLAIN}"
    
    # 尝试使用systemd-detect-virt
    if command -v systemd-detect-virt &>/dev/null; then
        virt_type=$(systemd-detect-virt)
    elif command -v virt-what &>/dev/null; then
        virt_type=$(virt-what | head -1)
    else
        # 简单检测
        if grep -q "openvz" /proc/vz/version 2>/dev/null || grep -q "openvz" /proc/cpuinfo 2>/dev/null; then
            virt_type="openvz"
        else
            virt_type="unknown"
        fi
    fi
    
    echo -e "${GREEN}虚拟化类型: ${virt_type}${PLAIN}"
    
    # OpenVZ检测
    if [[ "$virt_type" == "openvz" ]]; then
        echo -e "${RED}╔════════════════════════════════════════════╗${PLAIN}"
        echo -e "${RED}║  警告：检测到OpenVZ虚拟化                 ║${PLAIN}"
        echo -e "${RED}║  OpenVZ容器无法更换内核，无法启用BBR      ║${PLAIN}"
        echo -e "${RED}║  建议：更换为KVM/Xen虚拟化的VPS           ║${PLAIN}"
        echo -e "${RED}╚════════════════════════════════════════════╝${PLAIN}"
        read -p "是否继续（可能失败）? [y/N]: " continue_openvz
        [[ ! "$continue_openvz" =~ ^[Yy]$ ]] && exit 1
    fi
}

# 检查/boot分区空间
check_boot_space() {
    echo -e "${BLUE}检查/boot分区空间...${PLAIN}"
    
    # 获取/boot分区可用空间（MB）
    boot_available=$(df -m /boot 2>/dev/null | tail -1 | awk '{print $4}')
    
    if [[ -n "$boot_available" ]]; then
        if [[ $boot_available -lt 100 ]]; then
            echo -e "${RED}警告：/boot分区空间不足 (可用: ${boot_available}MB)${PLAIN}"
            echo -e "${YELLOW}建议：先清理旧内核释放空间，或确保有至少100MB可用空间${PLAIN}"
            read -p "是否继续? [y/N]: " continue_boot
            [[ ! "$continue_boot" =~ ^[Yy]$ ]] && exit 1
        else
            echo -e "${GREEN}/boot分区空间充足 (可用: ${boot_available}MB)${PLAIN}"
        fi
    fi
}

# 检查网络连接
check_network() {
    echo -e "${BLUE}检查网络连接...${PLAIN}"
    
    # 测试网络连接（优先国内镜像）
    if curl -s --connect-timeout 5 https://mirrors.aliyun.com > /dev/null 2>&1; then
        echo -e "${GREEN}网络连接正常（阿里云镜像）${PLAIN}"
        return 0
    elif curl -s --connect-timeout 5 https://www.baidu.com > /dev/null 2>&1; then
        echo -e "${GREEN}网络连接正常${PLAIN}"
        return 0
    elif ping -c 2 8.8.8.8 > /dev/null 2>&1; then
        echo -e "${YELLOW}网络连接正常但HTTPS访问受限${PLAIN}"
        return 0
    else
        echo -e "${RED}网络连接失败，请检查网络设置${PLAIN}"
        return 1
    fi
}

# 修复CentOS死源
fixCentOSRepo() {
    [[ ! "$OS" =~ centos ]] && return
    [[ "$VER" != "6" && "$VER" != "7" ]] && return
    
    echo -e "${YELLOW}检测到CentOS ${VER}，官方源已停服，切换到Vault源...${PLAIN}"
    mkdir -p /etc/yum.repos.d/backup
    mv /etc/yum.repos.d/CentOS-*.repo /etc/yum.repos.d/backup/ 2>/dev/null
    
    if [[ "$VER" == "7" ]]; then
        cat > /etc/yum.repos.d/CentOS-Vault.repo <<'EOF'
[base]
name=CentOS-7-Vault-Base
baseurl=https://mirrors.aliyun.com/centos-vault/7.9.2009/os/$basearch/
gpgcheck=0
enabled=1
[updates]
name=CentOS-7-Vault-Updates
baseurl=https://mirrors.aliyun.com/centos-vault/7.9.2009/updates/$basearch/
gpgcheck=0
enabled=1
[extras]
name=CentOS-7-Vault-Extras
baseurl=https://mirrors.aliyun.com/centos-vault/7.9.2009/extras/$basearch/
gpgcheck=0
enabled=1
EOF
    elif [[ "$VER" == "6" ]]; then
        cat > /etc/yum.repos.d/CentOS-Vault.repo <<'EOF'
[base]
name=CentOS-6-Vault-Base
baseurl=https://mirrors.aliyun.com/centos-vault/6.10/os/$basearch/
gpgcheck=0
enabled=1
[updates]
name=CentOS-6-Vault-Updates
baseurl=https://mirrors.aliyun.com/centos-vault/6.10/updates/$basearch/
gpgcheck=0
enabled=1
EOF
    fi
    yum clean all >/dev/null 2>&1
    echo -e "${GREEN}CentOS Vault源配置完成${PLAIN}"
}

# 检测BBR状态
check_bbr_status() {
    local param=$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk '{print $3}')
    if [[ "$param" == "bbr" ]]; then
        return 0
    else
        return 1
    fi
}

# 检测内核版本是否支持原生BBR
check_kernel_native_bbr() {
    local kernel_version=$(uname -r | cut -d- -f1)
    local major=$(echo "$kernel_version" | cut -d. -f1)
    local minor=$(echo "$kernel_version" | cut -d. -f2)
    
    # 内核4.9+支持BBR，5.4+为最佳
    if [[ $major -gt 5 ]] || [[ $major -eq 5 && $minor -ge 4 ]]; then
        echo -e "${GREEN}当前内核 $kernel_version 原生支持BBR（最佳）${PLAIN}"
        return 0
    elif [[ $major -eq 4 && $minor -ge 9 ]] || [[ $major -ge 5 ]]; then
        echo -e "${YELLOW}当前内核 $kernel_version 支持BBR（建议升级到5.4+）${PLAIN}"
        return 0
    else
        echo -e "${RED}当前内核 $kernel_version 不支持BBR，需要升级${PLAIN}"
        return 1
    fi
}

# 启用BBR
enable_bbr() {
    if check_bbr_status; then
        echo -e "${GREEN}BBR已经启用${PLAIN}"
        return 0
    fi
    
    if ! check_kernel_native_bbr; then
        echo -e "${YELLOW}需要先升级内核才能启用BBR${PLAIN}"
        return 1
    fi
    
    echo -e "${BLUE}正在配置BBR...${PLAIN}"
    
    # 配置sysctl
    cat > /etc/sysctl.d/99-bbr.conf <<EOF
# BBR配置
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# 基础网络优化
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_slow_start_after_idle = 0
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_max_syn_backlog = 8192
EOF
    
    sysctl -p /etc/sysctl.d/99-bbr.conf >/dev/null 2>&1
    
    if check_bbr_status; then
        echo -e "${GREEN}╔════════════════════════════════════════════╗${PLAIN}"
        echo -e "${GREEN}║  BBR启用成功！                            ║${PLAIN}"
        echo -e "${GREEN}║  您的网络加速已生效                       ║${PLAIN}"
        echo -e "${GREEN}╚════════════════════════════════════════════╝${PLAIN}"
        return 0
    else
        echo -e "${RED}BBR启用失败，请检查内核版本${PLAIN}"
        return 1
    fi
}

# Ubuntu/Debian升级内核
upgrade_kernel_debian() {
    echo -e "${BLUE}正在为 $OS $VER 升级内核...${PLAIN}"
    
    # 检测当前内核
    current_kernel=$(uname -r | cut -d- -f1)
    local major=$(echo "$current_kernel" | cut -d. -f1)
    local minor=$(echo "$current_kernel" | cut -d. -f2)
    
    # 如果已经是5.4+，无需升级
    if [[ $major -gt 5 ]] || [[ $major -eq 5 && $minor -ge 4 ]]; then
        echo -e "${GREEN}当前内核 $current_kernel 已是最新，无需升级${PLAIN}"
        enable_bbr
        return 0
    fi
    
    echo -e "${BLUE}更新软件包列表...${PLAIN}"
    apt-get update
    
    # Ubuntu 20.04+和Debian 11+的内核已经是5.4+
    if [[ "$OS" == "ubuntu" ]]; then
        if [[ "$VER" =~ ^(20|22|24) ]]; then
            echo -e "${BLUE}安装最新内核...${PLAIN}"
            apt-get install -y linux-generic
        elif [[ "$VER" == "18" ]]; then
            echo -e "${BLUE}安装HWE内核(5.4)...${PLAIN}"
            apt-get install -y --install-recommends linux-generic-hwe-18.04
        else
            echo -e "${BLUE}安装HWE内核...${PLAIN}"
            apt-get install -y --install-recommends linux-generic-hwe-16.04 2>/dev/null || \
            apt-get install -y linux-generic
        fi
    elif [[ "$OS" == "debian" ]]; then
        echo -e "${BLUE}安装最新内核...${PLAIN}"
        apt-get install -y linux-image-amd64
    fi
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}╔════════════════════════════════════════════╗${PLAIN}"
        echo -e "${GREEN}║  内核升级完成！                           ║${PLAIN}"
        echo -e "${GREEN}║  需要重启系统才能使用新内核               ║${PLAIN}"
        echo -e "${GREEN}╚════════════════════════════════════════════╝${PLAIN}"
        return 0
    else
        echo -e "${RED}内核升级失败${PLAIN}"
        return 1
    fi
}

# CentOS升级内核（使用ELRepo或官方仓库）
upgrade_kernel_centos() {
    # CentOS 8+ 不支持，直接提示换系统
    if [[ -n "$VER" && "$VER" -ge 8 ]] 2>/dev/null; then
        echo ""
        echo -e "${RED}╔══════════════════════════════════════════════════════╗${PLAIN}"
        echo -e "${RED}║      ⚠  不支持 CentOS ${VER} 及以上版本升级内核        ║${PLAIN}"
        echo -e "${RED}╠══════════════════════════════════════════════════════╣${PLAIN}"
        echo -e "${RED}║  CentOS 8+ 官方已停止维护，ELRepo 支持不稳定，      ║${PLAIN}"
        echo -e "${RED}║  强行升级内核极易导致系统损坏或无法启动。            ║${PLAIN}"
        echo -e "${RED}║                                                      ║${PLAIN}"
        echo -e "${YELLOW}║  推荐更换为以下系统后再使用本脚本：                 ║${PLAIN}"
        echo -e "${GREEN}║    ✔  Ubuntu 20.04 / 22.04 / 24.04               ║${PLAIN}"
        echo -e "${GREEN}║    ✔  Debian 10 / 11 / 12                        ║${PLAIN}"
        echo -e "${YELLOW}║                                                      ║${PLAIN}"
        echo -e "${YELLOW}║  如需继续使用 CentOS，可考虑迁移到：               ║${PLAIN}"
        echo -e "${YELLOW}║    ✔  Rocky Linux 8/9  （CentOS 官方替代品）      ║${PLAIN}"
        echo -e "${YELLOW}║    ✔  AlmaLinux 8/9                               ║${PLAIN}"
        echo -e "${RED}╚══════════════════════════════════════════════════════╝${PLAIN}"
        echo ""
        read -n1 -rp "按任意键返回主菜单..." key
        return 1
    fi

    echo -e "${BLUE}正在为 CentOS $VER 升级内核...${PLAIN}"
    
    # 检测当前内核
    current_kernel=$(uname -r | cut -d- -f1)
    local major=$(echo "$current_kernel" | cut -d. -f1)
    local minor=$(echo "$current_kernel" | cut -d. -f2)
    
    if [[ $major -gt 5 ]] || [[ $major -eq 5 && $minor -ge 4 ]]; then
        echo -e "${GREEN}当前内核 $current_kernel 已支持BBR${PLAIN}"
        enable_bbr
        return 0
    fi
    
    fixCentOSRepo
    
    if [[ "$VER" == "7" ]]; then
        # 配置yum超时参数，避免卡住
        echo -e "${BLUE}配置yum参数（防止下载超时）...${PLAIN}"
        echo "timeout=30" >> /etc/yum.conf
        echo "retries=3" >> /etc/yum.conf
        
        # 尝试从ELRepo安装（优先阿里云镜像）
        echo -e "${BLUE}安装ELRepo源...${PLAIN}"
        rpm --import https://mirrors.aliyun.com/elrepo/RPM-GPG-KEY-elrepo.org 2>/dev/null || \
        rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
        
        if [[ "$VER" == "7" ]]; then
            yum install -y https://mirrors.aliyun.com/elrepo/elrepo/el7/x86_64/RPMS/elrepo-release-7.0-6.el7.elrepo.noarch.rpm 2>/dev/null || \
            yum install -y https://www.elrepo.org/elrepo-release-7.el7.elrepo.noarch.rpm
        fi
        
        # 清理缓存
        echo -e "${BLUE}清理yum缓存...${PLAIN}"
        yum clean all
        
        # 安装最新主线内核
        echo -e "${YELLOW}╔════════════════════════════════════════════════════╗${PLAIN}"
        echo -e "${YELLOW}║  正在下载内核（6.x），文件较大约150-200MB        ║${PLAIN}"
        echo -e "${YELLOW}║  预计需要3-10分钟，请耐心等待...                  ║${PLAIN}"
        echo -e "${YELLOW}║  脚本会自动重试，如长时间无进度可Ctrl+C中断      ║${PLAIN}"
        echo -e "${YELLOW}╚════════════════════════════════════════════════════╝${PLAIN}"
        echo ""
        
        # 尝试3次
        local attempt=1
        local max_attempts=3
        local success=0
        
        while [[ $attempt -le $max_attempts ]]; do
            echo -e "${BLUE}尝试安装内核 (第 $attempt/$max_attempts 次)...${PLAIN}"
            
            # 使用yum自带的超时机制
            yum --enablerepo=elrepo-kernel install -y kernel-ml kernel-ml-devel
            
            if [[ $? -eq 0 ]]; then
                success=1
                break
            else
                echo -e "${RED}安装失败，准备重试...${PLAIN}"
                yum clean all
                attempt=$((attempt + 1))
                [[ $attempt -le $max_attempts ]] && sleep 3
            fi
        done
        
        if [[ $success -eq 1 ]]; then
            # 设置默认启动新内核
            echo -e "${BLUE}配置GRUB启动项...${PLAIN}"
            grub2-set-default 0
            grub2-mkconfig -o /boot/grub2/grub.cfg
            echo -e "${GREEN}╔════════════════════════════════════════════╗${PLAIN}"
            echo -e "${GREEN}║  内核升级完成！                           ║${PLAIN}"
            echo -e "${GREEN}║  需要重启系统才能使用新内核               ║${PLAIN}"
            echo -e "${GREEN}╚════════════════════════════════════════════╝${PLAIN}"
            return 0
        else
            echo -e "${RED}╔═══════════════════════════════════════════════════╗${PLAIN}"
            echo -e "${RED}║  内核升级失败（尝试${max_attempts}次后仍失败）    ║${PLAIN}"
            echo -e "${RED}║                                                   ║${PLAIN}"
            echo -e "${RED}║  建议手动操作：                                   ║${PLAIN}"
            echo -e "${RED}║  1. yum clean all                                 ║${PLAIN}"
            echo -e "${RED}║  2. yum --enablerepo=elrepo-kernel install -y kernel-ml ║${PLAIN}"
            echo -e "${RED}║                                                   ║${PLAIN}"
            echo -e "${RED}║  或者考虑升级到Rocky Linux / AlmaLinux           ║${PLAIN}"
            echo -e "${RED}╚═══════════════════════════════════════════════════╝${PLAIN}"
            return 1
        fi
    else
        echo -e "${RED}CentOS $VER 不支持自动升级内核${PLAIN}"
        return 1
    fi
}

# 卸载多余旧内核（保留当前和最新）
remove_old_kernels() {
    echo -e "${YELLOW}检测旧内核...${PLAIN}"
    
    if [[ "$OS" =~ centos|rhel ]]; then
        # 列出所有已安装内核
        installed_kernels=$(rpm -qa | grep ^kernel-[0-9] | sort -V)
        kernel_count=$(echo "$installed_kernels" | wc -l)
        
        if [[ $kernel_count -gt 2 ]]; then
            echo -e "${BLUE}发现 $kernel_count 个内核，保留最新2个${PLAIN}"
            echo -e "${YELLOW}将要删除的内核：${PLAIN}"
            echo "$installed_kernels" | head -n -2
            
            read -p "确认删除这些旧内核? [y/N]: " confirm_remove
            if [[ "$confirm_remove" =~ ^[Yy]$ ]]; then
                # 保留最新的2个，删除其他
                old_kernels=$(echo "$installed_kernels" | head -n -2)
                if [[ -n "$old_kernels" ]]; then
                    echo "$old_kernels" | xargs yum remove -y
                    echo -e "${GREEN}旧内核清理完成${PLAIN}"
                fi
            else
                echo -e "${YELLOW}已取消${PLAIN}"
            fi
        else
            echo -e "${GREEN}无需清理旧内核（当前: $kernel_count 个）${PLAIN}"
        fi
    elif [[ "$OS" =~ debian|ubuntu ]]; then
        current_kernel=$(uname -r)
        installed_kernels=$(dpkg -l | grep 'linux-image-[0-9]' | awk '{print $2}')
        
        echo -e "${YELLOW}当前运行内核: $current_kernel${PLAIN}"
        echo -e "${YELLOW}已安装的内核：${PLAIN}"
        echo "$installed_kernels"
        
        read -p "是否清理非当前内核? [y/N]: " confirm_remove
        if [[ "$confirm_remove" =~ ^[Yy]$ ]]; then
            for kernel in $installed_kernels; do
                if [[ "$kernel" != *"$current_kernel"* ]]; then
                    echo -e "${BLUE}移除旧内核: $kernel${PLAIN}"
                    apt-get purge -y "$kernel" 2>/dev/null
                fi
            done
            apt-get autoremove -y
            echo -e "${GREEN}旧内核清理完成${PLAIN}"
        else
            echo -e "${YELLOW}已取消${PLAIN}"
        fi
    fi
}

# 显示当前状态
show_status() {
    echo -e "\n${BLUE}==================== 系统状态 ====================${PLAIN}"
    echo -e "${GREEN}系统:${PLAIN} $OS $VER"
    echo -e "${GREEN}架构:${PLAIN} $ARCH"
    echo -e "${GREEN}内核:${PLAIN} $(uname -r)"
    
    if check_bbr_status; then
        echo -e "${GREEN}BBR状态:${PLAIN} ✅ 已启用"
    else
        echo -e "${GREEN}BBR状态:${PLAIN} ❌ 未启用"
    fi
    
    if lsmod | grep -q bbr; then
        echo -e "${GREEN}BBR模块:${PLAIN} ✅ 已加载"
    else
        echo -e "${GREEN}BBR模块:${PLAIN} ❌ 未加载"
    fi
    
    local qdisc=$(sysctl net.core.default_qdisc 2>/dev/null | awk '{print $3}')
    echo -e "${GREEN}队列算法:${PLAIN} ${qdisc:-未设置}"
    
    local congestion=$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk '{print $3}')
    echo -e "${GREEN}拥塞算法:${PLAIN} ${congestion:-未设置}"
    
    echo -e "${BLUE}=================================================${PLAIN}\n"
}

# 主菜单
show_menu() {
    clear
    echo -e "${BLUE}╔═════════════════════════════════════════════════╗${PLAIN}"
    echo -e "${BLUE}║       BBR一键加速脚本 v${sh_ver} (优化版)        ║${PLAIN}"
    echo -e "${BLUE}║       适用于Linux新手，自动检测依赖            ║${PLAIN}"
    echo -e "${BLUE}║                                                 ║${PLAIN}"
    echo -e "${BLUE}║       作者: 静水流深    QQ群: 615298           ║${PLAIN}"
    echo -e "${BLUE}╚═════════════════════════════════════════════════╝${PLAIN}"
    echo ""
    show_status
    echo -e "${GREEN}1.${PLAIN} 安装/启用 BBR ${YELLOW}(推荐先选此项)${PLAIN}"
    echo -e "${GREEN}2.${PLAIN} 升级内核（Ubuntu/Debian）"
    echo -e "${GREEN}3.${PLAIN} 升级内核（CentOS）"
    echo -e "${GREEN}4.${PLAIN} 清理旧内核 ${YELLOW}(释放/boot空间)${PLAIN}"
    echo -e "${GREEN}5.${PLAIN} 查看状态"
    echo " -------------"
    echo -e "${GREEN}0.${PLAIN} 退出"
    echo ""
    read -p "请选择操作 [0-5]: " choice
    
    case $choice in
        1)
            if check_kernel_native_bbr; then
                enable_bbr
            else
                echo -e "${YELLOW}当前内核不支持BBR，请先升级内核${PLAIN}"
                echo -e "${BLUE}提示：Ubuntu/Debian选2，CentOS选3${PLAIN}"
            fi
            ;;
        2)
            if [[ "$OS" =~ debian|ubuntu ]]; then
                check_boot_space
                upgrade_kernel_debian
                read -p "是否现在重启? [y/N]: " reboot_now
                [[ "$reboot_now" =~ ^[Yy]$ ]] && reboot
            else
                echo -e "${RED}此选项仅适用于Ubuntu/Debian${PLAIN}"
            fi
            ;;
        3)
            if [[ "$OS" =~ centos|rhel ]]; then
                check_boot_space
                upgrade_kernel_centos
                read -p "是否现在重启? [y/N]: " reboot_now
                [[ "$reboot_now" =~ ^[Yy]$ ]] && reboot
            else
                echo -e "${RED}此选项仅适用于CentOS${PLAIN}"
            fi
            ;;
        4)
            remove_old_kernels
            ;;
        5)
            show_status
            ;;
        0)
            echo -e "${GREEN}感谢使用！${PLAIN}"
            exit 0
            ;;
        *)
            echo -e "${RED}无效选择，请输入0-5${PLAIN}"
            ;;
    esac
    
    echo ""
    read -p "按回车键继续..." 
    show_menu
}

# 初始化检查
echo -e "${BLUE}╔═════════════════════════════════════════════════╗${PLAIN}"
echo -e "${BLUE}║            执行预检查...                        ║${PLAIN}"
echo -e "${BLUE}╚═════════════════════════════════════════════════╝${PLAIN}"
echo ""

# 执行所有预检查
check_dependencies
check_network
check_virt
fixCentOSRepo

echo ""
echo -e "${GREEN}预检查完成！${PLAIN}"
sleep 1

# 脚本入口
show_menu
