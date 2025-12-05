"""预设预览图生成"""
import json
import os
from pathlib import Path
from typing import Dict, Any, Optional
from PIL import Image, ImageDraw, ImageFont
import tempfile

UPLOAD_DIR = Path(os.getenv("UPLOAD_DIR", "./uploads"))
PREVIEW_DIR = UPLOAD_DIR / "previews"
PREVIEW_DIR.mkdir(parents=True, exist_ok=True)


async def generate_preview_image(layout: Dict[str, Any]) -> Optional[str]:
    """根据布局配置生成预览图"""
    try:
        # 获取画布尺寸
        canvas_width = layout.get("canvas_width", 1600)
        canvas_height = layout.get("canvas_height", 600)
        
        # 创建画布
        canvas = Image.new("RGB", (canvas_width, canvas_height), color=layout.get("background_color", "#05060a"))
        draw = ImageDraw.Draw(canvas)
        
        # 绘制文本框（简化版）
        box_left = layout.get("box_left", 0)
        box_top = layout.get("box_top", 0)
        box_width = layout.get("box_width", canvas_width)
        box_height = layout.get("box_height", canvas_height)
        
        # 绘制文本框背景
        text_bg = layout.get("text_bg", "rgba(0,0,0,0.52)")
        if text_bg.startswith("rgba"):
            # 解析 rgba
            rgba = text_bg.replace("rgba(", "").replace(")", "").split(",")
            r, g, b = int(rgba[0]), int(rgba[1]), int(rgba[2])
            alpha = float(rgba[3]) if len(rgba) > 3 else 0.52
            # 创建半透明层
            overlay = Image.new("RGBA", (int(box_width), int(box_height)), (r, g, b, int(alpha * 255)))
            canvas.paste(overlay, (int(box_left), int(box_top)), overlay)
        else:
            draw.rectangle(
                [int(box_left), int(box_top), int(box_left + box_width), int(box_top + box_height)],
                fill=text_bg
            )
        
        # 绘制示例文本
        text_color = layout.get("text_color", "#ffffff")
        font_size = layout.get("font_size", 56)
        try:
            # 尝试加载字体
            font_path = layout.get("body_font", "")
            if font_path and Path(font_path).exists():
                font = ImageFont.truetype(font_path, font_size)
            else:
                font = ImageFont.load_default()
        except:
            font = ImageFont.load_default()
        
        sample_text = "这是一个预设预览示例"
        text_x = int(box_left + layout.get("padding", 28))
        text_y = int(box_top + layout.get("padding", 28))
        draw.text((text_x, text_y), sample_text, fill=text_color, font=font)
        
        # 保存预览图
        preview_filename = f"preview_{hash(json.dumps(layout, sort_keys=True))}.png"
        preview_path = PREVIEW_DIR / preview_filename
        canvas.save(preview_path, "PNG")
        
        return f"/uploads/previews/{preview_filename}"
    except Exception as e:
        print(f"生成预览图失败: {e}")
        # 返回默认预览图路径
        return "/static/default-preview.png"

