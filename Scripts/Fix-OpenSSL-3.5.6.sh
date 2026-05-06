#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY
# 修复 OpenSSL 3.5.6 编译错误

echo " "
echo ">>> 正在修复 OpenSSL 3.5.6 编译错误..."

OPENSSL_MAKEFILE="../feeds/packages/libs/openssl/Makefile"

# 调试：显示当前目录和目标文件
echo "  → 当前目录: $(pwd)"
echo "  → 查找文件: $OPENSSL_MAKEFILE"

if [ ! -f "$OPENSSL_MAKEFILE" ]; then
	echo "✗ 未找到 OpenSSL Makefile: $OPENSSL_MAKEFILE"
	echo "  ℹ 可能 feeds 尚未更新，跳过修复"
	echo ""
	echo "调试信息："
	echo "  - 检查 openssl 目录是否存在: $([ -d '../feeds/packages/libs/openssl' ] && echo '存在' || echo '不存在')"
	if [ -d '../feeds/packages/libs/openssl' ]; then
		echo "  - openssl 目录内容:"
		ls -la ../feeds/packages/libs/openssl/ 2>/dev/null || echo "    无法列出目录"
	fi
	exit 0
fi

# 检查是否是 OpenSSL 3.5.6
OPENSSL_VERSION=$(grep -Po 'PKG_VERSION:=\K.*' "$OPENSSL_MAKEFILE" 2>/dev/null)
if [[ "$OPENSSL_VERSION" != "3.5.6" ]]; then
	echo "✓ OpenSSL 版本为 $OPENSSL_VERSION，不需要修复"
	exit 0
fi

# 备份原始文件
if [ ! -f "${OPENSSL_MAKEFILE}.bak" ]; then
	cp "$OPENSSL_MAKEFILE" "${OPENSSL_MAKEFILE}.bak"
fi

# 在 OPENSSL_OPTIONS 中添加 no-x942kdf 选项
if grep -q "no-x942kdf" "$OPENSSL_MAKEFILE"; then
	echo "✓ OpenSSL Makefile 已包含 no-x942kdf 选项"
else
	# 在 OPENSSL_OPTIONS 定义后添加 no-x942kdf
	sed -i '/^OPENSSL_OPTIONS:=/a\  no-x942kdf \\' "$OPENSSL_MAKEFILE"
	echo "✅ 已添加 no-x942kdf 选项到 OpenSSL 配置"
fi

echo "✅ OpenSSL 3.5.6 编译错误修复完成"
echo "  - 已禁用 X9.42 KDF 模块（该模块在 3.5.6 中有 bug）"
