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

# 方案：直接替换三个 KernelPackage 定义

# 1. 提取文件开头到 kmod-iptables 之前的内容
sed -n '1,/^define KernelPackage\/iptables$/p' "${NETFILTER_MK}.bak" | head -n -1 > "$NETFILTER_MK"

# 2. 写入修复后的 kmod-iptables
cat >> "$NETFILTER_MK" << 'EOF'
define KernelPackage/iptables
  SUBMENU:=$(NF_MENU)
  TITLE:=Iptables legacy
  DEPENDS:=@!LINUX_6_12 +kmod-nf-ipt
  HIDDEN:=1
  KCONFIG:= \
	CONFIG_IP_NF_IPTABLES_LEGACY \
	CONFIG_NETFILTER_XTABLES \
	CONFIG_NETFILTER_XTABLES_LEGACY=y \
	CONFIG_IP6_NF_IPTABLES_LEGACY \
	CONFIG_BRIDGE_NF_EBTABLES_LEGACY
  FILES:=
  AUTOLOAD:=
endef

$(eval $(call KernelPackage,iptables))

EOF

# 3. 写入修复后的 kmod-nf-ipt
cat >> "$NETFILTER_MK" << 'EOF'
define KernelPackage/nf-ipt
  SUBMENU:=$(NF_MENU)
  TITLE:=Iptables core
  KCONFIG:=$(KCONFIG_NF_IPT)
  DEPENDS:=+!LINUX_6_12:kmod-iptables
  FILES:= \
    $(LINUX_DIR)/net/netfilter/x_tables.ko \
    $(wildcard $(LINUX_DIR)/net/ipv4/netfilter/ip_tables.ko)
  AUTOLOAD:=$(call AutoProbe,x_tables)
endef

$(eval $(call KernelPackage,nf-ipt))

EOF

# 4. 写入修复后的 kmod-nf-ipt6
cat >> "$NETFILTER_MK" << 'EOF'
define KernelPackage/nf-ipt6
  SUBMENU:=$(NF_MENU)
  TITLE:=Ip6tables core
  KCONFIG:=$(KCONFIG_NF_IPT6)
  FILES:= \
    $(wildcard $(LINUX_DIR)/net/ipv6/netfilter/ip6_tables.ko)
  AUTOLOAD:=$(call AutoProbe,ip6_tables)
  DEPENDS:=+kmod-nf-ipt +kmod-nf-log6
endef

$(eval $(call KernelPackage,nf-ipt6))

EOF

# 5. 添加文件剩余部分（从 kmod-ipt-core 开始）
sed -n '/^define KernelPackage\/ipt-core$/,$p' "${NETFILTER_MK}.bak" >> "$NETFILTER_MK"

echo ""
echo "✅ Netfilter 模块冲突修复完成"
echo ""
echo "修复内容："
echo "  1. kmod-iptables 改为空包（不安装任何文件）"
echo "  2. kmod-iptables 依赖 kmod-nf-ipt"
echo "  3. kmod-nf-ipt 提供 ip_tables.ko 和 x_tables.ko"
echo "  4. 避免了 opkg 的文件冲突错误"
echo ""
