#!/bin/bash

# 获取当前脚本所在的绝对路径目录
# readlink -f "$0" 获取脚本的绝对路径
# dirname 获取该路径的目录部分
SHELL_FOLDER=$(dirname $(readlink -f "$0"))

# 调用通用目录下的 kernel_6.18.sh 脚本
# 该脚本会将 OpenWrt 的内核版本从默认版本切换到 6.18
# 主要操作：删除原有内核相关目录，从 6.18.y 分支拉取新代码
bash $SHELL_FOLDER/../common/kernel_6.18.sh

# (已注释) 从 Lean 的 LEDE 项目克隆 x86 平台的文件和补丁
# LEDE 是 OpenWrt 的一个流行分支，包含更多驱动和功能
#git_clone_path master https://github.com/coolsnowwolf/lede target/linux/x86/files target/linux/x86/patches-6.6

# 从 Lean 的 LEDE 项目下载网络配置脚本
# 02_network 脚本用于自动检测和配置网络接口
# 这里的脚本可能包含更多网卡型号的识别支持
# 文件下载地址：https://github.com/coolsnowwolf/lede/blob/master/target/linux/x86/base-files/etc/board.d/02_network
wget -N https://raw.githubusercontent.com/coolsnowwolf/lede/master/target/linux/x86/base-files/etc/board.d/02_network -P target/linux/x86/base-files/etc/board.d/

# 删除 APK 包管理器的提示脚本
# OpenWrt 新版本使用 APK 替代 OPKG，此脚本会显示使用提示
# 删除后可以减少系统中的提示信息
rm -rf package/base-files/files/etc/profile.d/apk-cheatsheet.sh

# ========== 内核升级模块 开始 ==========

# 删除 ksmbd (SMB/CIFS 服务器) 的一个补丁
# 该补丁修复了 v6.18 版本的递归锁定问题
# 但因为我们使用的是 6.18 内核，这个针对 6.12 的 backport 补丁可能不兼容
# 所以需要删除，避免编译冲突
rm -rf target/linux/generic/backport-6.12/510-v6.18-ksmbd-fix-recursive-locking-in-RPC-handle-list-access.patch

# (不能删除) 以下注释掉的命令会删除所有内核版本定义文件
# 这些文件定义了内核的具体版本号和补丁级别
#rm -rf target/linux/generic/kernel-*

# 从 mgz0227 的 openwrt 仓库 6.18.y 分支下载内核版本定义文件
# kernel-6.18 文件包含内核版本号和补丁级别的定义
# 下载到两个位置：
# 1. include/ - OpenWrt 构建系统引用位置
# 2. target/linux/generic/ - 通用内核配置位置
# 文件格式示例：
# LINUX_VERSION-6.18 = .5
# 表示完整内核版本为 6.18.5
wget -N https://raw.githubusercontent.com/mgz0227/openwrt/refs/heads/6.18.y/target/linux/generic/kernel-6.18 -P include/
wget -N https://raw.githubusercontent.com/mgz0227/openwrt/refs/heads/6.18.y/target/linux/generic/kernel-6.18 -P target/linux/generic/

# ========== 内核升级模块 结束 ==========

# (已注释) 将 Realtek r8169 驱动替换为 r8168 驱动
# r8169 是内核自带的开源驱动，r8168 是 Realtek 官方闭源驱动
# 某些网卡型号使用 r8168 更稳定
#sed -i 's/kmod-r8169/kmod-r8168/' target/linux/x86/image/64.mk

# 为 x86_64 平台添加额外的默认软件包
# 这些软件包会在编译时自动包含到固件中
# 包含的功能模块：
# - kmod-fs-f2fs: F2FS 文件系统支持（闪存优化文件系统）
# - kmod-mmc, kmod-sdhci: SD/MMC 卡和 SDIO 设备支持
# - kmod-usb-hid: USB 人机接口设备（键盘、鼠标等）
# - usbutils: USB 设备工具（lsusb 等）
# - pciutils: PCI 设备工具（lspci 等）
# - lm-sensors-detect: 温度传感器检测工具
# - kmod-atlantic: Aquantia AQC 系列 10G 网卡驱动
# - kmod-vmxnet3: VMware 虚拟网卡驱动
# - kmod-igbvf: Intel 千兆虚拟功能网卡驱动
# - kmod-iavf: Intel 以太网适配器虚拟功能驱动
# - kmod-bnx2x: Broadcom NetXtreme II 10G 网卡驱动
# - kmod-pcnet32: AMD PCnet32 网卡驱动
# - kmod-tulip: DECchip Tulip 网卡驱动
# - kmod-8139cp, kmod-8139too: Realtek 8139 系列网卡驱动
# - kmod-i40e: Intel XL710 40G 网卡驱动
# - kmod-drm-amdgpu: AMD GPU 开源驱动
# - kmod-mlx4-core, kmod-mlx5-core: Mellanox 网卡驱动
# - fdisk: 磁盘分区工具
# - lsblk: 列出块设备工具
# - kmod-phy-broadcom: Broadcom PHY 驱动
# - kmod-ixgbevf: Intel 10G 虚拟功能网卡驱动
sed -i 's/DEFAULT_PACKAGES +=/DEFAULT_PACKAGES += kmod-fs-f2fs kmod-mmc kmod-sdhci kmod-usb-hid usbutils pciutils lm-sensors-detect kmod-atlantic kmod-vmxnet3 kmod-igbvf kmod-iavf kmod-bnx2x kmod-pcnet32 kmod-tulip kmod-8139cp kmod-8139too kmod-i40e kmod-drm-amdgpu kmod-mlx4-core kmod-mlx5-core fdisk lsblk kmod-phy-broadcom kmod-ixgbevf/' target/linux/x86/Makefile

# 修改固件镜像大小，从 256MB 增加到 1024MB (1GB)
# 这样可以安装更多软件包，适合作为软路由或家庭服务器使用
# 影响的是生成的 img 镜像文件的大小
sed -i 's/256/1024/g' target/linux/x86/image/Makefile
