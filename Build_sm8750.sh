#!/bin/bash

# 颜色定义
info() {
  tput setaf 3
  echo "[INFO] $1"
  tput sgr0
}

error() {
  tput setaf 1
  echo "[ERROR] $1"
  tput sgr0
  exit 1
}

# 参数设置
ENABLE_KPM=true
ENABLE_LZ4KD=true

# 机型选择
info "请选择要编译的机型："
info "1. 一加 Ace 5 Pro"
info "2. 一加 13"
info "3.一加 13T"
info "4.一加 Pad 2 Pro"
info "5.一加 Ace5 至尊版"
info "6.真我 GT 7 Pro"
info "7.真我 GT 7 Pro 竞速"

read -p "输入选择 [1-4]: " device_choice

case $device_choice in
    1)
        DEVICE_NAME="oneplus_ace5_pro"
        REPO_MANIFEST="JiuGeFaCai_oneplus_ace5_pro_v.xml"
        KERNEL_TIME="Tue Dec 17 23:36:49 UTC 2024"
        KERNEL_SUFFIX="-android15-8-g013ec21bba94-abogki383916444-4k"
        ;;
    2)
        DEVICE_NAME="oneplus_13"
        REPO_MANIFEST="JiuGeFaCai_oneplus_13_v.xml"
        KERNEL_TIME="Tue Dec 17 23:36:49 UTC 2024"
        KERNEL_SUFFIX="-android15-8-g013ec21bba94-abogki383916444-4k"
        ;;
    3)
        DEVICE_NAME="oneplus_13t"
        REPO_MANIFEST="oneplus_13t.xml"
        KERNEL_TIME="FriApr 25 01:56:53 UTC 2025"
        KERNEL_SUFFIX="-android15-8-gba3bcfd39307-abogki413159095-4k"
        ;;
    4)
        DEVICE_NAME="oneplus_pad_2_pro"
        REPO_MANIFEST="oneplus_pad_2_pro.xml"
        KERNEL_TIME="Tue Mar 4 09:04:13 UTC 2025"
        KERNEL_SUFFIX="-android15-8-g302cb15749a8-ab13157299-4k"
        ;;
    5)
        DEVICE_NAME="oneplus_ace5_ultra"
        REPO_MANIFEST="oneplus_ace5_ultra.xml"
        KERNEL_TIME="Fri Apr 18 19:35:07 UTC 2025"
        KERNEL_SUFFIX="-android15-8-gfc70d29746a7-abogki412262948-4k"
        ;;
    6)
        DEVICE_NAME="realme_GT7pro"
        REPO_MANIFEST="realme_GT7pro.xml"
        KERNEL_TIME="Tue Dec 17 23:36:49 UTC 2024"
        KERNEL_SUFFIX="-android15-8-g013ec21bba94-abogki383916444-4k"
        ;;
    7)
        DEVICE_NAME="realme_GT7pro_Speed"
        REPO_MANIFEST="realme_GT7pro_Speed.xml"
        KERNEL_TIME="Tue Dec 17 23:36:49 UTC 2024"
        KERNEL_SUFFIX="-android15-8-g013ec21bba94-abogki383916444-4k"
        ;;
    *)
        error "无效的选择，请输入1-3之间的数字"
        ;;
esac

# 自定义补丁
# 函数：用于判断输入，确保无效输入返回默认值
prompt_boolean() {
    local prompt="$1"
    local default_value="$2"
    local result
    read -p "$prompt" result
    case "$result" in
        [nN]) echo false ;;
        [yY]) echo true ;;
        "") echo "$default_value" ;;
        *) echo "$default_value" ;;
    esac
}

# 自定义补丁设置
read -p "输入内核名称修改(可改中文和emoji，回车默认): " input_suffix
[ -n "$input_suffix" ] && KERNEL_SUFFIX="$input_suffix"

read -p "输入内核构建日期更改(回车默认为原厂): " input_time
[ -n "$input_time" ] && KERNEL_TIME="$input_time"

ENABLE_KPM=$(prompt_boolean "是否启用KPM？(回车默认开启) [y/N]: " true)
ENABLE_LZ4KD=$(prompt_boolean "是否启用LZ4KD？(回车默认开启) [y/N]: " true)
ENABLE_BBR=$(prompt_boolean "是否启用BBR？(回车默认关闭) [y/N]: " false)

# 选择的机型信息输出
info "选择的机型: $DEVICE_NAME"
info "内核源码文件: $REPO_MANIFEST"
info "内核名称: $KERNEL_SUFFIX"
info "内核时间: $KERNEL_TIME"
info "是否开启KPM: $ENABLE_KPM"
info "是否开启LZ4KD: $ENABLE_LZ4KD"
info "是否开启BBR: $ENABLE_BBR"

# 环境变量 - 按机型区分ccache目录
export CCACHE_COMPILERCHECK="%compiler% -dumpmachine; %compiler% -dumpversion"
export CCACHE_NOHASHDIR="true"
export CCACHE_HARDLINK="true"
export CCACHE_DIR="$HOME/.ccache_${DEVICE_NAME}"  # 改为按机型区分
export CCACHE_MAXSIZE="8G"

# ccache 初始化标志文件也按机型区分
CCACHE_INIT_FLAG="$CCACHE_DIR/.ccache_initialized"

# 初始化 ccache（仅第一次）
if command -v ccache >/dev/null 2>&1; then
    if [ ! -f "$CCACHE_INIT_FLAG" ]; then
        info "第一次为${DEVICE_NAME}初始化ccache..."
        mkdir -p "$CCACHE_DIR" || error "无法创建ccache目录"
        ccache -M "$CCACHE_MAXSIZE"
        touch "$CCACHE_INIT_FLAG"
    else
        info "ccache (${DEVICE_NAME}) 已初始化，跳过..."
    fi
else
    info "未安装 ccache，跳过初始化"
fi

# 工作目录 - 按机型区分
WORKSPACE="$HOME/kernel_${DEVICE_NAME}"
mkdir -p "$WORKSPACE" || error "无法创建工作目录"
cd "$WORKSPACE" || error "无法进入工作目录"

# 检查并安装依赖
info "检查并安装依赖..."
DEPS=(python3 p7zip-full git curl ccache libelf-dev build-essential libelf-dev flex bison libssl-dev libncurses-dev liblz4-tool zlib1g-dev libxml2-utils rsync unzip)
MISSING_DEPS=()

for pkg in "${DEPS[@]}"; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
        MISSING_DEPS+=("$pkg")
    fi
done

if [ ${#MISSING_DEPS[@]} -eq 0 ]; then
    info "所有依赖已安装，跳过安装。"
else
    info "缺少依赖：${MISSING_DEPS[*]}，正在安装..."
    sudo apt update || error "系统更新失败"
    sudo apt install -y "${MISSING_DEPS[@]}" || error "依赖安装失败"
fi

# 配置 Git（仅在未配置时）
info "检查 Git 配置..."

GIT_NAME=$(git config --global user.name || echo "")
GIT_EMAIL=$(git config --global user.email || echo "")

if [ -z "$GIT_NAME" ] || [ -z "$GIT_EMAIL" ]; then
    info "Git 未配置，正在设置..."
    git config --global user.name "Q1udaoyu"
    git config --global user.email "sucisama2888@gmail.com"
else
    info "Git 已配置："
fi

# 安装repo工具（仅首次）
if ! command -v repo >/dev/null 2>&1; then
    info "安装repo工具..."
    curl -fsSL https://storage.googleapis.com/git-repo-downloads/repo > ~/repo || error "repo下载失败"
    chmod a+x ~/repo
    sudo mv ~/repo /usr/local/bin/repo || error "repo安装失败"
else
    info "repo工具已安装"
fi

# 如果启用 KPM，修改 .config 文件中的设置
if [ "$ENABLE_KPM" = true ]; then
    info "启用 KPM 驱动..."
    if [ -f "$WORKSPACE/.config" ]; then
        sed -i 's/^# CONFIG_KPM is not set/CONFIG_KPM=y/' "$WORKSPACE/.config" || error "无法设置 KPM"
    else
        error "未找到 .config 配置文件"
    fi
fi
