#!/bin/bash

# 传话筒预设市场 - 一键安装脚本
# 类似 1Panel 的开箱即用安装方式

set -e

# 项目信息
REPO_URL="https://github.com/bvzrays/chuanhuatong-preset-market.git"
PROJECT_DIR="/opt/chuanhuatong-preset-market"

# 当前工作目录
CURRENT_DIR=$(pwd)

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 打印函数
print_log() {
    echo -e "${BLUE}[传话筒预设市场]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[传话筒预设市场]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[传话筒预设市场]${NC} $1"
}

print_error() {
    echo -e "${RED}[传话筒预设市场]${NC} $1"
}

print_info() {
    echo -e "${CYAN}[传话筒预设市场]${NC} $1"
}

# 检查命令是否存在
check_command() {
    if command -v $1 &> /dev/null; then
        return 0
    fi
    return 1
}

# 获取服务器 IP
get_server_ip() {
    if check_command curl; then
        SERVER_IP=$(curl -s ifconfig.me || curl -s ip.sb || curl -s icanhazip.com)
    elif check_command wget; then
        SERVER_IP=$(wget -qO- ifconfig.me || wget -qO- ip.sb || wget -qO- icanhazip.com)
    else
        SERVER_IP="localhost"
    fi
    echo ${SERVER_IP:-localhost}
}

# 生成随机字符串
generate_random_string() {
    openssl rand -hex 16 2>/dev/null || cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1
}

# 检测系统
detect_system() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
    else
        print_error "无法检测系统类型，请确保运行在 Linux 系统上"
        exit 1
    fi
    print_log "检测到系统: $OS $OS_VERSION"
}

# 检查是否为 root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_warning "建议使用 root 用户运行安装脚本"
        read -p "是否继续？(y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# 检测是否在国内网络
detect_china_network() {
    # 检测是否能访问 Google（简单判断）
    if ! curl -s --connect-timeout 3 --max-time 5 https://www.google.com > /dev/null 2>&1; then
        return 0  # 在国内
    fi
    return 1  # 不在国内
}

# 下载文件（带重试和镜像源）
download_with_retry() {
    local url=$1
    local output=$2
    local max_attempts=3
    local attempt=1
    
    # 国内镜像源列表
    local mirror_urls=(
        "$url"  # 原始 URL
    )
    
    # 如果是 GitHub，添加镜像源
    if echo "$url" | grep -q "github.com"; then
        mirror_urls=(
            "https://ghproxy.com/$url"  # ghproxy
            "https://mirror.ghproxy.com/$url"  # mirror.ghproxy
            "https://github.com.cnpmjs.org/$(echo $url | sed 's|https://github.com/||')"  # cnpmjs
            "$url"
        )
    fi
    
    # 如果是 Docker 官方源，添加国内镜像
    if echo "$url" | grep -q "download.docker.com"; then
        mirror_urls=(
            "https://mirrors.aliyun.com/docker-ce/$(echo $url | sed 's|https://download.docker.com/||')"
            "https://mirrors.tuna.tsinghua.edu.cn/docker-ce/$(echo $url | sed 's|https://download.docker.com/||')"
            "$url"
        )
    fi
    
    for mirror_url in "${mirror_urls[@]}"; do
        attempt=1
        while [ $attempt -le $max_attempts ]; do
            if curl -fsSL --connect-timeout 10 --max-time 30 "$mirror_url" -o "$output" 2>/dev/null; then
                return 0
            fi
            attempt=$((attempt + 1))
            sleep 2
        done
    done
    
    return 1
}

# 配置 Docker 镜像加速器
configure_docker_mirror() {
    if detect_china_network; then
        print_log "检测到国内网络，配置 Docker 镜像加速器..."
        
        mkdir -p /etc/docker
        
        # 配置镜像加速器（使用多个国内镜像源）
        cat > /etc/docker/daemon.json << EOF
{
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com",
    "https://mirror.baidubce.com",
    "https://ccr.ccs.tencentyun.com"
  ]
}
EOF
        
        print_success "Docker 镜像加速器配置完成"
    fi
}

# 安装 Docker
install_docker() {
    if check_command docker && check_command docker-compose; then
        print_success "Docker 已安装"
        docker --version
        configure_docker_mirror
        systemctl restart docker 2>/dev/null || true
        return 0
    fi

    print_log "开始安装 Docker..."
    
    # 检测是否在国内
    if detect_china_network; then
        print_info "检测到国内网络环境，将使用国内镜像源"
    fi
    
    if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
        apt-get update
        apt-get install -y \
            ca-certificates \
            curl \
            gnupg \
            lsb-release \
            wget
        
        mkdir -p /etc/apt/keyrings
        
        # 下载 Docker GPG 密钥（自动使用镜像源）
        print_log "下载 Docker GPG 密钥..."
        if detect_china_network; then
            # 优先使用国内镜像
            if ! curl -fsSL --connect-timeout 10 "https://mirrors.aliyun.com/docker-ce/linux/$OS/gpg" -o /tmp/docker.gpg 2>/dev/null; then
                if ! curl -fsSL --connect-timeout 10 "https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/$OS/gpg" -o /tmp/docker.gpg 2>/dev/null; then
                    if ! download_with_retry "https://download.docker.com/linux/$OS/gpg" "/tmp/docker.gpg"; then
                        print_error "无法下载 Docker GPG 密钥"
                        exit 1
                    fi
                fi
            fi
        else
            if ! download_with_retry "https://download.docker.com/linux/$OS/gpg" "/tmp/docker.gpg"; then
                print_error "无法下载 Docker GPG 密钥"
                exit 1
            fi
        fi
        
        gpg --dearmor -o /etc/apt/keyrings/docker.gpg < /tmp/docker.gpg
        rm -f /tmp/docker.gpg
        
        # 添加 Docker 仓库
        ARCH=$(dpkg --print-architecture)
        CODENAME=$(lsb_release -cs)
        
        # 使用国内镜像源（如果检测到国内网络）
        if detect_china_network; then
            print_log "使用阿里云 Docker 镜像源"
            echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.gpg] https://mirrors.aliyun.com/docker-ce/linux/$OS $CODENAME stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        else
            echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS $CODENAME stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        fi
        
        apt-get update
        apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        
        # 安装 docker-compose standalone（使用镜像源）
        print_log "安装 docker-compose..."
        COMPOSE_URL="https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)"
        if download_with_retry "$COMPOSE_URL" "/tmp/docker-compose"; then
            mv /tmp/docker-compose /usr/local/bin/docker-compose
            chmod +x /usr/local/bin/docker-compose
            print_success "docker-compose 安装完成"
        else
            print_warning "无法下载 docker-compose，将使用 docker compose plugin"
        fi
        
    elif [ "$OS" = "centos" ] || [ "$OS" = "rhel" ]; then
        yum install -y yum-utils
        
        # 使用国内镜像源
        if detect_china_network; then
            print_log "使用阿里云 Docker 镜像源"
            yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
        else
            yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        fi
        
        yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        
        COMPOSE_URL="https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)"
        if download_with_retry "$COMPOSE_URL" "/tmp/docker-compose"; then
            mv /tmp/docker-compose /usr/local/bin/docker-compose
            chmod +x /usr/local/bin/docker-compose
            print_success "docker-compose 安装完成"
        else
            print_warning "无法下载 docker-compose，将使用 docker compose plugin"
        fi
    fi
    
    # 配置镜像加速器
    configure_docker_mirror
    
    # 启动 Docker
    systemctl start docker
    systemctl enable docker
    
    # 验证安装
    if check_command docker; then
        print_success "Docker 安装完成"
        docker --version
    else
        print_error "Docker 安装失败"
        exit 1
    fi
}

# 配置环境变量
setup_env() {
    print_log "开始配置环境变量..."
    
    # 获取服务器 IP
    SERVER_IP=$(get_server_ip)
    print_info "检测到服务器 IP: $SERVER_IP"
    
    read -p "请输入服务器 IP 或域名 (默认: $SERVER_IP): " INPUT_IP
    SERVER_IP=${INPUT_IP:-$SERVER_IP}
    
    # 选择协议
    read -p "是否使用 HTTPS？(y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        PROTOCOL="https"
        FRONTEND_PORT=""
        BACKEND_PORT=""
    else
        PROTOCOL="http"
        read -p "请输入前端端口 (默认: 5173): " FRONTEND_PORT
        FRONTEND_PORT=${FRONTEND_PORT:-5173}
        BACKEND_PORT=":8000"
    fi
    
    if [ "$PROTOCOL" = "http" ]; then
        FRONTEND_URL="$PROTOCOL://$SERVER_IP:$FRONTEND_PORT"
        BACKEND_URL="$PROTOCOL://$SERVER_IP$BACKEND_PORT"
        CALLBACK_URL="$PROTOCOL://$SERVER_IP$BACKEND_PORT/api/auth/github/callback"
    else
        FRONTEND_URL="$PROTOCOL://$SERVER_IP"
        BACKEND_URL="$PROTOCOL://$SERVER_IP"
        CALLBACK_URL="$PROTOCOL://$SERVER_IP/api/auth/github/callback"
    fi
    
    print_info "前端地址: $FRONTEND_URL"
    print_info "后端地址: $BACKEND_URL"
    print_info "回调地址: $CALLBACK_URL"
    echo
    
    # GitHub OAuth 配置
    print_warning "请先访问 https://github.com/settings/developers 创建 OAuth App"
    print_info "回调 URL 设置为: $CALLBACK_URL"
    echo
    
    read -p "请输入 GitHub Client ID: " GITHUB_CLIENT_ID
    read -p "请输入 GitHub Client Secret: " GITHUB_CLIENT_SECRET
    
    # 生成 JWT Secret
    JWT_SECRET=$(generate_random_string)
    
    # 检测是否使用国内镜像
    USE_MIRROR="false"
    if detect_china_network; then
        USE_MIRROR="true"
    fi
    
    # 创建 .env 文件
    cat > .env << EOF
# GitHub OAuth
GITHUB_CLIENT_ID=$GITHUB_CLIENT_ID
GITHUB_CLIENT_SECRET=$GITHUB_CLIENT_SECRET
GITHUB_REDIRECT_URI=$CALLBACK_URL

# JWT
JWT_SECRET_KEY=$JWT_SECRET
JWT_ALGORITHM=HS256

# Database
DATABASE_URL=sqlite+aiosqlite:///./preset_market.db

# Server
HOST=0.0.0.0
PORT=8000
CORS_ORIGINS=$FRONTEND_URL
FRONTEND_URL=$FRONTEND_URL

# Upload
MAX_UPLOAD_SIZE=10485760
UPLOAD_DIR=./uploads

# Frontend API URL
VITE_API_URL=$BACKEND_URL

# Docker 构建镜像源（国内服务器设置为 true）
USE_CHINA_MIRROR=$USE_MIRROR
EOF
    
    print_success "环境变量配置完成"
}

# 配置防火墙
setup_firewall() {
    print_log "配置防火墙..."
    
    if check_command ufw; then
        ufw allow 8000/tcp > /dev/null 2>&1
        ufw allow 5173/tcp > /dev/null 2>&1
        ufw allow 80/tcp > /dev/null 2>&1
        ufw allow 443/tcp > /dev/null 2>&1
        print_success "防火墙规则已添加"
    elif check_command firewall-cmd; then
        firewall-cmd --permanent --add-port=8000/tcp > /dev/null 2>&1
        firewall-cmd --permanent --add-port=5173/tcp > /dev/null 2>&1
        firewall-cmd --permanent --add-port=80/tcp > /dev/null 2>&1
        firewall-cmd --permanent --add-port=443/tcp > /dev/null 2>&1
        firewall-cmd --reload > /dev/null 2>&1
        print_success "防火墙规则已添加"
    else
        print_warning "未检测到防火墙工具，请手动配置防火墙开放端口 8000 和 5173"
    fi
}

# 部署服务
deploy_services() {
    print_log "开始部署服务..."
    
    # 检查 docker-compose.yml
    if [ ! -f "docker-compose.yml" ]; then
        print_error "未找到 docker-compose.yml 文件"
        exit 1
    fi
    
    # 检查 docker-compose 命令（优先使用 plugin）
    if docker compose version > /dev/null 2>&1; then
        COMPOSE_CMD="docker compose"
        print_info "使用 docker compose plugin"
    elif [ -f "/usr/local/bin/docker-compose" ] && [ -x "/usr/local/bin/docker-compose" ]; then
        COMPOSE_CMD="/usr/local/bin/docker-compose"
        print_info "使用 standalone docker-compose"
    elif check_command docker-compose; then
        COMPOSE_CMD="docker-compose"
        print_info "使用系统 docker-compose"
    else
        print_error "未找到 docker-compose 命令，尝试修复..."
        # 尝试修复权限
        if [ -f "/usr/local/bin/docker-compose" ]; then
            chmod +x /usr/local/bin/docker-compose
            COMPOSE_CMD="/usr/local/bin/docker-compose"
            print_success "已修复 docker-compose 权限"
        else
            print_error "请手动安装 docker-compose 或使用 docker compose plugin"
            exit 1
        fi
    fi
    
    # 构建镜像（如果检测到国内网络，使用镜像源）
    print_log "正在构建 Docker 镜像..."
    if detect_china_network; then
        print_info "使用国内镜像源构建..."
        export DOCKER_BUILDKIT=1
        $COMPOSE_CMD build \
            --build-arg USE_CHINA_MIRROR=true \
            --build-arg VITE_API_URL=${VITE_API_URL:-http://localhost:8000}
    else
        $COMPOSE_CMD build
    fi
    
    # 启动服务
    print_log "正在启动服务..."
    $COMPOSE_CMD up -d
    
    # 等待服务启动
    print_log "等待服务启动..."
    sleep 15
    
    # 检查服务状态
    if $COMPOSE_CMD ps | grep -q "Up"; then
        print_success "服务启动成功"
    else
        print_error "服务启动失败，请检查日志: $COMPOSE_CMD logs"
        print_info "查看详细日志: $COMPOSE_CMD logs -f"
        exit 1
    fi
}

# 显示安装结果
show_result() {
    echo
    echo "=========================================="
    print_success "感谢您的耐心等待，安装已完成"
    echo "=========================================="
    echo
    print_info "请使用您的浏览器访问面板:"
    print_info "前端地址: $FRONTEND_URL"
    print_info "后端 API: $BACKEND_URL"
    print_info "API 文档: $BACKEND_URL/docs"
    echo
    print_warning "如果您使用的是云服务器，请在安全组中打开端口 8000 和 5173"
    echo
    # 检测 docker-compose 命令
    if docker compose version > /dev/null 2>&1; then
        COMPOSE_CMD="docker compose"
    elif [ -f "/usr/local/bin/docker-compose" ] && [ -x "/usr/local/bin/docker-compose" ]; then
        COMPOSE_CMD="/usr/local/bin/docker-compose"
    elif check_command docker-compose; then
        COMPOSE_CMD="docker-compose"
    else
        COMPOSE_CMD="docker compose"
    fi
    
    print_info "常用命令:"
    echo "  查看日志: cd $PROJECT_DIR && $COMPOSE_CMD logs -f"
    echo "  停止服务: cd $PROJECT_DIR && $COMPOSE_CMD down"
    echo "  重启服务: cd $PROJECT_DIR && $COMPOSE_CMD restart"
    echo "  更新服务: cd $PROJECT_DIR && git pull && $COMPOSE_CMD up -d --build"
    echo
    print_warning "为了您的服务器安全，请妥善保管 GitHub OAuth 配置信息"
    echo
    print_info "项目目录: $PROJECT_DIR"
    echo
}

# 准备项目目录
prepare_project() {
    # 如果当前目录有 docker-compose.yml，说明已经在项目目录中
    if [ -f "docker-compose.yml" ]; then
        PROJECT_DIR=$(pwd)
        print_info "检测到项目目录: $PROJECT_DIR"
        return 0
    fi
    
    # 否则使用默认目录或创建
    if [ ! -d "$PROJECT_DIR" ]; then
        print_log "项目目录不存在，开始克隆项目..."
        if ! check_command git; then
            print_error "未找到 git 命令，正在安装 git..."
            if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
                apt-get update
                apt-get install -y git
            elif [ "$OS" = "centos" ] || [ "$OS" = "rhel" ]; then
                yum install -y git
            fi
        fi
        mkdir -p $(dirname $PROJECT_DIR)
        
        # 如果检测到国内网络，使用镜像源克隆
        if detect_china_network; then
            print_log "检测到国内网络，使用 GitHub 镜像源克隆..."
            # 尝试使用 ghproxy 代理
            MIRROR_REPO_URL="https://ghproxy.com/$REPO_URL"
            if git clone "$MIRROR_REPO_URL" "$PROJECT_DIR" 2>/dev/null; then
                print_success "使用镜像源克隆成功"
            else
                print_warning "镜像源克隆失败，尝试直接克隆..."
                git clone $REPO_URL $PROJECT_DIR
            fi
        else
            git clone $REPO_URL $PROJECT_DIR
        fi
    else
        print_log "项目目录已存在，更新代码..."
        cd $PROJECT_DIR
        if detect_china_network; then
            # 配置 git 使用代理（如果需要）
            git config --global url."https://ghproxy.com/https://github.com/".insteadOf "https://github.com/" 2>/dev/null || true
        fi
        git pull || true
    fi
    
    cd $PROJECT_DIR
    print_success "项目目录准备完成: $PROJECT_DIR"
}

# 主函数
main() {
    clear
    echo "=========================================="
    echo "  传话筒预设市场 - 一键安装脚本"
    echo "=========================================="
    echo
    
    check_root
    detect_system
    
    # 准备项目
    prepare_project
    
    # 安装 Docker
    install_docker
    
    # 配置环境变量
    setup_env
    
    # 配置防火墙
    setup_firewall
    
    # 部署服务
    deploy_services
    
    # 显示结果
    show_result
}

# 运行主函数
main
