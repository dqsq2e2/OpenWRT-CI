#!/bin/bash
#
# 修复 QuickStart 首页温度显示（支持 MT7986A）
# 参考 wrt_release-main 的在线拉取方法
#

set -e

echo ">>> 执行 QuickStart 温度修复..."

# GitHub Gist URL（修复后的文件）
GIST_URL="https://gist.githubusercontent.com/puteulanus/1c180fae6bccd25e57eb6d30b7aa28aa/raw/istore_backend.lua"

# 查找目标文件（在 feeds 和 package 中搜索）
TARGET_LUA=$(find feeds package -name "istore_backend.lua" -type f 2>/dev/null | head -n 1)

if [ -z "$TARGET_LUA" ]; then
    echo "⚠ 警告: 未在源码中找到 istore_backend.lua，跳过修复"
    echo ""
    echo "可能的原因："
    echo "  1. QuickStart 未安装（检查 CONFIG_PACKAGE_luci-app-quickstart=y）"
    echo "  2. NAS feeds 未正确安装"
    echo "  3. feeds 路径结构变化"
    echo ""
    echo "调试命令："
    echo "  find feeds -name 'istore_backend.lua' -type f"
    echo "  find package/feeds -name 'istore_backend.lua' -type f"
    echo ""
    exit 0
fi

echo "✓ 定位到目标文件: $TARGET_LUA"

# 备份原文件
cp "$TARGET_LUA" "${TARGET_LUA}.bak"

# 尝试从 GitHub Gist 下载修复文件
echo "  正在从 GitHub Gist 下载修复文件..."
if curl -fsSL -o "${TARGET_LUA}.new" "$GIST_URL" 2>/dev/null; then
    mv "${TARGET_LUA}.new" "$TARGET_LUA"
    echo "✅ QuickStart 温度修复成功（已从 GitHub Gist 下载）"
    echo "  - 支持 MT7986A 等 MediaTek 平台"
    echo "  - 自动读取 /sys/class/thermal/thermal_zone0/temp"
else
    echo "⚠ 警告：无法从 GitHub Gist 下载修复文件（网络问题）"
    echo "  跳过 QuickStart 修复，使用原始文件继续编译"
    rm -f "${TARGET_LUA}.new"
fi
