#!/bin/bash
#
# 修复 OpenWrt opkg + Docker 环境下的 netfilter 模块冲突
# 问题：kmod-iptables 和 kmod-nf-ipt 都提供 ip_tables.ko 和 x_tables.ko
# 解决方案：让 kmod-iptables 成为空包，所有文件由 kmod-nf-ipt 提供
#

set -e

NETFILTER_MK="package/kernel/linux/modules/netfilter.mk"

if [ ! -f "$NETFILTER_MK" ]; then
    echo "❌ 错误：未找到 $NETFILTER_MK"
    exit 1
fi

echo ">>> 正在修复 netfilter 模块冲突..."

# 备份原文件
if [ ! -f "${NETFILTER_MK}.bak" ]; then
    cp "$NETFILTER_MK" "${NETFILTER_MK}.bak"
    echo "  ✓ 已备份原文件"
fi

# 方案：将 kmod-iptables 改为空包（只保留依赖关系），所有文件由 kmod-nf-ipt 提供
# 这样可以避免文件冲突，同时保持依赖链完整

# 1. 修改 kmod-iptables：清空 FILES 和 AUTOLOAD，添加对 kmod-nf-ipt 的依赖
sed -i '/^define KernelPackage\/iptables$/,/^endef$/{
    s|^  FILES:=.*$|  FILES:=|
    s|^  AUTOLOAD:=.*$|  AUTOLOAD:=|
    /^  DEPENDS:=/d
    /^  HIDDEN:=/d
    /^  TITLE:=/a\  DEPENDS:=@!LINUX_6_12 +kmod-nf-ipt\n  HIDDEN:=1
}' "$NETFILTER_MK"

# 2. 修复 kmod-nf-ipt 的 FILES，只使用实际存在的 x_tables.ko
# 注意：在新内核（6.18+）中，ip_tables.ko 已经不存在，只有 x_tables.ko
# 检查是否使用了 $(foreach ...) 变量（这可能导致文件列表为空）
if grep -A 10 "^define KernelPackage/nf-ipt$" "$NETFILTER_MK" | grep -q 'FILES:=.*\$(foreach'; then
    echo "  ⚠ kmod-nf-ipt 使用变量引用，替换为明确的文件路径"
    
    # 替换 FILES 行为实际的文件列表（只包含 x_tables.ko）
    # 使用 wildcard 来兼容不同内核版本（有些版本可能有 ip_tables.ko）
    sed -i '/^define KernelPackage\/nf-ipt$/,/^endef$/{
        s|^  FILES:=.*$|  FILES:= \\\n    \$(LINUX_DIR)/net/netfilter/x_tables.ko \\\n    \$(wildcard \$(LINUX_DIR)/net/ipv4/netfilter/ip_tables.ko)|
    }' "$NETFILTER_MK"
    
    # 同时修复 AUTOLOAD（只加载 x_tables，ip_tables 如果存在会自动加载）
    sed -i '/^define KernelPackage\/nf-ipt$/,/^endef$/{
        s|^  AUTOLOAD:=.*$|  AUTOLOAD:=\$(call AutoProbe,x_tables)|
    }' "$NETFILTER_MK"
    
    echo "  ✓ 已修复 kmod-nf-ipt 的 FILES 和 AUTOLOAD"
    echo "  ℹ 注意：新内核中只有 x_tables.ko，ip_tables.ko 已不存在"
else
    echo "  ℹ kmod-nf-ipt 的 FILES 已经是明确路径"
fi

# 3. 修复 kmod-nf-ipt6（IPv6 版本）的 FILES
# 同样的问题：ip6_tables.ko 在新内核中也不存在
if grep -A 10 "^define KernelPackage/nf-ipt6$" "$NETFILTER_MK" | grep -q 'FILES:=.*\$(foreach'; then
    echo "  ⚠ kmod-nf-ipt6 使用变量引用，替换为明确的文件路径"
    
    # 替换 FILES 行（使用 wildcard 兼容不同内核版本）
    sed -i '/^define KernelPackage\/nf-ipt6$/,/^endef$/{
        s|^  FILES:=.*$|  FILES:= \\\n    \$(wildcard \$(LINUX_DIR)/net/ipv6/netfilter/ip6_tables.ko)|
    }' "$NETFILTER_MK"
    
    # 修复 AUTOLOAD
    sed -i '/^define KernelPackage\/nf-ipt6$/,/^endef$/{
        s|^  AUTOLOAD:=.*$|  AUTOLOAD:=\$(call AutoProbe,ip6_tables)|
    }' "$NETFILTER_MK"
    
    echo "  ✓ 已修复 kmod-nf-ipt6 的 FILES 和 AUTOLOAD"
    echo "  ℹ 注意：新内核中 ip6_tables.ko 可能不存在"
else
    echo "  ℹ kmod-nf-ipt6 的 FILES 已经是明确路径"
fi

echo ""
echo "✅ Netfilter 模块冲突修复完成"
echo ""
echo "修复内容："
echo "  1. kmod-iptables 改为空包（不安装任何文件）"
echo "  2. kmod-iptables 依赖 kmod-nf-ipt"
echo "  3. kmod-nf-ipt 提供 ip_tables.ko 和 x_tables.ko"
echo "  4. 避免了 opkg 的文件冲突错误"
echo ""
