#!/bin/bash
#=================================================
# OpenWrt 通用 DIY 配置脚本
# 此脚本在编译前运行，用于自定义 OpenWrt 固件
#=================================================

# 启用 Bash 的扩展通配符功能
# 允许使用 !(pattern) 等高级通配符语法
shopt -s extglob

# ========== 软件源镜像切换 ==========
# 将 OpenWrt 官方 Git 源替换为 GitHub 镜像源
# 原因：GitHub 在国内访问相对更稳定（配合代理）
# 修改 feeds.conf.default 中的三个主要软件源：
# 1. packages - 核心软件包源
# 2. luci - Web 管理界面源
# 3. routing - 路由协议源
sed -i 's#https://git.openwrt.org/feed/packages.git#https://github.com/openwrt/packages.git#g' feeds.conf.default
sed -i 's#https://git.openwrt.org/project/luci.git#https://github.com/openwrt/luci.git#g' feeds.conf.default
sed -i 's#https://git.openwrt.org/feed/routing.git#https://github.com/openwrt/routing.git#g' feeds.conf.default

# ========== 添加自定义软件源 ==========
# 添加 miaogongzi 的自定义软件包源
# 该源包含 OpenClash、AdGuardHome 等常用插件
# 格式：src-git <源名称> <仓库地址>;<分支名>
sed -i '$a src-git miaogongzi https://github.com/mgz0227/OP-Packages.git;main' feeds.conf.default

# 删除不需要的软件源，减少编译时间和空间占用
# telephony: 电话/VoIP 相关包
# video: 视频相关包
sed -i "/telephony/d" feeds.conf.default
sed -i "/video/d" feeds.conf.default

# ========== 修改软件包索引路径 ==========
# 将软件包路径从 targets/%S/packages 改为 targets/%S/$(LINUX_VERSION)
# 这样可以按内核版本区分软件包，避免版本混乱
# %S 会被替换为目标平台名称（如 x86/64）
sed -i "s?targets/%S/packages?targets/%S/\$(LINUX_VERSION)?" include/feeds.mk

# 删除 feeds 脚本中的 refresh_config() 调用
# 避免在安装软件包时自动刷新配置，加快编译速度
sed -i '/	refresh_config();/d' scripts/feeds

# ========== 更新和安装软件包源 ==========
# 更新所有软件源
./scripts/feeds update -a
# 优先从 miaogongzi 源安装软件包（-f 强制覆盖）
./scripts/feeds install -a -p miaogongzi -f
# 安装所有其他源的软件包
./scripts/feeds install -a

# ========== 自定义系统信息 ==========
# 修改 os-release 文件中的版本信息
# 在 %C（版本代号）后添加 "by miaogongzi" 标识
sed --follow-symlinks -i "s#%C\"#%C by miaogongzi\"#" package/base-files/files/etc/os-release

# ========== 系统升级保留文件配置 ==========
# 在升级保留列表中添加 /etc/bench.log（性能测试日志）
# 删除 /etc/profile 和 /etc/shinit 的保留（这些文件会在升级时重置）
sed -i -e '$a /etc/bench.log' \
        -e '/\/etc\/profile/d' \
        -e '/\/etc\/shinit/d' \
        package/base-files/files/lib/upgrade/keep.d/base-files-essential

# 从 Makefile 中删除 profile 和 shinit 的安装配置
sed -i -e '/^\/etc\/profile/d' \
        -e '/^\/etc\/shinit/d' \
        package/base-files/Makefile

# 修改默认 LAN IP 地址
# 从 192.168.1.x 改为 192.168.3.x，避免与常见路由器冲突
sed -i "s/192.168.1/192.168.3/" package/base-files/files/bin/config_generate

# ========== (已注释) ImmortalWrt 补丁下载 ==========
# 以下是从 ImmortalWrt 项目下载的增强补丁（已禁用）
# video.mk: 视频驱动模块
# nftables: Fullcone NAT 支持（全锥型 NAT）
# libnftnl: Fullcone NAT 库支持
# wireless-regdb: 无线功率和 DFS 限制修改
# fstools: NTFS3 UTF-8 支持
# Config-kernel.in: 内核配置选项
#wget -N https://github.com/immortalwrt/immortalwrt/raw/refs/heads/openwrt-25.12/package/kernel/linux/modules/video.mk -P package/kernel/linux/modules/
#wget -N https://github.com/immortalwrt/immortalwrt/raw/refs/heads/openwrt-25.12/package/network/utils/nftables/patches/002-nftables-add-fullcone-expression-support.patch -P package/network/utils/nftables/patches/
#wget -N https://github.com/immortalwrt/immortalwrt/raw/refs/heads/openwrt-25.12/package/network/utils/nftables/patches/001-drop-useless-file.patch -P package/network/utils/nftables/patches/
#wget -N https://github.com/immortalwrt/immortalwrt/raw/refs/heads/openwrt-25.12/package/libs/libnftnl/patches/001-libnftnl-add-fullcone-expression-support.patch -P package/libs/libnftnl/patches/
#wget -N https://github.com/immortalwrt/immortalwrt/raw/refs/heads/openwrt-25.12/package/firmware/wireless-regdb/patches/600-custom-change-txpower-and-dfs.patch -P package/firmware/wireless-regdb/patches/
#wget -N  https://github.com/coolsnowwolf/lede/raw/refs/heads/master/package/system/fstools/patches/0200-ntfs3-with-utf8.patch -P package/system/fstools/patches/
#wget -N https://github.com/immortalwrt/immortalwrt/raw/refs/heads/openwrt-25.12/config/Config-kernel.in -P config/

# ========== 替换 OpenSSL 和 PPP 包 ==========
# 使用 ImmortalWrt 版本的 OpenSSL 和 PPP
# ImmortalWrt 版本通常包含更多优化和补丁
rm -rf package/libs/openssl package/network/services/ppp
git_clone_path openwrt-25.12 https://github.com/immortalwrt/immortalwrt package/libs/openssl package/network/services/ppp 

# ========== 版本时间戳 ==========
# 生成当前时间戳并保存到 version.date
# 用于固件版本标识
echo "$(date +"%s")" >version.date

# ========== 编译依赖修改 ==========
# 修改 package 编译依赖，确保 opkg/host 先编译
# opkg 是 OpenWrt 的包管理器
sed -i '/$(curdir)\/compile:/c\$(curdir)/compile: package/opkg/host/compile' package/Makefile

# ========== 默认软件包配置 ==========
# 设置固件默认安装的软件包列表
# 这些软件包会在首次启动时自动安装
# 包含的软件包说明：
# - luci-app-advancedplus: LuCI 高级设置插件
# - luci-app-firewall: 防火墙管理界面
# - luci-app-package-manager: 软件包管理器界面
# - luci-app-wizard: 设置向导
# - luci-base: LuCI 基础框架
# - luci-compat: LuCI 兼容层
# - luci-lib-ipkg: IPKG 库支持
# - luci-lib-fs: 文件系统库
# - luci-app-log-viewer: 日志查看器
# - luci-app-argon-config: Argon 主题配置
# - luci-app-ddns-go: DDNS 动态域名服务
# - luci-app-openclash: OpenClash 代理插件
# - luci-app-adguardhome: AdGuard Home 广告拦截
# - tcpdump-mini: 网络抓包工具（精简版）
# - open-vm-tools: VMware 虚拟机工具
# - wget-ssl: 支持 SSL 的 wget
# - curl: 数据传输工具
# - autocore: 自动检测硬件信息
# - htop: 系统监控工具
# - nano: 文本编辑器
# - zram-swap: ZRAM 内存压缩交换
# - kmod-lib-zstd: Zstd 压缩库内核模块
# - kmod-tcp-bbr: BBR 拥塞控制算法
# - bash: Bash shell
# - openssh-sftp-server: SFTP 服务器
# - block-mount: 挂载点管理
# - resolveip: IP 解析工具
# - ds-lite: DS-Lite 隧道支持
# - swconfig: 交换机配置工具
# - luci-app-fan: 风扇控制插件
# - luci-app-filemanager: 文件管理器
sed -i "s/DEFAULT_PACKAGES:=/DEFAULT_PACKAGES:=luci-app-advancedplus luci-app-firewall luci-app-package-manager \
luci-app-wizard luci-base luci-compat luci-lib-ipkg luci-lib-fs luci-app-log-viewer \
luci-app-argon-config luci-app-openclash luci-app-adguardhome tcpdump-mini open-vm-tools \
wget-ssl curl autocore htop nano zram-swap kmod-lib-zstd kmod-tcp-bbr bash openssh-sftp-server block-mount resolveip ds-lite swconfig luci-app-fan luci-app-filemanager /" include/target.mk

# 删除 procd-ujail 依赖
# procd-ujail 是进程隔离容器，可能导致某些问题
sed -i "s/procd-ujail//" include/target.mk

# ========== 内核版本魔数修改 ==========
# 修改 vermagic（内核版本魔数）生成方式
# 将复杂的版本检测改为固定值 '1'
# 这样可以绕过内核模块版本检查，允许安装不同版本的模块
sed -i "s/^.*vermagic$/\techo '1' > \$(LINUX_DIR)\/.vermagic/" include/kernel-defaults.mk

# ========== (已移除) 等待 OP-Packages 构建完成 ==========
# 原代码需要 GitHub Token，已移除
# 如需启用，请自行添加 REPO_TOKEN 环境变量

# ========== (已注释) 其他可选修改 ==========
# 删除内核大小检查，允许生成更大的固件
#sed -i "/call Build\/check-size,\$\$(KERNEL_SIZE)/d" include/image.mk

# 从 LEDE 克隆内核 hack 补丁（包含各种优化）
#git_clone_path master https://github.com/coolsnowwolf/lede mv target/linux/generic/hack-6.12

# 替换 fstools 文件系统工具
#rm -rf package/system/fstools
#git_clone_path master https://github.com/coolsnowwolf/lede package/system/fstools

# Realtek PHY LED 补丁
#rm -rf target/linux/generic/hack-6.12/767-net-phy-realtek-add-led*

# TCP 窗口检查可选补丁
#wget -N https://raw.githubusercontent.com/coolsnowwolf/lede/master/target/linux/generic/pending-6.12/613-netfilter_optional_tcp_window_check.patch -P target/linux/generic/pending-6.6/

# ========== Web 服务器配置 ==========
# 修改 uhttpd 最大请求数
# 从 3 增加到 20，提高并发处理能力
sed -i 's/max_requests 3/max_requests 20/g' package/network/services/uhttpd/files/uhttpd.config

# (已注释) 删除 Go 和 Node.js 语言包，减少编译时间
#rm -rf ./feeds/packages/lang/{golang,node}

# ========== 终端登录配置 ==========
# 修改 inittab 中的终端配置
# 将 askfirst（首次按键启动）改为 respawn（自动重启）
# 这样串口终端会自动启动，无需按键
sed -i "s/tty\(0\|1\)::askfirst/tty\1::respawn/g" target/linux/*/base-files/etc/inittab

# ========== 版本号配置 ==========
# 使用当前日期作为版本号
# 格式：YYYYMMDD
date=`date +%Y%m%d`
# 修改 version.mk 中的版本定义
# REVISION: 版本修订号（设为日期）
# VERSION_CODE: 版本代码（与 REVISION 相同）
sed -i \
  -e "/\(# \)\?REVISION:=/c\REVISION:=$date" \
  -e '/VERSION_CODE:=/c\VERSION_CODE:=$(REVISION)' \
  include/version.mk

# ========== RPC 超时配置 ==========
# 增加 rpcd 的超时时间
# 从 30 秒增加到 60 秒，避免慢速设备超时
sed -i 's/option timeout 30/option timeout 60/g' package/system/rpcd/files/rpcd.config

# 增加 LuCI RPC 调用超时时间
# 从 20 秒增加到 60 秒
sed -i 's#20) \* 1000#60) \* 1000#g' feeds/luci/modules/luci-base/htdocs/luci-static/resources/rpc.js

# ========== 软件包依赖修正 ==========
# 修改 miaogongzi 源中软件包的依赖关系
# - 移除 luci/luci-ssl/uhttpd 依赖（已包含在基础包中）
# - nginx 改为 nginx-ssl（支持 HTTPS）
# - python 改为 python3
# - 修正语言包路径
sed -i \
	-e "s/+\(luci\|luci-ssl\|uhttpd\)\( \|$\)/\2/" \
	-e "s/+nginx\( \|$\)/+nginx-ssl\1/" \
	-e 's/+python\( \|$\)/+python3/' \
	-e 's?../../lang?$(TOPDIR)/feeds/packages/lang?' \
	package/feeds/miaogongzi/*/Makefile

# ========== 品牌定制 ==========
# 将系统中的 "OpenWrt" 替换为 "MeowWrt"
# 修改的文件包括：
# - config_generate: 网络配置生成脚本
# - image-config.in: 镜像配置
# - mac80211.uc: 无线配置脚本
# - Config-images.in: 镜像配置界面
# - Config.in: 主配置文件
# - u-boot.mk: U-Boot 编译配置
sed -i "s/OpenWrt/MeowWrt/g" package/base-files/files/bin/config_generate package/base-files/image-config.in package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc config/Config-images.in Config.in include/u-boot.mk  || true

# ========== 无线配置默认值 ==========
# 修改无线网络的默认配置
# 1. 默认国家代码设为 "CN"（中国）
# 2. 默认启用无线（disabled='0'）
sed -i -e "s/set \${s}.country='\${country || ''}'/set \${s}.country='\${country || \"CN\"}'/g" -e "s/set \${s}.disabled=.*/set \${s}.disabled='0'/" package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc

# (已注释) 删除 jool（IPv6/IPv4 转换工具）
#rm -rf package/feeds/packages/jool
