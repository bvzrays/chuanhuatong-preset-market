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

# 安装 Docker
install_docker() {
    if check_command docker && check_command docker-compose; then
        print_success "Docker 已安装"
        docker --version
        return 0
    fi

    print_log "开始安装 Docker..."
    
    if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
        apt-get update
        apt-get install -y \
            ca-certificates \
            curl \
            gnupg \
            lsb-release
        
        mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/$OS/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS \
          $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        apt-get update
        apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        
        # 安装 docker-compose standalone
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        
    elif [ "$OS" = "centos" ] || [ "$OS" = "rhel" ]; then
        yum install -y yum-utils
        yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    fi
    
    systemctl start docker
    systemctl enable docker
    
    print_success "Docker 安装完成"
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
    
    # 构建镜像
    print_log "正在构建 Docker 镜像..."
    docker-compose build --quiet
    
    # 启动服务
    print_log "正在启动服务..."
    docker-compose up -d
    
    # 等待服务启动
    print_log "等待服务启动..."
    sleep 10
    
    # 检查服务状态
    if docker-compose ps | grep -q "Up"; then
        print_success "服务启动成功"
    else
        print_error "服务启动失败，请检查日志: docker-compose logs"
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
    print_info "常用命令:"
    echo "  查看日志: cd $PROJECT_DIR && docker-compose logs -f"
    echo "  停止服务: cd $PROJECT_DIR && docker-compose down"
    echo "  重启服务: cd $PROJECT_DIR && docker-compose restart"
    echo "  更新服务: cd $PROJECT_DIR && git pull && docker-compose up -d --build"
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
        git clone $REPO_URL $PROJECT_DIR
    else
        print_log "项目目录已存在，更新代码..."
        cd $PROJECT_DIR
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
