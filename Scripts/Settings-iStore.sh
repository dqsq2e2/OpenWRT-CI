#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY
# iStore Edition Settings

echo "=========================================="
echo "执行 iStore 自定义配置"
echo "=========================================="

# ---------------------------------------------------------
# 1. 基础配置（继承原有逻辑）
# ---------------------------------------------------------
#移除luci-app-attendedsysupgrade
sed -i "/attendedsysupgrade/d" $(find ./feeds/luci/collections/ -type f -name "Makefile")
#修改默认主题
sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g" $(find ./feeds/luci/collections/ -type f -name "Makefile")
#修改immortalwrt.lan关联IP
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $(find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js")
#添加编译日期标识
sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ $WRT_MARK-$WRT_DATE')/g" $(find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js")

WIFI_SH=$(find ./target/linux/{mediatek/filogic,qualcommax}/base-files/etc/uci-defaults/ -type f -name "*set-wireless.sh" 2>/dev/null)
WIFI_UC="./package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc"
if [ -f "$WIFI_SH" ]; then
	#修改WIFI名称
	sed -i "s/BASE_SSID='.*'/BASE_SSID='$WRT_SSID'/g" $WIFI_SH
	#修改WIFI密码
	sed -i "s/BASE_WORD='.*'/BASE_WORD='$WRT_WORD'/g" $WIFI_SH
elif [ -f "$WIFI_UC" ]; then
	#修改WIFI名称
	sed -i "s/ssid='.*'/ssid='$WRT_SSID'/g" $WIFI_UC
	#修改WIFI密码
	sed -i "s/key='.*'/key='$WRT_WORD'/g" $WIFI_UC
	#修改WIFI地区
	sed -i "s/country='.*'/country='CN'/g" $WIFI_UC
	#修改WIFI加密
	sed -i "s/encryption='.*'/encryption='psk2+ccmp'/g" $WIFI_UC
fi

CFG_FILE="./package/base-files/files/bin/config_generate"
#修改默认IP地址
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $CFG_FILE
#修改默认主机名
sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" $CFG_FILE

# ---------------------------------------------------------
# 2. iStore 特定配置
# ---------------------------------------------------------
echo ">>> 配置 iStore 相关设置..."

#配置文件修改
echo "CONFIG_PACKAGE_luci=y" >> ./.config
echo "CONFIG_LUCI_LANG_zh_Hans=y" >> ./.config
echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y" >> ./.config
echo "CONFIG_PACKAGE_luci-app-$WRT_THEME-config=y" >> ./.config

# 强制使用 opkg 包管理器
echo "CONFIG_USE_APK=n" >> ./.config
echo "CONFIG_PACKAGE_opkg=y" >> ./.config

#手动调整的插件
if [ -n "$WRT_PACKAGE" ]; then
	echo -e "$WRT_PACKAGE" >> ./.config
fi

#无WIFI配置标志
if [[ "${WRT_CONFIG,,}" == *"wifi"* && "${WRT_CONFIG,,}" == *"no"* ]]; then
	echo "WRT_WIFI=wifi-no" >> $GITHUB_ENV
fi

# ---------------------------------------------------------
# 3. QuickStart 首页温度显示修复
# ---------------------------------------------------------
echo ">>> 执行 QuickStart 温度显示修复..."

# 获取 GitHub Workspace 根目录
if [ -n "$GITHUB_WORKSPACE" ]; then
    REPO_ROOT="$GITHUB_WORKSPACE"
else
    REPO_ROOT=$(dirname "$(readlink -f "$0")")/../
fi

CUSTOM_LUA="$REPO_ROOT/Files/istore/istore_backend.lua"

# 查找目标文件 (feeds 和 package 都找)
# 注意：此时 iStore feeds 应该已经在 Packages-iStore.sh 中重新安装过了
TARGET_LUA=$(find feeds package -name "istore_backend.lua" -type f 2>/dev/null | head -n 1)

if [ -n "$TARGET_LUA" ]; then
    echo "✅ 定位到目标文件: $TARGET_LUA"
    if [ -f "$CUSTOM_LUA" ]; then
        echo "正在覆盖自定义文件..."
        cp -f "$CUSTOM_LUA" "$TARGET_LUA"
        if cmp -s "$CUSTOM_LUA" "$TARGET_LUA"; then
            echo "✅ QuickStart 温度显示修复成功"
        else
            echo "❌ 错误: 文件复制校验失败"
        fi
    else
        echo "⚠️ 警告: 仓库中未找到自定义文件 $CUSTOM_LUA"
    fi
else
    echo "❌ 错误: 未在源码中找到 istore_backend.lua"
    echo "   可能原因："
    echo "   1. iStore feeds 未正确安装"
    echo "   2. Packages-iStore.sh 中的 feeds 重新安装失败"
    echo "   请检查 Packages-iStore.sh 的执行日志"
fi

# ---------------------------------------------------------
# 4. 升级 Golang（适配 owrt）
# ---------------------------------------------------------
echo ">>> 升级 Golang 到最新版本..."
if [ -d "feeds/packages/lang/golang" ]; then
	rm -rf feeds/packages/lang/golang
	git clone https://github.com/sbwml/packages_lang_golang -b 26.x feeds/packages/lang/golang
	echo "✅ Golang 已升级到 26.x"
fi

# ---------------------------------------------------------
# 5. 再次确认移除 xtables-addons 和 mt76
# ---------------------------------------------------------
echo ">>> 再次确认移除 xtables-addons 和 mt76..."

# 移除 xtables-addons 源码目录
rm -rf feeds/packages/net/xtables-addons 2>/dev/null || true
rm -rf package/feeds/packages/xtables-addons 2>/dev/null || true

# 移除 xtables-addons 编译目录
rm -rf build_dir/target-*/linux-*/xtables-addons* 2>/dev/null || true

# 从配置中移除 xtables-addons
sed -i '/xtables-addons/d' .config 2>/dev/null || true
sed -i '/kmod-ipt-account/d' .config 2>/dev/null || true
sed -i '/kmod-xt-/d' .config 2>/dev/null || true

echo "✅ xtables-addons 已彻底移除"

# 移除 mt76 无线驱动（NoWiFi 配置）
echo ">>> 再次确认移除 mt76 无线驱动..."

# 删除 mt76 源码目录
rm -rf package/kernel/mt76 2>/dev/null || true

# 删除 mt76 编译目录
rm -rf build_dir/target-*/linux-*/mt76* 2>/dev/null || true

# 从配置中移除 mt76
sed -i '/CONFIG_PACKAGE_kmod-mt76/d' .config 2>/dev/null || true
sed -i '/CONFIG_PACKAGE_kmod-mt79/d' .config 2>/dev/null || true
sed -i '/CONFIG_PACKAGE_mt79.*-firmware/d' .config 2>/dev/null || true

echo "✅ mt76 无线驱动已彻底移除"

# ---------------------------------------------------------
# 6. 网络参数优化（sysctl）
# ---------------------------------------------------------
echo ">>> 配置网络优化参数..."
mkdir -p files/etc/sysctl.d/

cat > files/etc/sysctl.d/99-istore-optimize.conf << 'SYSCTL'
# ---------------------------------------------------------
# Conntrack（代理高并发必需）
# ---------------------------------------------------------
net.netfilter.nf_conntrack_max=32768
net.netfilter.nf_conntrack_tcp_timeout_established=3600
net.netfilter.nf_conntrack_udp_timeout=60
net.netfilter.nf_conntrack_udp_timeout_stream=120

# ---------------------------------------------------------
# TCP 优化
# ---------------------------------------------------------
net.core.netdev_max_backlog=2048
net.core.somaxconn=2048
net.ipv4.tcp_max_syn_backlog=2048
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_fin_timeout=30
net.ipv4.tcp_keepalive_time=600
net.ipv4.tcp_keepalive_intvl=15
net.ipv4.tcp_keepalive_probes=5
net.ipv4.tcp_max_tw_buckets=8192

# ---------------------------------------------------------
# 缓冲区（适配 256MB 路由器）
# ---------------------------------------------------------
net.core.rmem_max=4194304
net.core.wmem_max=4194304
net.ipv4.tcp_rmem=4096 131072 4194304
net.ipv4.tcp_wmem=4096 65536 4194304
net.ipv4.udp_mem=8192 12288 16384

# ---------------------------------------------------------
# 本地端口范围
# ---------------------------------------------------------
net.ipv4.ip_local_port_range=1024 65535
SYSCTL

echo "✅ 网络优化参数已写入"

# ---------------------------------------------------------
# 7. 修改默认 IP (可选)
# ---------------------------------------------------------
# 如果需要修改默认IP，取消下面的注释
# sed -i 's/192.168.1.1/192.168.30.1/g' package/base-files/files/bin/config_generate

# ---------------------------------------------------------
# 8. 修复 owrt 分支的 kmod-iptables 冲突（关键！）
# ---------------------------------------------------------
echo ">>> 修复 kmod-iptables 冲突（owrt 分支特有问题）..."

# 检查是否需要修复
if [ -f ".kmod_iptables_fix_needed" ]; then
    echo "检测到 kmod-iptables 冲突修复标记"
    
    # 强制禁用 kmod-iptables
    # 在 owrt 分支中，kmod-iptables 和 kmod-nf-ipt 提供相同的文件导致冲突
    # 解决方案：禁用 kmod-iptables，让 kmod-nf-ipt 提供这些文件
    
    echo "正在从配置中移除 kmod-iptables..."
    sed -i '/CONFIG_PACKAGE_kmod-iptables/d' .config 2>/dev/null || true
    echo '# CONFIG_PACKAGE_kmod-iptables is not set' >> .config
    
    # 确保 iptables-nft 和 nftables 保持启用
    echo "确保 iptables-nft 和 nftables 保持启用..."
    sed -i '/CONFIG_PACKAGE_iptables-nft/d' .config 2>/dev/null || true
    sed -i '/CONFIG_PACKAGE_ip6tables-nft/d' .config 2>/dev/null || true
    sed -i '/CONFIG_PACKAGE_nftables/d' .config 2>/dev/null || true
    echo 'CONFIG_PACKAGE_iptables-nft=y' >> .config
    echo 'CONFIG_PACKAGE_ip6tables-nft=y' >> .config
    echo 'CONFIG_PACKAGE_nftables=y' >> .config
    
    # 重新运行 defconfig 以解析依赖
    echo "重新解析配置依赖..."
    make defconfig
    
    # 验证修复
    if grep -q "# CONFIG_PACKAGE_kmod-iptables is not set" .config; then
        echo "✅ kmod-iptables 已成功禁用"
    else
        echo "⚠️ 警告: kmod-iptables 禁用可能未生效"
    fi
    
    # 删除标记文件
    rm -f .kmod_iptables_fix_needed
    
    echo "✅ kmod-iptables 冲突修复完成"
else
    echo "ℹ️ 未检测到 kmod-iptables 冲突修复标记，跳过"
fi

echo "=========================================="
echo "✅ iStore 配置完成"
echo "=========================================="
