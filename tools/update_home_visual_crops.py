"""Inspect original PNG alpha bounds and update fitting metadata, never pixels."""
import csv
import math
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
table = ROOT / 'config/tables/home_visuals.csv'
rows = list(csv.reader(table.open(encoding='utf-8-sig', newline='')))
assert rows[0][6:10] == ['crop_left', 'crop_top', 'crop_width', 'crop_height']
missing = []
for row in rows[3:]:
    path = ROOT / row[3].removeprefix('res://')
    if not path.exists():
        missing.append(row[0])
        continue
    with Image.open(path) as image:
        assert image.mode == 'RGBA', path
        width, height = image.size
        bounds = image.getchannel('A').point(lambda a: 255 if a >= 16 else 0).getbbox()
        assert bounds, path
        left, top, right, bottom = bounds
        left, top = max(0, left-2), max(0, top-2)
        right, bottom = min(width, right+2), min(height, bottom+2)
        row[6:10] = [f'{n:.6f}' for n in (left/width, top/height, (right-left)/width, (bottom-top)/height)]
        if row[1] != 'castle':
            # Equal visible area per tier, not equal whitespace or long-side size.
            visible_pixels = sum(image.getchannel('A').histogram()[16:])
            target_area = 10000 + 500 * (int(row[2]) - 1)
            scale = min(math.sqrt(target_area / visible_pixels), 185 / (right-left), 162 / (bottom-top))
            row[4:6] = [str(round((right-left)*scale)), str(round((bottom-top)*scale))]
with table.open('w', encoding='utf-8', newline='') as output:
    csv.writer(output, lineterminator='\n').writerows(rows)
print('Home visual metadata updated; missing:', missing)
