"""认证相关 API"""
from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import RedirectResponse
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_db
from app.auth import get_or_create_user_from_github, create_access_token, get_current_user
from app.models import User
import os

router = APIRouter(prefix="/api/auth", tags=["auth"])

GITHUB_CLIENT_ID = os.getenv("GITHUB_CLIENT_ID")
GITHUB_REDIRECT_URI = os.getenv("GITHUB_REDIRECT_URI", "http://localhost:8000/api/auth/github/callback")
FRONTEND_URL = os.getenv("FRONTEND_URL", "http://localhost:5173")


@router.get("/github")
async def github_login():
    """GitHub OAuth 登录入口"""
    if not GITHUB_CLIENT_ID:
        raise HTTPException(status_code=500, detail="GitHub OAuth 未配置")
    
    auth_url = (
        f"https://github.com/login/oauth/authorize"
        f"?client_id={GITHUB_CLIENT_ID}"
        f"&redirect_uri={GITHUB_REDIRECT_URI}"
        f"&scope=read:user user:email"
    )
    return RedirectResponse(url=auth_url)


@router.get("/github/callback")
async def github_callback(
    code: str = Query(...),
    db: AsyncSession = Depends(get_db),
):
    """GitHub OAuth 回调"""
    try:
        user = await get_or_create_user_from_github(code, db)
        token = create_access_token(data={"sub": user.id})
        
        # 重定向到前端，携带 token
        return RedirectResponse(
            url=f"{FRONTEND_URL}/auth/callback?token={token}"
        )
    except Exception as e:
        return RedirectResponse(
            url=f"{FRONTEND_URL}/auth/callback?error={str(e)}"
        )


@router.get("/me")
async def get_me(current_user: User = Depends(get_current_user)):
    """获取当前用户信息"""
    return {
        "id": current_user.id,
        "username": current_user.username,
        "avatar_url": current_user.avatar_url,
        "email": current_user.email,
    }


@router.post("/logout")
async def logout():
    """登出（前端删除 token 即可）"""
    return {"message": "登出成功"}

