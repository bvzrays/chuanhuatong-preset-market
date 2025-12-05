"""用户相关 API"""
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.models import User, Preset
from app.auth import get_current_user

router = APIRouter(prefix="/api/users", tags=["users"])


@router.get("/me/presets")
async def get_my_presets(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """获取当前用户的预设列表"""
    result = await db.execute(
        select(Preset)
        .where(Preset.author_id == current_user.id)
        .options(selectinload(Preset.author))
    )
    presets = result.scalars().all()
    
    return {
        "items": [
            {
                "id": p.id,
                "name": p.name,
                "slug": p.slug,
                "description": p.description,
                "preview_image": p.preview_image,
                "download_count": p.download_count,
                "like_count": p.like_count,
                "comment_count": p.comment_count,
                "is_public": p.is_public,
                "created_at": p.created_at.isoformat() if p.created_at else None,
            }
            for p in presets
        ]
    }

