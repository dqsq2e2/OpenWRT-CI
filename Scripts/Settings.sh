#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

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

#配置文件修改
echo "CONFIG_PACKAGE_luci=y" >> ./.config
echo "CONFIG_LUCI_LANG_zh_Hans=y" >> ./.config
echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y" >> ./.config
echo "CONFIG_PACKAGE_luci-app-$WRT_THEME-config=y" >> ./.config

#引入私有扩展配置
if [ -f "$GITHUB_WORKSPACE/Config/PRIVATE.txt" ]; then
	echo "Applying private configurations from PRIVATE.txt..."
	cat $GITHUB_WORKSPACE/Config/PRIVATE.txt >> ./.config
fi

#配置 opkg 系统软件源（参考 wrt_release-main 方法）
echo "配置 opkg 系统软件源..."

DEFAULT_SETTINGS_DIR="./package/emortal/default-settings"
DISTFEEDS_CONF="$DEFAULT_SETTINGS_DIR/files/99-distfeeds.conf"

if [ -d "$DEFAULT_SETTINGS_DIR" ]; then
	# 创建 99-distfeeds.conf 文件
	cat > "$DISTFEEDS_CONF" << 'EOF'
src/gz immortalwrt_core https://downloads.immortalwrt.org/releases/24.10-SNAPSHOT/targets/mediatek/filogic/packages
src/gz immortalwrt_base https://downloads.immortalwrt.org/releases/24.10-SNAPSHOT/packages/aarch64_cortex-a53/base
src/gz immortalwrt_luci https://downloads.immortalwrt.org/releases/24.10-SNAPSHOT/packages/aarch64_cortex-a53/luci
src/gz immortalwrt_packages https://downloads.immortalwrt.org/releases/24.10-SNAPSHOT/packages/aarch64_cortex-a53/packages
src/gz immortalwrt_routing https://downloads.immortalwrt.org/releases/24.10-SNAPSHOT/packages/aarch64_cortex-a53/routing
src/gz immortalwrt_telephony https://downloads.immortalwrt.org/releases/24.10-SNAPSHOT/packages/aarch64_cortex-a53/telephony
EOF

	# 修改 Makefile，添加安装 99-distfeeds.conf 的指令
	if ! grep -q "99-distfeeds.conf" "$DEFAULT_SETTINGS_DIR/Makefile"; then
		sed -i "/define Package\/default-settings\/install/a\\
\\t\$(INSTALL_DIR) \$(1)/etc\\n\\
\\t\$(INSTALL_DATA) ./files/99-distfeeds.conf \$(1)/etc/99-distfeeds.conf\\n" "$DEFAULT_SETTINGS_DIR/Makefile"
		echo "  ✓ 已修改 Makefile，添加 99-distfeeds.conf 安装指令"
	fi

	# 修改 99-default-settings，在启动时移动文件并取消签名检查
	DEFAULT_SETTINGS_FILE="$DEFAULT_SETTINGS_DIR/files/99-default-settings"
	if [ -f "$DEFAULT_SETTINGS_FILE" ]; then
		# 在 exit 0 之前插入配置命令
		if ! grep -q "99-distfeeds.conf" "$DEFAULT_SETTINGS_FILE"; then
			sed -i "/exit 0/i\\
[ -f '/etc/99-distfeeds.conf' ] && mv '/etc/99-distfeeds.conf' '/etc/opkg/distfeeds.conf'\\n\\
sed -ri '/check_signature/s@^[^#]@#&@' /etc/opkg.conf\\n" "$DEFAULT_SETTINGS_FILE"
			echo "  ✓ 已修改 99-default-settings，添加软件源配置和取消签名检查"
		fi
	fi

	echo "✅ opkg 系统软件源配置完成（ImmortalWrt 24.10-SNAPSHOT）"
	echo "  - 软件源文件: $DISTFEEDS_CONF"
	echo "  - 首次启动时自动移动到 /etc/opkg/distfeeds.conf"
	echo "  - 自动取消 opkg 签名检查"
else
	echo "⚠️  警告: 未找到 default-settings 目录，跳过软件源配置"
	echo "  路径: $DEFAULT_SETTINGS_DIR"
fi

#手动调整的插件
if [ -n "$WRT_PACKAGE" ]; then
	echo -e "$WRT_PACKAGE" >> ./.config
fi

#无WIFI配置标志
if [[ "${WRT_CONFIG,,}" == *"wifi"* && "${WRT_CONFIG,,}" == *"no"* ]]; then
	echo "WRT_WIFI=wifi-no" >> $GITHUB_ENV
fi

#高通平台调整
DTS_PATH="./target/linux/qualcommax/dts/"
if [[ "${WRT_TARGET^^}" == *"QUALCOMMAX"* ]]; then
	#取消nss相关feed
	echo "CONFIG_FEED_nss_packages=n" >> ./.config
	echo "CONFIG_FEED_sqm_scripts_nss=n" >> ./.config
	#设置NSS版本
	echo "CONFIG_NSS_FIRMWARE_VERSION_12_5=y" >> ./.config
	#其他调整
	echo "CONFIG_PACKAGE_kmod-usb-serial-qualcomm=y" >> ./.config

	#无WIFI配置调整Q6大小
	if [[ "${WRT_CONFIG,,}" == *"wifi"* && "${WRT_CONFIG,,}" == *"no"* ]]; then
		find $DTS_PATH -type f ! -iname '*nowifi*' -exec sed -i 's/ipq\(6018\|8074\).dtsi/ipq\1-nowifi.dtsi/g' {} +
		echo "qualcommax set up nowifi successfully!"
	fi
fi
