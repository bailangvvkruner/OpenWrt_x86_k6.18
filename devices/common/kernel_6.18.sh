#!/bin/bash

# ============================================================
# OpenWrt 内核版本切换脚本 - 切换到 Linux 6.18.y 版本
# ============================================================
# 此脚本的作用是将 OpenWrt 的内核版本从默认版本切换到 6.18 版本
# 实现原理：
# 1. 删除当前 OpenWrt 源码中的内核相关目录
# 2. 从 mgz0227/openwrt 仓库的 6.18.y 分支获取适配好的内核代码
# 3. 更新相关的软件包以兼容新内核
# ============================================================

# 启用 Bash 的扩展通配符功能
# 允许使用 !(pattern) 等高级通配符语法
shopt -s extglob

# ========== 第一步：删除原有内核相关目录 ==========
# 删除以下目录，为切换内核做准备：
# - target/linux: 内核目标平台配置（包含各平台的内核配置、补丁等）
# - package/boot: 引导加载程序包（如 uboot, grub 等）
# - package/devel: 开发工具包（如调试工具、性能分析工具）
# - package/firmware: 固件包（如无线固件、CPU 微码等）
# - package/kernel: 内核模块包（如驱动模块、内核补丁）
# - package/libs: 库文件包（如 libnl, openssl 等）
# - package/network: 网络相关包（如防火墙、VPN 等）
# - tools: 编译工具链组件
# - toolchain: 交叉编译工具链
# 这些目录中的内容会与 6.18 内核不兼容，必须替换
rm -rf target/linux package/boot package/devel package/firmware package/kernel package/libs package/network package/kernel tools toolchain

# ========== 第二步：创建临时目录并切换到 6.18.y 分支 ==========
# 创建临时目录用于检出 6.18.y 分支的代码
mkdir new
# 复制 .git 目录到 new 目录，保留 git 仓库信息
# 这样可以在 new 目录中切换分支
cp -rf .git new/.git
cd new

# 强制切换到 6.18.y 分支
# origin/6.18.y 是远程分支名，表示 mgz0227/openwrt 仓库中维护的 6.18 内核分支
# --hard 参数会丢弃所有本地修改，完全同步到远程分支状态
git reset --hard origin/6.18.y

# ========== 第三步：复制 6.18 内核相关文件回主目录 ==========
# 将 6.18.y 分支中的内核相关文件复制回上级目录（主工作目录）
# --parents 参数保留目录结构
# 复制的目录说明：
# - target/linux: 6.18 内核的平台配置和补丁
# - package/boot: 适配 6.18 的引导程序
# - package/devel: 适配 6.18 的开发工具
# - package/firmware: 适配 6.18 的固件
# - package/kernel: 6.18 内核模块和驱动
# - package/libs: 适配 6.18 的库文件
# - package/network: 适配 6.18 的网络组件
# - tools: 适配 6.18 的编译工具
# - toolchain: 适配 6.18 的工具链
# - config: 构建系统配置文件
cp -rf --parents target/linux package/boot package/devel package/firmware package/kernel package/libs package/network package/kernel tools toolchain config ../

# 删除 bcm53xx 平台支持
# bcm53xx 是 Broadcom 的 ARM 路由器平台
# 可能因为 6.18 内核支持不完善或有编译问题而被移除
rm -rf target/linux/bcm53xx

# 返回主工作目录
cd -

# ========== 第四步：更新 feeds/packages 中的软件包 ==========
# 进入 packages feed 目录
cd feeds/packages

# 替换 libmariadb（MariaDB 数据库客户端库）
# 使用 graysky2 维护的版本，该版本针对新内核进行了适配
# libmariadb 是 MySQL 的一个分支，用于数据库连接
rm -rf libs/libmariadb
git_clone_path libmaria https://github.com/graysky2/packages libs/libmariadb
cd ../../

# ========== 第五步：更新更多软件包以兼容 6.18 内核 ==========
# 进入 packages feed 目录
cd feeds/packages

# 删除以下软件包，准备用新版本替换：
# - net/xtables-addons: iptables 扩展模块（需要适配新内核的 netfilter）
# - net/jool: IPv4/IPv6 转换工具（内核模块需要适配）
# - kernel/v4l2loopback: 视频回环设备驱动
# - libs/libpfring: 高性能数据包处理库
rm -rf net/xtables-addons net/jool kernel/v4l2loopback libs/libpfring

# 从官方 packages 仓库获取 jool、v4l2loopback、libpfring
# master 分支包含最新版本，可能已经支持 6.18 内核
git_clone_path master https://github.com/openwrt/packages net/jool kernel/v4l2loopback libs/libpfring

# 从 graysky2 的仓库获取 xtables-addons
# 6.18-xt-addons 分支是专门为 6.18 内核适配的版本
# xtables-addons 提供额外的 iptables 匹配和目标模块
git_clone_path 6.18-xt-addons https://github.com/graysky2/packages net/xtables-addons

# 下载 ovpn-dco (OpenVPN Data Channel Offload) 的 Makefile
# ovpn-dco 是 OpenVPN 的内核级数据通道卸载功能
# 可以提高 OpenVPN 的性能
# 这个 Makefile 是针对 6.18 内核适配的版本
wget -N https://raw.githubusercontent.com/graysky2/packages/c55afaa2bebca50a0e019a249c2748e7d7f745b7/kernel/ovpn-dco/Makefile -P kernel/ovpn-dco/

cd ../../

# ========== (已注释) miaogongzi 源的修改 ==========
# 以下代码被注释，可能是这些包已经不需要特殊处理
#cd feeds/miaogongzi
#rm -rf fibocom_QMI_WWAN rkp-ipid
#cd ../../
# fibocom_QMI_WWAN: Fibocom 4G/5G 模块驱动
# rkp-ipid: 可能是某个网络相关的补丁

# ========== 第六步：更新主 package 目录中的软件包 ==========
# 进入主 package 目录
cd package

# 删除以下软件包组件：
# - devel/kselftests-bpf: BPF (Berkeley Packet Filter) 自测试工具
#   可能与 6.18 内核的 BPF 接口不兼容
# - libs/libnl/Makefile: libnl (Netlink 库) 的 Makefile
#   需要替换为适配 6.18 的版本
# - kernel/mt76: MediaTek 无线网卡驱动
#   需要替换为支持 6.18 内核的版本
# - kernel/ath10k-ct: Qualcomm Atheros 无线网卡驱动 (ct 版本)
#   需要替换为支持 6.18 内核的版本
rm -rf devel/kselftests-bpf  libs/libnl/Makefile kernel/mt76 kernel/ath10k-ct

# (已注释) mt76 驱动的补丁下载
# mt76 是 MediaTek 76xx 系列无线网卡驱动
# 这个补丁修复了定时器兼容性问题
# wget -N https://patch-diff.githubusercontent.com/raw/openwrt/mt76/pull/1026.patch -P kernel/mt76/patches/
# mv kernel/mt76/patches/1026.patch kernel/mt76/patches/002-fix-mt76-timer-compat.patch

# 下载适配 6.18 内核的 libnl Makefile
# libnl 是用于与内核 netlink 接口通信的用户空间库
# 许多网络工具（如 iw, nl80211）依赖此库
# 6.18-libnl 分支包含针对 6.18 内核的适配
wget -N https://raw.githubusercontent.com/mgz0227/openwrt/refs/heads/6.18-libnl/package/libs/libnl/Makefile -P libs/libnl/ 

cd ../

# ========== 第七步：修复 tools/tar 编译问题 ==========
# 在 tools/tar/Makefile 中添加 gl_cv_func_getcwd_path_max=yes
# 这会跳过 gnulib 对 getcwd_path_max 的运行时检测
# 解决某些环境下 tar 编译卡住或失败的问题
sed -i '/HOST_BUILD_PARALLEL := 1/a HOST_CONFIGURE_VARS += gl_cv_func_getcwd_path_max=yes' tools/tar/Makefile

# ============================================================
# 脚本执行完成后的效果：
# 1. OpenWrt 源码中的内核相关代码已切换到 6.18.y 版本
# 2. 所有依赖内核的软件包已更新为兼容版本
# 3. 编译时将使用 Linux 6.18 内核
# 
# 注意事项：
# - 此脚本必须在 OpenWrt 源码根目录执行
# - 执行前需要确保 git 仓库有 6.18.y 分支
# - 执行后需要重新运行 make defconfig 和编译
# ============================================================
