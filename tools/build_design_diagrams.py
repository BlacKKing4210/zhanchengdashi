from __future__ import annotations

from dataclasses import dataclass
from html import escape
from pathlib import Path
from xml.etree.ElementTree import Element, SubElement, tostring

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "docs" / "diagrams"
OUTPUT_DIR = ROOT / "output" / "diagrams"


@dataclass(frozen=True)
class Box:
    id: str
    label: str
    x: int
    y: int
    w: int
    h: int
    fill: str = "#FFFFFF"
    stroke: str = "#1F2937"


@dataclass(frozen=True)
class Edge:
    source: str
    target: str
    label: str = ""


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    candidates = [
        Path("C:/Windows/Fonts/NotoSansSC-VF.ttf"),
        Path("C:/Windows/Fonts/msyhbd.ttc" if bold else "C:/Windows/Fonts/msyh.ttc"),
        Path("C:/Windows/Fonts/simhei.ttf"),
    ]
    for path in candidates:
        if path.exists():
            return ImageFont.truetype(str(path), size=size)
    return ImageFont.load_default()


def hex_to_rgba(value: str) -> tuple[int, int, int, int]:
    value = value.lstrip("#")
    return (int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16), 255)


def wrap_text(draw: ImageDraw.ImageDraw, text: str, fnt: ImageFont.FreeTypeFont, max_width: int) -> list[str]:
    lines: list[str] = []
    for raw_line in text.split("\n"):
        line = ""
        for char in raw_line:
            candidate = line + char
            if draw.textbbox((0, 0), candidate, font=fnt)[2] <= max_width or line == "":
                line = candidate
            else:
                lines.append(line)
                line = char
        lines.append(line)
    return lines


def centered_text(
    draw: ImageDraw.ImageDraw,
    text: str,
    rect: tuple[int, int, int, int],
    size: int,
    fill: tuple[int, int, int, int],
    bold: bool = False,
) -> None:
    fnt = font(size, bold)
    max_width = rect[2] - rect[0] - 22
    lines = wrap_text(draw, text, fnt, max_width)
    line_height = size + 7
    total_h = line_height * len(lines)
    y = rect[1] + (rect[3] - rect[1] - total_h) / 2
    for line in lines:
        bbox = draw.textbbox((0, 0), line, font=fnt)
        x = rect[0] + (rect[2] - rect[0] - (bbox[2] - bbox[0])) / 2
        draw.text((x, y), line, font=fnt, fill=fill)
        y += line_height


def arrow(draw: ImageDraw.ImageDraw, start: tuple[int, int], end: tuple[int, int], color: tuple[int, int, int, int]) -> None:
    draw.line([start, end], fill=color, width=4)
    dx = end[0] - start[0]
    dy = end[1] - start[1]
    if abs(dx) >= abs(dy):
        direction = 1 if dx >= 0 else -1
        points = [(end[0], end[1]), (end[0] - 14 * direction, end[1] - 8), (end[0] - 14 * direction, end[1] + 8)]
    else:
        direction = 1 if dy >= 0 else -1
        points = [(end[0], end[1]), (end[0] - 8, end[1] - 14 * direction), (end[0] + 8, end[1] - 14 * direction)]
    draw.polygon(points, fill=color)


def draw_box(draw: ImageDraw.ImageDraw, box: Box, title: bool = False) -> None:
    shadow = (0, 0, 0, 42)
    fill = hex_to_rgba(box.fill)
    stroke = hex_to_rgba(box.stroke)
    rect = (box.x, box.y, box.x + box.w, box.y + box.h)
    shadow_rect = (box.x + 5, box.y + 6, box.x + box.w + 5, box.y + box.h + 6)
    draw.rounded_rectangle(shadow_rect, radius=8, fill=shadow)
    draw.rounded_rectangle(rect, radius=8, fill=fill, outline=stroke, width=3)
    centered_text(draw, box.label, rect, 22 if not title else 28, (31, 41, 55, 255), title)


def write_drawio(path: Path, diagram_name: str, boxes: list[Box], edges: list[Edge], width: int, height: int) -> None:
    mxfile = Element("mxfile", {"host": "app.diagrams.net", "type": "device"})
    diagram = SubElement(mxfile, "diagram", {"name": diagram_name})
    graph = SubElement(
        diagram,
        "mxGraphModel",
        {
            "dx": str(width),
            "dy": str(height),
            "grid": "1",
            "gridSize": "10",
            "guides": "1",
            "tooltips": "1",
            "connect": "1",
            "arrows": "1",
            "fold": "1",
            "page": "1",
            "pageScale": "1",
            "pageWidth": str(width),
            "pageHeight": str(height),
            "math": "0",
            "shadow": "0",
        },
    )
    root = SubElement(graph, "root")
    SubElement(root, "mxCell", {"id": "0"})
    SubElement(root, "mxCell", {"id": "1", "parent": "0"})
    for box in boxes:
        cell = SubElement(
            root,
            "mxCell",
            {
                "id": box.id,
                "value": escape(box.label).replace("\n", "<br>"),
                "style": (
                    "rounded=1;whiteSpace=wrap;html=1;fontFamily=Microsoft YaHei;"
                    f"fontSize=16;fillColor={box.fill};strokeColor={box.stroke};strokeWidth=2;"
                ),
                "vertex": "1",
                "parent": "1",
            },
        )
        SubElement(cell, "mxGeometry", {"x": str(box.x), "y": str(box.y), "width": str(box.w), "height": str(box.h), "as": "geometry"})
    for index, edge in enumerate(edges):
        cell = SubElement(
            root,
            "mxCell",
            {
                "id": f"edge_{index}",
                "value": escape(edge.label),
                "style": "edgeStyle=orthogonalEdgeStyle;rounded=1;orthogonalLoop=1;jettySize=auto;html=1;strokeWidth=2;endArrow=block;",
                "edge": "1",
                "parent": "1",
                "source": edge.source,
                "target": edge.target,
            },
        )
        SubElement(cell, "mxGeometry", {"relative": "1", "as": "geometry"})
    xml = tostring(mxfile, encoding="utf-8", xml_declaration=True)
    path.write_bytes(xml)


def build_gameplay_flow() -> None:
    width, height = 1600, 960
    boxes = [
        Box("start", "进入游戏\n读取配置与本地数据", 70, 110, 220, 100, "#DBEAFE", "#1D4ED8"),
        Box("lobby", "主界面\n段位 / 资源 / 编组预览", 370, 110, 240, 100, "#ECFDF5", "#15803D"),
        Box("deck", "编组页\n选 8 张动物卡", 700, 60, 220, 92, "#FEF3C7", "#D97706"),
        Box("gacha", "抽卡页\n消耗券获得碎片", 700, 185, 220, 92, "#FCE7F3", "#BE185D"),
        Box("match", "匹配对手\n同段位对战", 1000, 110, 220, 100, "#EDE9FE", "#7C3AED"),
        Box("battle", "战斗\n解锁地块 / 建筑产兵", 1300, 110, 240, 100, "#FEE2E2", "#DC2626"),
        Box("unlock", "地块揭示\n营地按编组与品质降级", 1300, 315, 240, 112, "#FFF7ED", "#EA580C"),
        Box("auto", "自动推进\n单位索敌与攻击", 1000, 315, 220, 100, "#E0F2FE", "#0284C7"),
        Box("result", "结算\n胜利券 x3 / 失败券 x1", 700, 335, 240, 100, "#DCFCE7", "#16A34A"),
        Box("save", "回到主界面\n继续编组 / 抽卡 / 再战", 370, 335, 240, 100, "#F1F5F9", "#475569"),
        Box("doc", "文档先行门禁\n规则 -> 图 -> 实现 -> 验证", 70, 335, 240, 100, "#FFFFFF", "#111827"),
    ]
    edges = [
        Edge("start", "lobby"),
        Edge("lobby", "deck", "调整阵容"),
        Edge("deck", "lobby"),
        Edge("lobby", "gacha", "补充卡牌"),
        Edge("gacha", "lobby"),
        Edge("lobby", "match", "匹配"),
        Edge("match", "battle"),
        Edge("battle", "unlock"),
        Edge("unlock", "auto"),
        Edge("auto", "battle", "持续推进"),
        Edge("auto", "result", "胜负触发"),
        Edge("result", "save"),
        Edge("save", "lobby"),
        Edge("doc", "lobby", "策划约束"),
    ]
    write_drawio(SOURCE_DIR / "current_gameplay_flow.drawio", "当前玩法流程图", boxes, edges, width, height)

    image = Image.new("RGBA", (width, height), "#F8FAFC")
    draw = ImageDraw.Draw(image)
    draw.text((60, 40), "当前玩法流程图（draw.io 源文件交付）", font=font(36, True), fill=(15, 23, 42, 255))
    draw.text((60, 82), "源文件：docs/diagrams/current_gameplay_flow.drawio", font=font(22), fill=(71, 85, 105, 255))
    for edge in edges:
        source = next(box for box in boxes if box.id == edge.source)
        target = next(box for box in boxes if box.id == edge.target)
        start = (source.x + source.w, source.y + source.h // 2)
        end = (target.x, target.y + target.h // 2)
        if target.x < source.x:
            start = (source.x, source.y + source.h // 2)
            end = (target.x + target.w, target.y + target.h // 2)
        if abs(target.y - source.y) > 120:
            start = (source.x + source.w // 2, source.y + source.h)
            end = (target.x + target.w // 2, target.y)
        arrow(draw, start, end, (51, 65, 85, 255))
    for box in boxes:
        draw_box(draw, box, box.id == "doc")
    image.save(OUTPUT_DIR / "current_gameplay_flow.png")


def draw_phone(draw: ImageDraw.ImageDraw, x: int, y: int, title: str, panels: list[tuple[str, str]]) -> None:
    w, h = 330, 620
    draw.rounded_rectangle((x + 8, y + 10, x + w + 8, y + h + 10), radius=30, fill=(0, 0, 0, 45))
    draw.rounded_rectangle((x, y, x + w, y + h), radius=30, fill=(238, 246, 255, 255), outline=(15, 23, 42, 255), width=4)
    draw.rounded_rectangle((x + 22, y + 22, x + w - 22, y + 82), radius=14, fill=(37, 99, 235, 255), outline=(15, 23, 42, 255), width=3)
    centered_text(draw, title, (x + 22, y + 22, x + w - 22, y + 82), 23, (255, 255, 255, 255), True)
    cursor = y + 108
    colors = ["#DCFCE7", "#FEF3C7", "#EDE9FE", "#FEE2E2", "#E0F2FE"]
    for index, (label, note) in enumerate(panels):
        fill = hex_to_rgba(colors[index % len(colors)])
        draw.rounded_rectangle((x + 28, cursor, x + w - 28, cursor + 84), radius=10, fill=fill, outline=(30, 41, 59, 255), width=2)
        centered_text(draw, label + "\n" + note, (x + 38, cursor + 8, x + w - 38, cursor + 76), 18, (31, 41, 55, 255), index == 0)
        cursor += 102
    draw.rounded_rectangle((x + 28, y + h - 76, x + w - 28, y + h - 28), radius=12, fill=(250, 204, 21, 255), outline=(30, 41, 59, 255), width=3)
    centered_text(draw, "底部导航 / 主按钮", (x + 28, y + h - 76, x + w - 28, y + h - 28), 18, (31, 41, 55, 255), True)


def build_ui_ue_wireflow() -> None:
    width, height = 1700, 920
    boxes = [
        Box("lobby", "主界面\n资源、段位、编组预览、匹配入口", 80, 180, 330, 620, "#DBEAFE", "#1D4ED8"),
        Box("deck", "编组页\n槽位、卡牌详情、升级、可用卡列表", 525, 180, 330, 620, "#FEF3C7", "#D97706"),
        Box("battle", "战斗页\n棋盘、资源、地块提示、选择面板", 970, 180, 330, 620, "#DCFCE7", "#15803D"),
        Box("result", "结算弹窗\n胜负、奖励、段位反馈、返回", 1415, 265, 220, 240, "#FCE7F3", "#BE185D"),
        Box("panel", "底部信息面板\n点击营地显示动物卡牌信息", 1415, 560, 220, 180, "#EDE9FE", "#7C3AED"),
    ]
    edges = [
        Edge("lobby", "deck", "编组"),
        Edge("deck", "lobby", "返回"),
        Edge("lobby", "battle", "匹配"),
        Edge("battle", "result", "胜负"),
        Edge("battle", "panel", "点选地块/营地"),
    ]
    write_drawio(SOURCE_DIR / "current_ui_ue_wireflow.drawio", "当前 UI/UE 线框交互图", boxes, edges, width, height)

    image = Image.new("RGBA", (width, height), "#F8FAFC")
    draw = ImageDraw.Draw(image)
    draw.text((70, 42), "当前 UI/UE 线框交互图（draw.io 源文件交付）", font=font(36, True), fill=(15, 23, 42, 255))
    draw.text((70, 86), "源文件：docs/diagrams/current_ui_ue_wireflow.drawio", font=font(22), fill=(71, 85, 105, 255))
    draw_phone(
        draw,
        80,
        180,
        "主界面",
        [("资源条", "金币 / 券"), ("段位卡片", "星级 / 胜负"), ("动物预览", "当前编组"), ("匹配按钮", "进入战斗")],
    )
    draw_phone(
        draw,
        525,
        180,
        "编组页",
        [("8 个槽位", "选择上阵卡"), ("卡牌详情", "攻击 / 生命 / 速度"), ("升级按钮", "碎片消耗"), ("卡牌列表", "未上阵卡")],
    )
    draw_phone(
        draw,
        970,
        180,
        "战斗页",
        [("顶部资源", "金币 / 券 / 时间"), ("六边形棋盘", "地块扩张"), ("品质建筑", "营地 / 箭塔"), ("底部面板", "卡牌信息")],
    )
    for start, end, label_y in [((410, 490), (525, 490), 454), ((855, 490), (970, 490), 454), ((1300, 390), (1415, 390), 354), ((1300, 660), (1415, 660), 624)]:
        arrow(draw, start, end, (51, 65, 85, 255))
    draw_box(draw, boxes[3])
    draw_box(draw, boxes[4])
    image.save(OUTPUT_DIR / "current_ui_ue_wireflow.png")


def main() -> None:
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    build_gameplay_flow()
    build_ui_ue_wireflow()


if __name__ == "__main__":
    main()
