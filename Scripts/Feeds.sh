#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

# 参考 Actions-OpenWrt-MT798X-main 的 feeds 安装方法
# QuickStart 在 nas-packages-luci 中，不在 istore 中！

echo "=========================================="
echo "添加 Feeds 源"
echo "=========================================="

# 备份原始 feeds
if [ ! -f "feeds.conf.default.bak" ]; then
    cp feeds.conf.default feeds.conf.default.bak
fi

# 添加 NAS feeds（QuickStart 在这里）
if ! grep -q "linkease/nas-packages" feeds.conf.default; then
    echo "" >> feeds.conf.default
    echo 'src-git nas https://github.com/linkease/nas-packages.git;master' >> feeds.conf.default
    echo 'src-git nas_luci https://github.com/linkease/nas-packages-luci.git;main' >> feeds.conf.default
    echo "✅ 已添加 NAS feeds (包含 QuickStart)"
else
    echo "⏭️  NAS feeds 已存在"
fi

# 添加 iStore feeds
if ! grep -q "linkease/istore" feeds.conf.default; then
    echo 'src-git istore https://github.com/linkease/istore;main' >> feeds.conf.default
    echo "✅ 已添加 iStore feeds"
else
    echo "⏭️  iStore feeds 已存在"
fi

echo "=========================================="
echo "feeds.conf.default 内容:"
echo "=========================================="
cat feeds.conf.default
echo "=========================================="

echo ""
echo "✅ Feeds 源配置完成"
echo "  - NAS feeds: 包含 QuickStart、iStoreOS 等"
echo "  - iStore feeds: 包含 iStore 商店"
