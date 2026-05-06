#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY
# 修复 OpenWrt opkg + Docker 环境下的 netfilter 模块冲突
# 问题：kmod-iptables 和 kmod-nf-ipt 都提供 ip_tables.ko 和 x_tables.ko
# 解决方案：让 kmod-nf-ipt 排除这些文件，由 kmod-iptables 提供
# 参考：https://github.com/openwrt/openwrt/issues/22992

echo " "
echo ">>> 正在修复 netfilter 模块冲突..."

NETFILTER_MK="kernel/linux/modules/netfilter.mk"

if [ ! -f "$NETFILTER_MK" ]; then
	echo "✗ 错误：未找到 $NETFILTER_MK"
	exit 0
fi

# 检查是否已经修复
if grep -q "filter-out ipv4/netfilter/ip_tables netfilter/x_tables" "$NETFILTER_MK"; then
	echo "✓ netfilter 模块冲突已修复"
	exit 0
fi

# 备份原文件
if [ ! -f "${NETFILTER_MK}.bak" ]; then
	cp "$NETFILTER_MK" "${NETFILTER_MK}.bak"
	echo "  ✓ 已备份原文件"
fi

echo "  → 修改 kmod-nf-ipt 定义，排除冲突文件..."

# 使用 sed 修改 kmod-nf-ipt 的 FILES 定义
# 将 $(NF_IPT-m) 改为 $(filter-out ipv4/netfilter/ip_tables netfilter/x_tables,$(NF_IPT-m))
sed -i '/^define KernelPackage\/nf-ipt$/,/^endef$/{
	s|FILES:=\$(foreach mod,\$(NF_IPT-m),\$(LINUX_DIR)/net/\$(mod)\.ko)|FILES:=$(foreach mod,$(filter-out ipv4/netfilter/ip_tables netfilter/x_tables,$(NF_IPT-m)),$(LINUX_DIR)/net/$(mod).ko)|
	s|AUTOLOAD:=\$(call AutoProbe,\$(notdir \$(NF_IPT-m)))|AUTOLOAD:=$(call AutoProbe,$(notdir $(filter-out ipv4/netfilter/ip_tables netfilter/x_tables,$(NF_IPT-m))))|
}' "$NETFILTER_MK"

echo "  ✓ 已修改 kmod-nf-ipt 的 FILES 和 AUTOLOAD"

# 同样修复 kmod-nf-ipt6（如果需要）
# 注意：ip6_tables.ko 不与 kmod-iptables 冲突，所以不需要排除
# 只有 ip_tables.ko 和 x_tables.ko 才与 kmod-iptables 冲突
echo "  ℹ kmod-nf-ipt6 不需要修改（ip6_tables.ko 不冲突）"

echo ""
echo "✅ Netfilter 模块冲突修复完成"
echo ""
echo "修复内容："
echo "  1. kmod-nf-ipt 排除 ip_tables.ko 和 x_tables.ko"
echo "  2. 这些文件由 kmod-iptables 提供"
echo "  3. kmod-nf-ipt6 保持不变（ip6_tables.ko 不冲突）"
echo "  4. 避免了 opkg 的文件冲突错误"
echo "  5. 参考：https://github.com/openwrt/openwrt/issues/22992"
echo ""

