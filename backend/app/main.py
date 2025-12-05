"""主应用入口"""
import os
from pathlib import Path
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from dotenv import load_dotenv

from app.database import init_db
from app.api import presets, comments, auth, users

load_dotenv()

app = FastAPI(
    title="传话筒预设市场",
    description="传话筒插件的预设分享平台",
    version="1.0.0",
)

# CORS 配置
CORS_ORIGINS = os.getenv("CORS_ORIGINS", "http://localhost:5173,http://localhost:3000").split(",")
app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 静态文件服务
UPLOAD_DIR = Path(os.getenv("UPLOAD_DIR", "./uploads"))
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=str(UPLOAD_DIR)), name="uploads")

# 注册路由
app.include_router(auth.router)
app.include_router(presets.router)
app.include_router(comments.router)
app.include_router(users.router)


@app.on_event("startup")
async def startup_event():
    """启动时初始化数据库"""
    await init_db()
    print("=" * 50)
    print("✅ 数据库初始化完成")
    print(f"📁 上传目录: {UPLOAD_DIR.absolute()}")
    plugin_dir = os.getenv("PLUGIN_DATA_DIR")
    if plugin_dir:
        print(f"📦 插件目录: {plugin_dir}")
    else:
        print("⚠️  未配置插件目录，下载功能将返回 JSON 文件")
    print("=" * 50)


@app.get("/")
async def root():
    """根路径"""
    return {
        "message": "传话筒预设市场 API",
        "version": "1.0.0",
    }


@app.get("/health")
async def health():
    """健康检查"""
    return {"status": "ok"}

