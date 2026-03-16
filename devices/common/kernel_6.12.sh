#!/bin/bash

# ============================================================
# OpenWrt 内核版本切换脚本 - 切换到 Linux 6.12.y 版本
# ============================================================
# 此脚本的作用是将 OpenWrt 的内核版本切换到 6.12 版本
# 6.12 是 OpenWrt 官方支持的较新内核版本
# 实现原理：
# 1. 删除当前 OpenWrt 源码中的内核相关目录
# 2. 从 mgz0227/openwrt 仓库的 master 分支获取适配好的内核代码
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
# 注意：与 kernel_6.18.sh 相比，这里没有删除 package/kernel（第二次出现）
rm -rf target/linux package/boot package/devel package/firmware package/kernel package/libs package/network tools toolchain

# ========== 第二步：创建临时目录并切换到 master 分支 ==========
# 创建临时目录用于检出 master 分支的代码
mkdir new
# 复制 .git 目录到 new 目录，保留 git 仓库信息
# 这样可以在 new 目录中切换分支
cp -rf .git new/.git
cd new

# 强制切换到 master 分支
# origin/master 是远程分支名，表示 mgz0227/openwrt 仓库的主分支
# master 分支通常包含 6.12 内核版本
# --hard 参数会丢弃所有本地修改，完全同步到远程分支状态
git reset --hard origin/master

# ========== 第三步：复制 6.12 内核相关文件回主目录 ==========
# 将 master 分支中的内核相关文件复制回上级目录（主工作目录）
# --parents 参数保留目录结构
# 复制的目录说明：
# - target/linux: 6.12 内核的平台配置和补丁
# - package/boot: 适配 6.12 的引导程序
# - package/devel: 适配 6.12 的开发工具
# - package/firmware: 适配 6.12 的固件
# - package/kernel: 6.12 内核模块和驱动
# - package/libs: 适配 6.12 的库文件
# - package/network: 适配 6.12 的网络组件
# - tools: 适配 6.12 的编译工具
# - toolchain: 适配 6.12 的工具链
# - config: 构建系统配置文件
cp -rf --parents target/linux package/boot package/devel package/firmware package/kernel package/libs package/network tools toolchain config ../

# 返回主工作目录
cd -

# ========== 第四步：更新 feeds/packages 中的软件包 ==========
# 进入 packages feed 目录
cd feeds/packages

# 删除以下软件包，准备用新版本替换：
# - net/xtables-addons: iptables 扩展模块（需要适配新内核的 netfilter）
# - net/strongswan: StrongSwan VPN 解决方案（IPsec 实现）
# - utils/coremark: CoreMark CPU 性能基准测试工具
# - lang/golang: Go 语言支持包
# - utils/open-vm-tools: VMware 虚拟机工具
# - libs/rpcsvc-proto: RPC 服务协议定义
# - libs: 整个 libs 目录（库文件集合）
rm -rf net/xtables-addons net/strongswan utils/coremark lang/golang utils/open-vm-tools libs/rpcsvc-proto libs

# 从官方 packages 仓库获取最新版本的软件包
# master 分支包含最新版本，已经支持 6.12 内核
# 这些软件包对于 6.12 内核的兼容性更好
git_clone_path master https://github.com/openwrt/packages net/xtables-addons net/strongswan lang/golang utils/open-vm-tools libs/rpcsvc-proto libs
cd ../../

# ========== (已注释) 可选的软件包修改 ==========
# 以下代码被注释，可能是这些包已经不需要特殊处理
#cd package
# 删除 BPF 自测试工具
#rm -rf devel/kselftests-bpf 
# 删除 perf 性能分析工具
#devel/perf
#cd ../

# ============================================================
# 脚本执行完成后的效果：
# 1. OpenWrt 源码中的内核相关代码已切换到 6.12.y 版本
# 2. 所有依赖内核的软件包已更新为兼容版本
# 3. 编译时将使用 Linux 6.12 内核
# 
# 与 kernel_6.18.sh 的区别：
# 1. 使用 master 分支而非 6.18.y 分支
# 2. 没有删除 bcm53xx 平台支持
# 3. 更新的软件包列表略有不同
# 4. 6.12 是官方支持的版本，兼容性更好
# 
# 注意事项：
# - 此脚本必须在 OpenWrt 源码根目录执行
# - 执行前需要确保 git 仓库有 master 分支
# - 执行后需要重新运行 make defconfig 和编译
# ============================================================
