#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY
# iStore Edition - Customized for ImmortalWrt SNAPSHOT

#安装和更新软件包
UPDATE_PACKAGE() {
	local PKG_NAME=$1
	local PKG_REPO=$2
	local PKG_BRANCH=$3
	local PKG_SPECIAL=$4
	local PKG_LIST=("$PKG_NAME" $5)  # 第5个参数为自定义名称列表
	local REPO_NAME=${PKG_REPO#*/}

	echo " "

	# 删除本地可能存在的不同名称的软件包
	for NAME in "${PKG_LIST[@]}"; do
		# 查找匹配的目录
		echo "Search directory: $NAME"
		local FOUND_DIRS=$(find ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "*$NAME*" 2>/dev/null)

		# 删除找到的目录
		if [ -n "$FOUND_DIRS" ]; then
			while read -r DIR; do
				rm -rf "$DIR"
				echo "Delete directory: $DIR"
			done <<< "$FOUND_DIRS"
		else
			echo "Not found directory: $NAME"
		fi
	done

	# 克隆 GitHub 仓库
	git clone --depth=1 --single-branch --branch $PKG_BRANCH "https://github.com/$PKG_REPO.git"

	# 处理克隆的仓库
	if [[ "$PKG_SPECIAL" == "pkg" ]]; then
		find ./$REPO_NAME/*/ -maxdepth 3 -type d -iname "*$PKG_NAME*" -prune -exec cp -rf {} ./ \;
		rm -rf ./$REPO_NAME/
	elif [[ "$PKG_SPECIAL" == "name" ]]; then
		mv -f $REPO_NAME $PKG_NAME
	fi
}

echo "=========================================="
echo "开始安装 iStore 生态插件"
echo "=========================================="

# ========================================
# 移除有问题的包
# ========================================
echo ">>> 移除 xtables-addons（编译失败）..."

# 当前在 wrt/package/ 目录
# feeds 在 wrt/feeds/ 目录
if [ -d "../feeds/packages/net/xtables-addons" ]; then
	rm -rf ../feeds/packages/net/xtables-addons
	echo "✅ xtables-addons 已从 feeds 移除"
fi

# 同时检查 package/feeds 目录
if [ -d "./feeds/packages/xtables-addons" ]; then
	rm -rf ./feeds/packages/xtables-addons
	echo "✅ xtables-addons 已从 package/feeds 移除"
fi

# 返回上级目录执行 feeds uninstall
cd ..
./scripts/feeds uninstall xtables-addons 2>/dev/null || true
echo "✅ xtables-addons 已从 feeds 索引移除"

# ========================================
# 移除 mt76 无线驱动（NoWiFi 配置）
# ========================================
echo ">>> 移除 mt76 无线驱动（NoWiFi 配置）..."

# 删除 mt76 源码目录
if [ -d "package/kernel/mt76" ]; then
	rm -rf package/kernel/mt76
	echo "✅ mt76 源码已移除"
fi

# 从 feeds 中移除
./scripts/feeds uninstall kmod-mt76-core 2>/dev/null || true
./scripts/feeds uninstall kmod-mt76-connac 2>/dev/null || true
./scripts/feeds uninstall kmod-mt7915e 2>/dev/null || true
./scripts/feeds uninstall kmod-mt7916-firmware 2>/dev/null || true
./scripts/feeds uninstall kmod-mt7986-firmware 2>/dev/null || true
./scripts/feeds uninstall mt7986-wo-firmware 2>/dev/null || true

echo "✅ mt76 无线驱动已彻底移除"

cd package

# ========================================
# iStore 生态系统
# ========================================
echo ">>> 添加 iStore feeds..."

# 添加 NAS feeds
if ! grep -q "nas-packages" ../feeds.conf.default 2>/dev/null; then
	echo 'src-git nas https://github.com/linkease/nas-packages.git;master' >> ../feeds.conf.default
	echo 'src-git nas_luci https://github.com/linkease/nas-packages-luci.git;main' >> ../feeds.conf.default
fi

# 添加 iStore feeds
if ! grep -q "istore" ../feeds.conf.default 2>/dev/null; then
	echo 'src-git istore https://github.com/linkease/istore;main' >> ../feeds.conf.default
fi

echo "✅ iStore feeds 添加完成"

# 重新更新和安装 feeds（确保 iStore 被安装）
echo ">>> 重新更新和安装 feeds..."
cd ..
./scripts/feeds update -a
./scripts/feeds install -a
cd package
echo "✅ Feeds 重新安装完成"

# ========================================
# 主题
# ========================================
echo ">>> 安装主题..."
UPDATE_PACKAGE "argon" "sbwml/luci-theme-argon" "openwrt-25.12"
UPDATE_PACKAGE "aurora" "eamonxg/luci-theme-aurora" "master"
UPDATE_PACKAGE "aurora-config" "eamonxg/luci-app-aurora-config" "master"

# ========================================
# OpenClash
# ========================================
echo ">>> 安装 OpenClash..."
UPDATE_PACKAGE "openclash" "vernesong/OpenClash" "dev" "pkg"

# ========================================
# 磁盘管理
# ========================================
echo ">>> 安装磁盘管理..."
UPDATE_PACKAGE "diskman" "lisaac/luci-app-diskman" "master"

# ========================================
# 定时任务
# ========================================
echo ">>> 安装定时任务..."
UPDATE_PACKAGE "taskplan" "sirpdboy/luci-app-taskplan" "master"

# ========================================
# 修复 owrt 分支的 kmod-iptables 冲突
# ========================================
echo ">>> 修复 kmod-iptables 冲突（owrt 分支特有问题）..."

cd ..

# 在 .config 生成后，强制禁用 kmod-iptables
# 这个操作需要在 make defconfig 之后执行
# 所以我们创建一个标记文件，让 Settings 脚本处理
touch .kmod_iptables_fix_needed

echo "✅ kmod-iptables 冲突修复标记已创建"

cd package

echo "=========================================="
echo "✅ iStore 插件安装完成"
echo "=========================================="
