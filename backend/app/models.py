"""数据库模型"""
from sqlalchemy import Column, Integer, String, Text, DateTime, ForeignKey, Boolean
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.database import Base


class User(Base):
    """用户模型"""
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    github_id = Column(Integer, unique=True, index=True, nullable=False)
    username = Column(String(100), nullable=False, index=True)
    avatar_url = Column(String(500))
    email = Column(String(255))
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    presets = relationship("Preset", back_populates="author", cascade="all, delete-orphan")
    comments = relationship("Comment", back_populates="author", cascade="all, delete-orphan")
    likes = relationship("Like", back_populates="user", cascade="all, delete-orphan")


class Preset(Base):
    """预设模型"""
    __tablename__ = "presets"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(200), nullable=False, index=True)
    slug = Column(String(200), unique=True, nullable=False, index=True)
    description = Column(Text)
    layout = Column(Text, nullable=False)  # JSON 字符串
    preview_image = Column(String(500))  # 预览图路径
    author_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    download_count = Column(Integer, default=0)
    like_count = Column(Integer, default=0)
    comment_count = Column(Integer, default=0)
    is_public = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    author = relationship("User", back_populates="presets")
    comments = relationship("Comment", back_populates="preset", cascade="all, delete-orphan")
    likes = relationship("Like", back_populates="preset", cascade="all, delete-orphan")


class Comment(Base):
    """评论模型"""
    __tablename__ = "comments"

    id = Column(Integer, primary_key=True, index=True)
    content = Column(Text, nullable=False)
    preset_id = Column(Integer, ForeignKey("presets.id"), nullable=False)
    author_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    preset = relationship("Preset", back_populates="comments")
    author = relationship("User", back_populates="comments")


class Like(Base):
    """点赞模型"""
    __tablename__ = "likes"

    id = Column(Integer, primary_key=True, index=True)
    preset_id = Column(Integer, ForeignKey("presets.id"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    preset = relationship("Preset", back_populates="likes")
    user = relationship("User", back_populates="likes")

    __table_args__ = (
        {"sqlite_autoincrement": True},
    )

