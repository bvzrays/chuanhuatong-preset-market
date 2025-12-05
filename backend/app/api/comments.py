"""评论相关 API"""
from typing import List
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc
from sqlalchemy.orm import selectinload
from pydantic import BaseModel

from app.database import get_db
from app.models import Comment, Preset, User
from app.auth import get_current_user, get_optional_user

router = APIRouter(prefix="/api/comments", tags=["comments"])


class CommentCreate(BaseModel):
    content: str


class CommentResponse(BaseModel):
    id: int
    content: str
    preset_id: int
    author: dict
    created_at: str
    updated_at: str


@router.get("/preset/{preset_id}")
async def get_comments(
    preset_id: int,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
):
    """获取预设的评论列表"""
    # 检查预设是否存在
    preset_result = await db.execute(select(Preset).where(Preset.id == preset_id))
    preset = preset_result.scalar_one_or_none()
    if not preset:
        raise HTTPException(status_code=404, detail="预设不存在")
    
    # 获取评论
    query = (
        select(Comment)
        .where(Comment.preset_id == preset_id)
        .order_by(desc(Comment.created_at))
        .options(selectinload(Comment.author))
    )
    
    result = await db.execute(query.offset((page - 1) * page_size).limit(page_size))
    comments = result.scalars().all()
    
    return {
        "items": [
            {
                "id": c.id,
                "content": c.content,
                "preset_id": c.preset_id,
                "author": {
                    "id": c.author.id,
                    "username": c.author.username,
                    "avatar_url": c.author.avatar_url,
                },
                "created_at": c.created_at.isoformat() if c.created_at else None,
                "updated_at": c.updated_at.isoformat() if c.updated_at else None,
            }
            for c in comments
        ],
        "page": page,
        "page_size": page_size,
    }


@router.post("/preset/{preset_id}")
async def create_comment(
    preset_id: int,
    comment_data: CommentCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """创建评论"""
    # 检查预设是否存在
    preset_result = await db.execute(select(Preset).where(Preset.id == preset_id))
    preset = preset_result.scalar_one_or_none()
    if not preset:
        raise HTTPException(status_code=404, detail="预设不存在")
    
    if not comment_data.content.strip():
        raise HTTPException(status_code=400, detail="评论内容不能为空")
    
    # 创建评论
    comment = Comment(
        content=comment_data.content.strip(),
        preset_id=preset_id,
        author_id=current_user.id,
    )
    
    db.add(comment)
    preset.comment_count += 1
    await db.commit()
    await db.refresh(comment)
    await db.refresh(comment.author)
    
    return {
        "id": comment.id,
        "content": comment.content,
        "preset_id": comment.preset_id,
        "author": {
            "id": comment.author.id,
            "username": comment.author.username,
            "avatar_url": comment.author.avatar_url,
        },
        "created_at": comment.created_at.isoformat() if comment.created_at else None,
        "updated_at": comment.updated_at.isoformat() if comment.updated_at else None,
    }


@router.delete("/{comment_id}")
async def delete_comment(
    comment_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """删除评论"""
    result = await db.execute(select(Comment).where(Comment.id == comment_id))
    comment = result.scalar_one_or_none()
    
    if not comment:
        raise HTTPException(status_code=404, detail="评论不存在")
    
    if comment.author_id != current_user.id:
        raise HTTPException(status_code=403, detail="无权删除")
    
    # 减少评论计数
    preset_result = await db.execute(select(Preset).where(Preset.id == comment.preset_id))
    preset = preset_result.scalar_one_or_none()
    if preset:
        preset.comment_count = max(0, preset.comment_count - 1)
    
    await db.delete(comment)
    await db.commit()
    
    return {"message": "评论删除成功"}

