# -*- coding: utf-8 -*-
import re
from pathlib import Path

raw = Path(r"C:\Users\yigit\Desktop\Projeler\kira-artisi-hesapla\store\live_smoke\21_home.xml").read_text(encoding="utf-8")
for m in re.finditer(r"<node [^>]+>", raw):
    s = m.group(0)
    d = re.search(r'content-desc="([^"]*)"', s)
    b = re.search(r'bounds="([^"]+)"', s)
    c = re.search(r'class="([^"]+)"', s)
    desc = d.group(1) if d else ""
    cls = c.group(1) if c else ""
    if "EditText" in cls or "Mevcut" in desc or "TextField" in cls:
        print(cls, "|", desc[:100].replace("\n", " | "), "|", b.group(1) if b else "")

# Also print all focusable clickable nodes with small height (inputs)
print("--- candidates ---")
for m in re.finditer(r"<node [^>]+>", raw):
    s = m.group(0)
    b = re.search(r"bounds=\"\[(\d+),(\d+)\]\[(\d+),(\d+)\]\"", s)
    if not b:
        continue
    x1, y1, x2, y2 = map(int, b.groups())
    h = y2 - y1
    w = x2 - x1
    if h < 120 and w > 400 and y1 > 500 and y1 < 1600 and 'focusable="true"' in s:
        d = re.search(r'content-desc="([^"]*)"', s)
        print(f"y={y1}-{y2} h={h} w={w} desc={(d.group(1)[:40] if d else '')!r}")
