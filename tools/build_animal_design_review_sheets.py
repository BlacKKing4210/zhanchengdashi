from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
ART_DIR = ROOT / "assets" / "card_art" / "animals"
OUTPUT_DIR = ROOT / "output" / "animal_design_review"


FONT_CANDIDATES = [
    Path("C:/Windows/Fonts/msyh.ttc"),
    Path("C:/Windows/Fonts/simhei.ttf"),
    Path("C:/Windows/Fonts/simsun.ttc"),
]


def load_font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        Path("C:/Windows/Fonts/msyhbd.ttc") if bold else Path("C:/Windows/Fonts/msyh.ttc"),
        *FONT_CANDIDATES,
    ]
    for path in candidates:
        if path.exists():
            try:
                return ImageFont.truetype(str(path), size)
            except OSError:
                pass
    return ImageFont.load_default()


TITLE_FONT = load_font(46, bold=True)
SUBTITLE_FONT = load_font(24)
CARD_NAME_FONT = load_font(27, bold=True)
CARD_META_FONT = load_font(18)
CARD_TEXT_FONT = load_font(21)
SMALL_FONT = load_font(16)


QUALITY_COLORS = {
    "绿色": "#30a66a",
    "蓝色": "#3287d3",
    "紫色": "#9b58d0",
    "金色": "#d79b1f",
}


ROLE_COLORS = {
    "轻型": "#547aa5",
    "普通": "#6d7480",
    "重型": "#8a6f3b",
    "远程": "#7b75aa",
    "突击": "#a65f59",
    "辅助": "#57906f",
    "运营": "#9a7a38",
    "反制": "#7b6f79",
}


ANIMALS = {
    "mouse": ("老鼠", "绿色", "轻型", "2只 1/1 快", "低血双单位；喂死亡流、撑数量。"),
    "ant": ("蚂蚁", "绿色", "轻型", "2只 1/1 快", "轻型友军+1攻；数量流发动机。"),
    "sparrow": ("麻雀", "绿色", "轻型", "2只 1/1 快", "优先建筑/后排；快攻拆建。"),
    "frog": ("青蛙", "绿色", "远程", "1只 1/2 中", "基础远程半血样板；怕贴脸。"),
    "rabbit": ("兔子", "绿色", "重型", "1只 1/4 中", "高血新手前排；保护后排。"),
    "chicken": ("鸡", "绿色", "远程", "1只 1/2 中", "廉价后排补伤；无技能。"),
    "pigeon": ("鸽子", "绿色", "轻型", "2只 1/1 快", "亡语返1金；死亡流接运营。"),
    "hamster": ("仓鼠", "绿色", "运营", "1只 0/3 中", "低攻经济位；需要保护。"),
    "snail": ("蜗牛", "绿色", "重型", "1只 1/6 慢", "纯肉盾；基础铁壁前排。"),
    "tadpole": ("蝌蚪", "绿色", "轻型", "2只 1/1 快", "最低血触发素材；骗攻击。"),
    "cat": ("猫", "绿色", "普通", "1只 2/3 快", "高攻近战；清小单位。"),
    "dog": ("狗", "绿色", "重型", "1只 1/5 中", "守线前排；保护远程辅助。"),
    "duck": ("鸭", "绿色", "轻型", "2只 1/1 快", "亡语补1个小鸭；持续群潮。"),
    "squirrel": ("松鼠", "绿色", "轻型", "2只 1/2 快", "抢连接点/建筑；快攻运营两用。"),
    "hedgehog": ("刺猬", "绿色", "反制", "1只 1/4 中", "低费抗轻型；无反伤。"),
    "turtle": ("乌龟", "绿色", "重型", "1只 1/6 慢", "慢速高血；可靠站线。"),
    "goat": ("山羊", "绿色", "辅助", "1只 0/4 中", "友军6+时全体+1血。"),
    "sheep": ("羊", "绿色", "辅助", "1只 0/3 中", "入场给附近1点护盾。"),
    "parrot": ("鹦鹉", "绿色", "远程", "1只 1/3 中", "普通后排；暂不复制。"),
    "fox": ("狐狸", "绿色", "突击", "2只 1/2 快", "优先远程/建筑；反远程快攻。"),
    "monkey": ("猴子", "蓝色", "辅助", "1只 1/4 中", "入场复制1个低费动物。"),
    "pig": ("猪", "蓝色", "运营", "1只 1/6 慢", "亡语返金币；经济前排。"),
    "deer": ("鹿", "蓝色", "突击", "1只 2/4 快", "入场短冲锋；拆建开口。"),
    "beaver": ("河狸", "蓝色", "运营", "1只 1/4 中", "周期修复最近建筑。"),
    "otter": ("水獭", "蓝色", "辅助", "1只 1/4 中", "中血辅助位；无技能。"),
    "penguin": ("企鹅", "蓝色", "辅助", "1只 1/4 中", "友军5+时全体+1攻。"),
    "peacock": ("孔雀", "蓝色", "远程", "1只 2/3 中", "中距离高攻；半血远程。"),
    "kangaroo": ("袋鼠", "蓝色", "突击", "1只 2/3 快", "优先远程/后排；切远程。"),
    "seal": ("海豹", "蓝色", "重型", "1只 1/7 慢", "蓝色纯肉盾；无技能。"),
    "swan": ("天鹅", "蓝色", "辅助", "1只 0/5 中", "续航承载辅助；高血。"),
    "wolf": ("狼", "蓝色", "普通", "1只 2/5 中", "高攻普通近战；稳定中线。"),
    "horse": ("马", "蓝色", "轻型", "2只 1/3 快", "快速补线；撑数量和速度。"),
    "cow": ("牛", "蓝色", "重型", "1只 1/8 慢", "运营护线；保护金矿。"),
    "zebra": ("斑马", "蓝色", "辅助", "2只 1/3 快", "不同类型3+时附近+1攻。"),
    "camel": ("骆驼", "蓝色", "重型", "1只 1/8 慢", "远征护矿前排；无回血。"),
    "dolphin": ("海豚", "蓝色", "远程", "1只 2/3 中", "均衡远程输出；半血。"),
    "falcon": ("猎鹰", "蓝色", "远程", "1只 2/3 中", "优先敌方远程；远程内战。"),
    "boar": ("野猪", "蓝色", "突击", "1只 2/5 快", "首次接敌眩晕；破口。"),
    "crane": ("鹤", "蓝色", "辅助", "1只 0/5 中", "周期治疗最近低血友军。"),
    "lynx": ("猞猁", "蓝色", "突击", "1只 3/4 快", "高速优先远程；刺客。"),
    "bear": ("熊", "紫色", "重型", "1只 2/10 慢", "入场震慑；反群潮开局。"),
    "tiger": ("老虎", "紫色", "突击", "1只 3/5 快", "高爆发突击；无技能。"),
    "lion": ("狮子", "紫色", "普通", "1只 2/7 中", "亡语返场1个小狮。"),
    "rhino": ("犀牛", "紫色", "重型", "1只 2/10 慢", "首次冲撞眩晕；开团。"),
    "hippo": ("河马", "紫色", "重型", "1只 2/11 慢", "超高生命；纯前排。"),
    "giraffe": ("长颈鹿", "紫色", "辅助", "1只 2/4 中", "附近远程/后排+1血。"),
    "gorilla": ("大猩猩", "紫色", "反制", "1只 2/8 中", "近战小范围震击；清轻型。"),
    "leopard": ("豹子", "紫色", "轻型", "3只 2/2 快", "三单位高速突击；怕AOE。"),
    "eagle": ("老鹰", "紫色", "远程", "1只 3/4 中", "优先斩杀低血目标。"),
    "crocodile": ("鳄鱼", "紫色", "反制", "1只 2/8 中", "对高生命目标+1伤。"),
    "elephant": ("大象", "金色", "重型", "1只 2/13 慢", "大范围+1血光环。"),
    "blue_whale": ("蓝鲸", "金色", "辅助", "1只 1/9 慢", "周期给2个友军护盾。"),
    "orca": ("虎鲸", "金色", "突击", "1只 3/7 快", "击杀后回复1血；收割。"),
    "shark": ("鲨鱼", "金色", "突击", "1只 4/7 快", "最高输出突击；无技能。"),
    "python": ("巨蟒", "金色", "反制", "1只 2/8 慢", "缠绕高生命或突击目标。"),
    "komodo_dragon": ("科莫多龙", "金色", "反制", "1只 3/9 中", "对高生命目标毒压血。"),
    "polar_bear": ("北极熊", "金色", "重型", "1只 2/13 慢", "低血获得冰盾。"),
    "silverback": ("银背猩猩", "金色", "反制", "1只 3/10 中", "友亡阈值后+1攻。"),
    "golden_eagle": ("金雕", "金色", "远程", "1只 3/4 中", "超远程标记远程/最远目标。"),
    "mammoth": ("猛犸象", "金色", "重型", "1只 2/14 慢", "入场给前排厚盾。"),
}


FLOWS = [
    {
        "id": "mouse_rush_death",
        "title": "鼠潮快攻 / 死亡数量",
        "subtitle": "双单位铺场、亡语和数量阈值互相放大；怕AOE和击杀成长。",
        "animals": [
            "mouse",
            "ant",
            "tadpole",
            "duck",
            "pigeon",
            "squirrel",
            "sparrow",
            "horse",
            "zebra",
            "monkey",
            "leopard",
            "silverback",
            "lion",
        ],
    },
    {
        "id": "fortress_wall",
        "title": "铁壁堡垒 / 慢速推进",
        "subtitle": "无技能高血前排和少数护盾/生命光环守线；怕反高生命和毒。",
        "animals": [
            "snail",
            "turtle",
            "dog",
            "rabbit",
            "hedgehog",
            "seal",
            "cow",
            "camel",
            "bear",
            "rhino",
            "hippo",
            "elephant",
            "polar_bear",
            "mammoth",
        ],
    },
    {
        "id": "eagle_eye_range",
        "title": "鹰眼远火 / 后排点杀",
        "subtitle": "远程半血或三分之一血，靠前排保护和目标偏好压制；怕快攻切入。",
        "animals": [
            "frog",
            "chicken",
            "parrot",
            "peacock",
            "dolphin",
            "falcon",
            "eagle",
            "golden_eagle",
            "giraffe",
            "rabbit",
            "dog",
            "seal",
        ],
    },
    {
        "id": "fang_assault",
        "title": "獠牙突击 / 拆建反远",
        "subtitle": "快单位优先远程、后排或建筑，制造窗口；怕重型堵路和控制。",
        "animals": [
            "fox",
            "sparrow",
            "squirrel",
            "deer",
            "kangaroo",
            "boar",
            "lynx",
            "tiger",
            "leopard",
            "orca",
            "shark",
            "cat",
            "wolf",
        ],
    },
    {
        "id": "pastoral_sustain",
        "title": "牧歌续航 / 护盾治疗",
        "subtitle": "少量护盾、治疗和后排生命增益赢长线换血；怕斩杀和突击点杀。",
        "animals": [
            "goat",
            "sheep",
            "otter",
            "swan",
            "crane",
            "blue_whale",
            "giraffe",
            "beaver",
            "chicken",
            "rabbit",
        ],
    },
    {
        "id": "gold_fruit_economy",
        "title": "金果运营 / 建筑资源",
        "subtitle": "用前排和修复保护金矿、防御塔与营地；怕快攻拆建和突击强开。",
        "animals": [
            "hamster",
            "pig",
            "beaver",
            "cow",
            "camel",
            "squirrel",
            "pigeon",
            "deer",
            "sheep",
            "duck",
        ],
    },
    {
        "id": "counter_endgame",
        "title": "反制终局 / AOE与克制",
        "subtitle": "清轻型、反远程、反高血、击杀收割组成克制网；各自也有明确短板。",
        "animals": [
            "cat",
            "hedgehog",
            "gorilla",
            "crocodile",
            "python",
            "komodo_dragon",
            "eagle",
            "golden_eagle",
            "orca",
            "bear",
            "rhino",
            "silverback",
            "lion",
            "shark",
        ],
    },
]


def text_width(draw: ImageDraw.ImageDraw, text: str, font: ImageFont.ImageFont) -> int:
    left, _, right, _ = draw.textbbox((0, 0), text, font=font)
    return right - left


def wrap_by_width(draw: ImageDraw.ImageDraw, text: str, font: ImageFont.ImageFont, max_width: int, max_lines: int) -> list[str]:
    lines: list[str] = []
    current = ""
    for char in text:
        if char in "，。；：、！？" and current:
            current += char
            continue
        candidate = current + char
        if current and text_width(draw, candidate, font) > max_width:
            lines.append(current)
            current = char
            if len(lines) == max_lines:
                break
        else:
            current = candidate
    if len(lines) < max_lines and current:
        lines.append(current)
    if len(lines) > max_lines:
        lines = lines[:max_lines]
    if len(lines) == max_lines and text_width(draw, lines[-1], font) > max_width:
        while lines[-1] and text_width(draw, lines[-1] + "...", font) > max_width:
            lines[-1] = lines[-1][:-1]
        lines[-1] += "..."
    return lines


def rounded_chip(draw: ImageDraw.ImageDraw, xy: tuple[int, int], text: str, fill: str, font: ImageFont.ImageFont) -> int:
    x, y = xy
    width = text_width(draw, text, font) + 22
    height = 27
    draw.rounded_rectangle((x, y, x + width, y + height), radius=10, fill=fill)
    draw.text((x + 11, y + 4), text, fill="#ffffff", font=font)
    return width


def paste_art(canvas: Image.Image, key: str, box: tuple[int, int, int, int]) -> None:
    path = ART_DIR / f"{key}.png"
    x1, y1, x2, y2 = box
    background = Image.new("RGBA", (x2 - x1, y2 - y1), "#f1f5f9")
    if path.exists():
        art = Image.open(path).convert("RGBA")
        art.thumbnail((x2 - x1 - 16, y2 - y1 - 16), Image.Resampling.LANCZOS)
        pos = ((background.width - art.width) // 2, (background.height - art.height) // 2)
        background.alpha_composite(art, pos)
    canvas.alpha_composite(background, (x1, y1))


def draw_card(canvas: Image.Image, draw: ImageDraw.ImageDraw, key: str, x: int, y: int, width: int, height: int) -> None:
    name, quality, role, meta, effect = ANIMALS[key]
    role_color = ROLE_COLORS.get(role, "#6d7480")
    quality_color = QUALITY_COLORS.get(quality, "#6d7480")
    draw.rounded_rectangle((x, y, x + width, y + height), radius=18, fill="#ffffff", outline="#cad5e1", width=2)
    draw.rounded_rectangle((x, y, x + width, y + 12), radius=8, fill=role_color)

    art_size = 126
    paste_art(canvas, key, (x + 18, y + 28, x + 18 + art_size, y + 28 + art_size))

    text_x = x + 158
    draw.text((text_x, y + 30), name, fill="#142033", font=CARD_NAME_FONT)
    chip_y = y + 70
    chip_w = rounded_chip(draw, (text_x, chip_y), quality, quality_color, SMALL_FONT)
    rounded_chip(draw, (text_x + chip_w + 8, chip_y), role, role_color, SMALL_FONT)
    draw.text((text_x, y + 108), meta, fill="#475569", font=CARD_META_FONT)

    effect_lines = wrap_by_width(draw, effect, CARD_TEXT_FONT, width - 42, 2)
    line_y = y + 172
    draw.line((x + 18, y + 162, x + width - 18, y + 162), fill="#e2e8f0", width=1)
    for line in effect_lines:
        draw.text((x + 20, line_y), line, fill="#1e293b", font=CARD_TEXT_FONT)
        line_y += 30


def build_sheet(flow: dict) -> Path:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    columns = 5
    card_width = 330
    card_height = 244
    gap = 18
    margin = 42
    header_height = 142
    animals = flow["animals"]
    rows = (len(animals) + columns - 1) // columns
    width = margin * 2 + columns * card_width + (columns - 1) * gap
    height = margin + header_height + rows * card_height + (rows - 1) * gap + 54

    canvas = Image.new("RGBA", (width, height), "#edf3f8")
    draw = ImageDraw.Draw(canvas)
    draw.rectangle((0, 0, width, 18), fill="#1f5f8b")
    draw.text((margin, 42), flow["title"], fill="#0f172a", font=TITLE_FONT)
    draw.text((margin, 96), flow["subtitle"], fill="#475569", font=SUBTITLE_FONT)

    for index, key in enumerate(animals):
        col = index % columns
        row = index // columns
        x = margin + col * (card_width + gap)
        y = margin + header_height + row * (card_height + gap)
        draw_card(canvas, draw, key, x, y, card_width, card_height)

    footer = "当前图片来自 assets/card_art/animals。动物可重复出现在不同流派中，便于按配合关系审阅。"
    draw.text((margin, height - 38), footer, fill="#64748b", font=SMALL_FONT)

    output = OUTPUT_DIR / f"{flow['id']}.png"
    canvas.convert("RGB").save(output, quality=95)
    return output


def main() -> None:
    for flow in FLOWS:
        path = build_sheet(flow)
        print(path.relative_to(ROOT).as_posix())


if __name__ == "__main__":
    main()
