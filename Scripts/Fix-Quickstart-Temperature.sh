#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY
# 修复 QuickStart 温度显示问题（MT7986A 等平台）

echo " "
echo ">>> 正在修复 QuickStart 温度显示..."

# QuickStart 可能在多个位置，按优先级查找
QUICKSTART_PATHS=(
	"../feeds/nas_luci/luci/luci-app-quickstart/luasrc/controller/istore_backend.lua"
	"../feeds/nas_luci/applications/luci-app-quickstart/luasrc/controller/istore_backend.lua"
	"../package/feeds/nas_luci/luci-app-quickstart/luasrc/controller/istore_backend.lua"
)

QUICKSTART_FILE=""
for path in "${QUICKSTART_PATHS[@]}"; do
	if [ -f "$path" ]; then
		QUICKSTART_FILE="$path"
		echo "  ✓ 找到 QuickStart 文件: $path"
		break
	fi
done

if [ -z "$QUICKSTART_FILE" ]; then
	echo "⚠ 警告: 未在源码中找到 istore_backend.lua，跳过修复"
	echo "可能的原因："
	echo "  1. QuickStart 未安装（检查 CONFIG_PACKAGE_luci-app-quickstart=y）"
	echo "  2. NAS feeds 未正确安装"
	echo "  3. feeds 路径结构变化"
	echo ""
	echo "调试命令："
	echo "  find ../feeds -name 'istore_backend.lua' -type f"
	echo "  find ../package/feeds -name 'istore_backend.lua' -type f"
	exit 0
fi

# 检查是否已经修复
if grep -q "/sys/class/thermal/thermal_zone0/temp" "$QUICKSTART_FILE"; then
	echo "✓ QuickStart 温度显示已修复"
	exit 0
fi

# 备份原始文件
if [ ! -f "${QUICKSTART_FILE}.bak" ]; then
	cp "$QUICKSTART_FILE" "${QUICKSTART_FILE}.bak"
fi

# 本地修复：将温度读取路径改为通用路径
# 查找所有可能的温度路径并替换
sed -i 's|/sys/devices/virtual/thermal/thermal_zone0/temp|/sys/class/thermal/thermal_zone0/temp|g' "$QUICKSTART_FILE"
sed -i 's|/sys/devices/platform/soc/[^/]*/thermal_zone0/temp|/sys/class/thermal/thermal_zone0/temp|g' "$QUICKSTART_FILE"

echo "✅ QuickStart 温度显示修复完成"
echo "  - 支持 MT7986A 等 MediaTek 平台"
echo "  - 自动读取 /sys/class/thermal/thermal_zone0/temp"
