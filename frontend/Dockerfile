# 构建阶段
FROM node:18-alpine as build

WORKDIR /app

# 构建参数
ARG VITE_API_URL=http://localhost:8000
ARG USE_CHINA_MIRROR=false

# 设置环境变量
ENV VITE_API_URL=$VITE_API_URL

# 配置 npm 使用国内镜像源（可选）
RUN if [ "$USE_CHINA_MIRROR" = "true" ]; then \
    npm config set registry https://registry.npmmirror.com; \
    fi

# 复制 package 文件
COPY package*.json ./

# 安装依赖
RUN npm ci --only=production=false

# 复制源代码
COPY . .

# 构建应用
RUN npm run build

# 生产阶段
FROM nginx:alpine

# 安装 curl 用于健康检查
RUN apk add --no-cache curl

# 复制构建产物
COPY --from=build /app/dist /usr/share/nginx/html

# 复制 nginx 配置
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost/ || exit 1

CMD ["nginx", "-g", "daemon off;"]

