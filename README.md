# 🎨 传话筒预设市场

> 传话筒插件的预设分享平台，支持上传、下载、评论和点赞预设

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Python](https://img.shields.io/badge/python-3.10+-blue.svg)](https://www.python.org/)
[![Node](https://img.shields.io/badge/node-18+-green.svg)](https://nodejs.org/)

## ✨ 功能特性

- 🎨 **预设管理**：上传、下载、浏览预设
- 💬 **社区互动**：评论、点赞、排序（最新/最热/最多点赞）
- 🔐 **GitHub 登录**：使用 GitHub OAuth 2.0 身份认证
- 🖼️ **预览图生成**：自动生成预设预览图
- 📱 **响应式设计**：现代化 UI，支持移动端
- 🚀 **一键部署**：开箱即用，类似 1Panel 的安装体验

## 🚀 快速安装

### 便捷的安装方式

只需几个简单步骤，即可在您的 Linux 服务器上安装并运行传话筒预设市场

#### 1. 准备 Linux 服务器

确保您有一台运行 Linux 系统的服务器，支持 CentOS、Ubuntu、Debian 等主流发行版。

#### 2. 运行安装脚本

以 root 用户身份运行一键安装脚本，自动完成下载和安装。

**方式一：直接运行（推荐）**

```bash
bash -c "$(curl -sSL https://raw.githubusercontent.com/bvzrays/chuanhuatong-preset-market/main/install.sh)"
```

**方式二：先克隆再运行**

```bash
git clone https://github.com/bvzrays/chuanhuatong-preset-market.git
cd chuanhuatong-preset-market
chmod +x install.sh
./install.sh
```

脚本会自动：
- ✅ 检测系统环境
- ✅ 安装 Docker（如未安装）
- ✅ 配置环境变量
- ✅ 部署服务
- ✅ 配置防火墙

#### 3. 配置 GitHub OAuth

安装过程中会提示您输入 GitHub OAuth 配置。如果还没有创建 OAuth App：

1. 访问 https://github.com/settings/developers
2. 点击 "New OAuth App"
3. 填写信息：
   - **Application name**: 传话筒预设市场
   - **Homepage URL**: `http://你的IP:5173` 或 `http://你的域名`
   - **Authorization callback URL**: `http://你的IP:8000/api/auth/github/callback` 或 `http://你的域名/api/auth/github/callback`
4. 复制 **Client ID** 和 **Client Secret**

#### 4. 访问管理面板

安装完成后，通过浏览器访问安装脚本提示的访问地址，开始使用传话筒预设市场。

## 📖 使用说明

### 上传预设

1. 点击右上角 "GitHub 登录" 登录
2. 点击 "上传预设" 按钮
3. 选择从传话筒插件导出的预设 JSON 文件
4. 填写名称和描述
5. 点击 "上传预设"

### 下载预设

1. 在首页浏览预设列表
2. 点击预设卡片进入详情页
3. 点击 "下载预设" 按钮
4. 预设会自动下载为 JSON 文件，保存到 `AstrBot/data/plugin_data/astrbot_plugin_chuanhuatong/presets/`

### 评论和点赞

- 登录后可以对预设进行评论
- 点击 ❤️ 按钮为预设点赞
- 支持按最新、最热、最多点赞排序

## 🛠️ 常用命令

### 查看服务状态

```bash
docker-compose ps
```

### 查看日志

```bash
# 所有服务
docker-compose logs -f

# 特定服务
docker-compose logs -f backend
docker-compose logs -f frontend
```

### 重启服务

```bash
docker-compose restart
```

### 停止服务

```bash
docker-compose down
```

### 更新服务

```bash
git pull
docker-compose up -d --build
```

### 备份数据

```bash
# 备份数据库
docker-compose exec backend cp preset_market.db preset_market.db.backup

# 备份上传文件
docker-compose exec backend tar -czf uploads_backup.tar.gz uploads/
```

## ⚙️ 配置说明

### 环境变量

主要配置项在 `.env` 文件中：

| 变量名 | 说明 | 必需 |
|--------|------|------|
| `GITHUB_CLIENT_ID` | GitHub OAuth Client ID | ✅ |
| `GITHUB_CLIENT_SECRET` | GitHub OAuth Client Secret | ✅ |
| `GITHUB_REDIRECT_URI` | OAuth 回调地址 | ✅ |
| `JWT_SECRET_KEY` | JWT 密钥 | ✅ |
| `CORS_ORIGINS` | 允许的跨域来源 | ✅ |
| `FRONTEND_URL` | 前端地址 | ✅ |
| `PLUGIN_DATA_DIR` | 插件数据目录（可选） | ❌ |

### 插件目录配置（可选）

如果设置了 `PLUGIN_DATA_DIR`，下载的预设会自动保存到插件目录：

```env
PLUGIN_DATA_DIR=/path/to/AstrBot/data/plugin_data/astrbot_plugin_chuanhuatong
```

未设置时，预设会以 JSON 文件形式下载，需手动保存。

## 🔧 故障排查

### 服务无法启动

1. 检查端口占用：
```bash
sudo netstat -tlnp | grep -E '8000|5173'
```

2. 查看日志：
```bash
docker-compose logs backend
docker-compose logs frontend
```

### 无法访问

1. 检查防火墙：
```bash
sudo ufw status
sudo ufw allow 8000/tcp
sudo ufw allow 5173/tcp
```

2. 检查服务状态：
```bash
docker-compose ps
```

### GitHub OAuth 失败

1. 检查 `.env` 配置是否正确
2. 检查回调 URL 是否与 GitHub 配置一致
3. 查看后端日志获取详细错误

### 预览图不显示

1. 检查上传目录权限
2. 查看后端日志

## 📝 API 文档

启动后端服务后，访问以下地址查看 API 文档：

- Swagger UI: `http://your-domain:8000/docs`
- ReDoc: `http://your-domain:8000/redoc`

## 🛠️ 技术栈

### 后端
- **FastAPI** - 现代 Python Web 框架
- **SQLAlchemy** - ORM 数据库操作
- **SQLite** - 轻量级数据库
- **Pillow** - 图片处理
- **JWT** - 身份认证

### 前端
- **React 18** - UI 框架
- **TypeScript** - 类型安全
- **Vite** - 构建工具
- **Tailwind CSS** - 样式框架
- **React Router** - 路由管理

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 许可证

MIT License

## 👤 作者

- GitHub: [@bvzrays](https://github.com/bvzrays)

## 🔗 相关链接

- [传话筒插件](https://github.com/bvzrays/astrbot_plugin_chuanhuatong)
- [AstrBot](https://github.com/AstrBot-Dev/AstrBot)

---

**⭐ 如果这个项目对你有帮助，请给个 Star！**
