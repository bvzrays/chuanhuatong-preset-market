"""预设相关 API"""
import json
import os
import re
from pathlib import Path
from typing import List, Optional
from uuid import uuid4
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Query
from fastapi.responses import FileResponse, JSONResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, desc, asc
from sqlalchemy.orm import selectinload
from pydantic import BaseModel

from app.database import get_db
from app.models import Preset, User, Like, Comment
from app.auth import get_current_user, get_optional_user
from app.preview import generate_preview_image

router = APIRouter(prefix="/api/presets", tags=["presets"])


class PresetCreate(BaseModel):
    name: str
    description: Optional[str] = None
    layout: dict
    is_public: bool = True


class PresetUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    layout: Optional[dict] = None
    is_public: Optional[bool] = None


def sanitize_slug(name: str) -> str:
    """生成安全的 slug"""
    slug = re.sub(r'[^\w\s-]', '', name.lower())
    slug = re.sub(r'[-\s]+', '-', slug)
    return slug[:200]


@router.get("")
async def list_presets(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    sort: str = Query("latest", regex="^(latest|popular|likes)$"),
    search: Optional[str] = None,
    db: AsyncSession = Depends(get_db),
    current_user: Optional[User] = Depends(get_optional_user),
):
    """获取预设列表"""
    query = select(Preset).where(Preset.is_public == True)
    
    if search:
        query = query.where(Preset.name.contains(search))
    
    # 排序
    if sort == "latest":
        query = query.order_by(desc(Preset.created_at))
    elif sort == "popular":
        query = query.order_by(desc(Preset.download_count))
    elif sort == "likes":
        query = query.order_by(desc(Preset.like_count))
    
    # 分页
    total_result = await db.execute(select(func.count()).select_from(query.subquery()))
    total = total_result.scalar()
    
    query = query.offset((page - 1) * page_size).limit(page_size)
    result = await db.execute(query.options(selectinload(Preset.author)))
    presets = result.scalars().all()
    
    # 检查用户是否已点赞
    user_liked_preset_ids = set()
    if current_user:
        likes_result = await db.execute(
            select(Like.preset_id).where(Like.user_id == current_user.id)
        )
        user_liked_preset_ids = set(likes_result.scalars().all())
    
    return {
        "items": [
            {
                "id": p.id,
                "name": p.name,
                "slug": p.slug,
                "description": p.description,
                "preview_image": p.preview_image,
                "author": {
                    "id": p.author.id,
                    "username": p.author.username,
                    "avatar_url": p.author.avatar_url,
                },
                "download_count": p.download_count,
                "like_count": p.like_count,
                "comment_count": p.comment_count,
                "is_liked": p.id in user_liked_preset_ids,
                "created_at": p.created_at.isoformat() if p.created_at else None,
            }
            for p in presets
        ],
        "total": total,
        "page": page,
        "page_size": page_size,
    }


@router.get("/{preset_id}")
async def get_preset(
    preset_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: Optional[User] = Depends(get_optional_user),
):
    """获取预设详情"""
    result = await db.execute(
        select(Preset)
        .where(Preset.id == preset_id)
        .options(selectinload(Preset.author))
    )
    preset = result.scalar_one_or_none()
    
    if not preset:
        raise HTTPException(status_code=404, detail="预设不存在")
    
    if not preset.is_public and (not current_user or preset.author_id != current_user.id):
        raise HTTPException(status_code=403, detail="无权访问")
    
    # 检查是否已点赞
    is_liked = False
    if current_user:
        like_result = await db.execute(
            select(Like).where(
                Like.preset_id == preset_id,
                Like.user_id == current_user.id
            )
        )
        is_liked = like_result.scalar_one_or_none() is not None
    
    layout = json.loads(preset.layout) if isinstance(preset.layout, str) else preset.layout
    
    return {
        "id": preset.id,
        "name": preset.name,
        "slug": preset.slug,
        "description": preset.description,
        "layout": layout,
        "preview_image": preset.preview_image,
        "author": {
            "id": preset.author.id,
            "username": preset.author.username,
            "avatar_url": preset.author.avatar_url,
        },
        "download_count": preset.download_count,
        "like_count": preset.like_count,
        "comment_count": preset.comment_count,
        "is_liked": is_liked,
        "is_owner": current_user and preset.author_id == current_user.id,
        "created_at": preset.created_at.isoformat() if preset.created_at else None,
        "updated_at": preset.updated_at.isoformat() if preset.updated_at else None,
    }


@router.post("")
async def create_preset(
    preset_data: PresetCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """创建预设"""
    # 生成 slug
    base_slug = sanitize_slug(preset_data.name)
    slug = base_slug
    counter = 1
    while True:
        result = await db.execute(select(Preset).where(Preset.slug == slug))
        if result.scalar_one_or_none() is None:
            break
        slug = f"{base_slug}-{counter}"
        counter += 1
    
    # 创建预设
    preset = Preset(
        name=preset_data.name,
        slug=slug,
        description=preset_data.description,
        layout=json.dumps(preset_data.layout, ensure_ascii=False),
        author_id=current_user.id,
        is_public=preset_data.is_public,
    )
    
    # 生成预览图
    try:
        preview_path = await generate_preview_image(preset_data.layout)
        preset.preview_image = preview_path
    except Exception as e:
        print(f"生成预览图失败: {e}")
    
    db.add(preset)
    await db.commit()
    await db.refresh(preset)
    
    return {
        "id": preset.id,
        "name": preset.name,
        "slug": preset.slug,
        "message": "预设创建成功",
    }


@router.put("/{preset_id}")
async def update_preset(
    preset_id: int,
    preset_data: PresetUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """更新预设"""
    result = await db.execute(select(Preset).where(Preset.id == preset_id))
    preset = result.scalar_one_or_none()
    
    if not preset:
        raise HTTPException(status_code=404, detail="预设不存在")
    
    if preset.author_id != current_user.id:
        raise HTTPException(status_code=403, detail="无权修改")
    
    if preset_data.name is not None:
        preset.name = preset_data.name
    if preset_data.description is not None:
        preset.description = preset_data.description
    if preset_data.layout is not None:
        preset.layout = json.dumps(preset_data.layout, ensure_ascii=False)
        # 重新生成预览图
        try:
            preview_path = await generate_preview_image(preset_data.layout)
            preset.preview_image = preview_path
        except Exception as e:
            print(f"生成预览图失败: {e}")
    if preset_data.is_public is not None:
        preset.is_public = preset_data.is_public
    
    await db.commit()
    await db.refresh(preset)
    
    return {"message": "预设更新成功"}


@router.delete("/{preset_id}")
async def delete_preset(
    preset_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """删除预设"""
    result = await db.execute(select(Preset).where(Preset.id == preset_id))
    preset = result.scalar_one_or_none()
    
    if not preset:
        raise HTTPException(status_code=404, detail="预设不存在")
    
    if preset.author_id != current_user.id:
        raise HTTPException(status_code=403, detail="无权删除")
    
    await db.delete(preset)
    await db.commit()
    
    return {"message": "预设删除成功"}


@router.get("/{preset_id}/download")
async def download_preset(
    preset_id: int,
    db: AsyncSession = Depends(get_db),
):
    """下载预设"""
    result = await db.execute(select(Preset).where(Preset.id == preset_id))
    preset = result.scalar_one_or_none()
    
    if not preset:
        raise HTTPException(status_code=404, detail="预设不存在")
    
    if not preset.is_public:
        raise HTTPException(status_code=403, detail="预设未公开")
    
    # 增加下载计数
    preset.download_count += 1
    await db.commit()
    
    # 构建预设 JSON
    layout = json.loads(preset.layout) if isinstance(preset.layout, str) else preset.layout
    preset_json = {
        "name": preset.name,
        "slug": preset.slug,
        "saved_at": datetime.utcnow().isoformat(timespec="seconds") + "Z",
        "layout": layout,
    }
    
    # 如果配置了插件目录，直接保存到插件目录
    plugin_data_dir = os.getenv("PLUGIN_DATA_DIR")
    if plugin_data_dir:
        preset_dir = Path(plugin_data_dir) / "presets"
        try:
            preset_dir.mkdir(parents=True, exist_ok=True)
            preset_file = preset_dir / f"{preset.slug}.json"
            preset_file.write_text(
                json.dumps(preset_json, ensure_ascii=False, indent=2),
                encoding="utf-8"
            )
            return JSONResponse({
                "message": "预设已保存到插件目录",
                "path": str(preset_file),
                "preset": preset_json,
            })
        except PermissionError as e:
            # 权限错误
            print(f"保存到插件目录失败（权限错误）: {e}")
        except Exception as e:
            # 其他错误
            print(f"保存到插件目录失败: {e}")
    
    # 否则返回 JSON 文件下载
    return JSONResponse(
        content=preset_json,
        headers={
            "Content-Disposition": f'attachment; filename="{preset.slug}.json"',
            "Content-Type": "application/json; charset=utf-8"
        }
    )


@router.post("/{preset_id}/like")
async def toggle_like(
    preset_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """点赞/取消点赞"""
    result = await db.execute(select(Preset).where(Preset.id == preset_id))
    preset = result.scalar_one_or_none()
    
    if not preset:
        raise HTTPException(status_code=404, detail="预设不存在")
    
    # 检查是否已点赞
    like_result = await db.execute(
        select(Like).where(
            Like.preset_id == preset_id,
            Like.user_id == current_user.id
        )
    )
    like = like_result.scalar_one_or_none()
    
    if like:
        # 取消点赞
        await db.delete(like)
        preset.like_count = max(0, preset.like_count - 1)
        await db.commit()
        return {"liked": False, "like_count": preset.like_count}
    else:
        # 点赞
        like = Like(preset_id=preset_id, user_id=current_user.id)
        db.add(like)
        preset.like_count += 1
        await db.commit()
        return {"liked": True, "like_count": preset.like_count}

