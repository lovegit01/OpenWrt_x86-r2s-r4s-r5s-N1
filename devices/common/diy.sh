#!/bin/bash
#=================================================
shopt -s extglob

sed -i '$a src-git kiddin9 https://github.com/kiddin9/openwrt-packages.git;master' feeds.conf.default
sed -i "/telephony/d" feeds.conf.default

sed -i "s?targets/%S/packages?targets/%S/\$(LINUX_VERSION)?" include/feeds.mk

sed -i '/	refresh_config();/d' scripts/feeds

./scripts/feeds update -a
./scripts/feeds install -a -p allen -f
./scripts/feeds install -a

echo "$(date +"%s")" >version.date
sed -i '/$(curdir)\/compile:/c\$(curdir)/compile: package/opkg/host/compile' package/Makefile
sed -i 's/$(TARGET_DIR)) install/$(TARGET_DIR)) install --force-overwrite --force-depends/' package/Makefile
sed -i "s/DEFAULT_PACKAGES:=/DEFAULT_PACKAGES:=luci-app-advanced luci-app-firewall luci-app-gpsysupgrade luci-app-opkg luci-app-upnp luci-app-autoreboot \
luci-app-wizard luci-base luci-compat luci-lib-ipkg luci-lib-fs \
luci-app-accesscontrol luci-app-adbyby-plus luci-app-filebrowser luci-app-samba4 luci-app-sqm luci-app-syncdial luci-app-vlmcsd automount \
luci-app-wolplus luci-app-acme luci-app-alist luci-app-aliyundrive-webdav luci-app-aria2 luci-app-arpbind luci-app-attendedsysupgrade luci-app-cifs-mount \
luci-app-autotimeset luci-app-cpulimit luci-app-cloudreve luci-app-ddns luci-app-diskman luci-app-easymesh luci-app-hd-idle luci-app-gowebdav \
luci-app-jd-dailybonus luci-app-homeassistant luci-app-ksmbd luci-app-mosdns luci-app-mwan3 luci-app-oaf luci-app-ramfree luci-app-nlbwmon \
luci-app-quickstart luci-app-netspeedtest luci-app-qbittorrent luci-app-parentcontrol luci-app-netdata luci-app-openvpn-server luci-app-rclone \
luci-app-wechatpush luci-app-smartdns luci-app-store luci-app-unblockmusic luci-app-vsftpd luci-app-argon-config luci-app-wireguard \
luci-app-wifischedule luci-app-ttyd luci-app-statistics luci-app-transmission luci-app-usb-printer luci-app-unishare luci-app-watchcat \
luci-app-wifidog luci-app-wrtbwmon luci-app-zerotier btop naiveproxy luci-theme-edge \
coremark wget-ssl curl autocore htop nano zram-swap kmod-lib-zstd kmod-tcp-bbr bash openssh-sftp-server block-mount resolveip ds-lite swconfig luci-app-fan /" include/target.mk
sed -i "s/procd-ujail//" include/target.mk

sed -i "s/^.*vermagic$/\techo '1' > \$(LINUX_DIR)\/.vermagic/" include/kernel-defaults.mk

status=$(curl -H "Authorization: token $REPO_TOKEN" -s "https://api.github.com/repos/kiddin9/openwrt-packages/actions/runs" | jq -r '.workflow_runs[0].status')
echo "$status"
while [[ "$status" == "in_progress" || "$status" == "queued" ]];do
	echo "wait 5s"
	sleep 5
	status=$(curl -H "Authorization: token $REPO_TOKEN" -s "https://api.github.com/repos/kiddin9/openwrt-packages/actions/runs" | jq -r '.workflow_runs[0].status')
done


mv -f feeds/kiddin9/r81* tmp/

sed -i "s/192.168.1/10.1.1/" package/feeds/kiddin9/base-files/files/bin/config_generate
sed -i "s/192.168.1/10.1.1/" package/base-files/files/bin/config_generate

(
svn co https://github.com/coolsnowwolf/lede/trunk/target/linux/generic/hack-5.15 target/linux/generic/hack-5.15
svn co https://github.com/coolsnowwolf/lede/trunk/target/linux/generic/backport-5.15 target/linux/generic/backport-5.15
find target/linux/generic/backport-5.15 -name "[0-9][0-9][0-9]-[a-z][a-z]*" -exec rm -f {} \;
rm -rf target/linux/generic/backport-5.15/{799-v6.0-net-mii*,802-v6.1-nvmem*,803-v5.19-nvmem*,733-v6.2-02-net-mediatek-sgmii-ensure*,733-v6.2-03-net-mediatek*,733-v6.2-04-mtk_sgmii-enable*,775-v5.16-net-phylink*,776-v5.16-net-ethernet-*,890-v6.1-mtd-spinand-winbond*,891-v6.1-mtd-spinand-winbond*}
curl -sfL https://raw.githubusercontent.com/coolsnowwolf/lede/master/target/linux/generic/pending-5.15/613-netfilter_optional_tcp_window_check.patch -o target/linux/generic/pending-5.15/613-netfilter_optional_tcp_window_check.patch
sed -i "s/CONFIG_WERROR=y/CONFIG_WERROR=n/" target/linux/generic/config-5.15
) &

grep -q "23.05" include/version.mk && [ -d package/kernel/mt76 ] && {
mkdir package/kernel/mt76/patches
curl -sfL https://raw.githubusercontent.com/immortalwrt/immortalwrt/master/package/kernel/mt76/patches/0001-mt76-allow-VHT-rate-on-2.4GHz.patch -o package/kernel/mt76/patches/0001-mt76-allow-VHT-rate-on-2.4GHz.patch
} || rm -rf devices/common/patches/mt7922.patch

grep -q "1.8.8" package/network/utils/iptables/Makefile && {
rm -rf package/network/utils/iptables
svn co https://github.com/openwrt/openwrt/branches/openwrt-22.03/package/network/utils/iptables package/network/utils/iptables
}

grep -q 'PKG_RELEASE:=9' package/libs/openssl/Makefile && {
sh -c "curl -sfL https://github.com/openwrt/openwrt/commit/a48d0bdb77eb93f7fba6e055dace125c72755b6a.patch | patch -d './' -p1 --forward"
}

sed -i "/BuildPackage,miniupnpd-iptables/d" feeds/packages/net/miniupnpd/Makefile
sed -i 's/Os/O2/g' include/target.mk
sed -i "/mediaurlbase/d" package/feeds/*/luci-theme*/root/etc/uci-defaults/*
sed -i 's/=bbr/=cubic/' package/kernel/linux/files/sysctl-tcp-bbr.conf

# find target/linux/x86 -name "config*" -exec bash -c 'cat kernel.conf >> "{}"' \;
sed -i 's/max_requests 3/max_requests 20/g' package/network/services/uhttpd/files/uhttpd.config
#rm -rf ./feeds/packages/lang/{golang,node}
sed -i "s/tty\(0\|1\)::askfirst/tty\1::respawn/g" target/linux/*/base-files/etc/inittab


date=`date +%m.%d.%Y`
sed -i -e "/\(# \)\?REVISION:=/c\REVISION:=$date" -e '/VERSION_CODE:=/c\VERSION_CODE:=$(REVISION)' include/version.mk

sed -i \
	-e "s/+\(luci\|luci-ssl\|uhttpd\)\( \|$\)/\2/" \
	-e "s/+nginx\( \|$\)/+nginx-ssl\1/" \
	-e 's/+python\( \|$\)/+python3/' \
	-e 's?../../lang?$(TOPDIR)/feeds/packages/lang?' \
	package/feeds/kiddin9/*/Makefile

(
if [ -f sdk.tar.xz ]; then
	sed -i 's,$(STAGING_DIR_HOST)/bin/upx,upx,' package/feeds/kiddin9/*/Makefile
	mkdir sdk
	tar -xJf sdk.tar.xz -C sdk
	cp -rf sdk/*/staging_dir/* ./staging_dir/
	rm -rf sdk.tar.xz sdk
	sed -i '/\(tools\|toolchain\)\/Makefile/d' Makefile
	if [ -f /usr/bin/python ]; then
		ln -sf /usr/bin/python staging_dir/host/bin/python
	else
		ln -sf /usr/bin/python3 staging_dir/host/bin/python
	fi
	ln -sf /usr/bin/python3 staging_dir/host/bin/python3
fi
) &
