#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

# 添加 iStore feeds 源（官方推荐方式）
echo "=========================================="
echo "添加 iStore feeds 源"
echo "=========================================="

cd "$GITHUB_WORKSPACE/wrt/"

if [ ! -f "feeds.conf.default" ]; then
    echo "❌ 错误: feeds.conf.default 文件不存在"
    exit 1
fi

# 添加 iStore feeds（官方推荐）
if ! grep -q "linkease/istore" feeds.conf.default; then
    echo "" >> feeds.conf.default
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
