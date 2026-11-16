#!/usr/bin/env python3
"""Draw the README's graphics from the project's own data, fonts and palette.

    python3 scripts/make_readme_art.py      # writes docs/media/{hero,spec,design-language,year-wheel}.png

Everything drawn here is real: the outlines come from App/Content/annotations.json, the colours
from App/Palette.swift and LiturgicalTint, the dates from the same church-calendar rules the app
uses (ChurchCalendar.swift), the type from App/Fonts. Nothing is invented for the picture.
"""
from __future__ import annotations

import datetime as dt
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
MEDIA = ROOT / "docs/media"
PAINTING = ROOT / "docs/reference/met-11.53-DP-19630-001-4000x3349.jpg"

# App/Palette.swift
IVORY = (237, 230, 214)
GOLD = (184, 156, 94)
STONE = (153, 143, 128)
INK = (12, 11, 10)
# LiturgicalTint.rgb
TINTS = {"violet": (158, 133, 204), "gold": (255, 230, 173), "red": (235, 122, 107), "green": (153, 204, 148)}


def font(name: str, size: int, style: str = "Regular") -> ImageFont.FreeTypeFont:
    f = ImageFont.truetype(str(ROOT / "App/Fonts" / name), size)
    try:
        f.set_variation_by_name(style)
    except (OSError, ValueError):
        pass
    return f


def title(size: int, style: str = "Regular") -> ImageFont.FreeTypeFont:
    return font("CormorantGaramond-Variable.ttf", size, style)


def text(size: int, italic: bool = False) -> ImageFont.FreeTypeFont:
    return font("EBGaramond-Italic-Variable.ttf" if italic else "EBGaramond-Variable.ttf", size)


def tracked(d: ImageDraw.ImageDraw, xy: tuple[float, float], s: str, f, fill, tracking: float) -> float:
    """Letter-spaced text (small caps labels); returns the end x."""
    x, y = xy
    for ch in s:
        d.text((x, y), ch, font=f, fill=fill)
        x += d.textlength(ch, font=f) + tracking
    return x


def outlines() -> dict[str, list[tuple[float, float]]]:
    lib = json.loads((ROOT / "App/Content/annotations.json").read_text())
    return {a["id"]: [(p["x"], p["y"]) for p in a["outline"]] for a in lib["annotations"] if a.get("outline")}


def glow_lines(size: tuple[int, int], polys: list[list[tuple[float, float]]], color, width: int, blur: float) -> Image.Image:
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for p in polys:
        d.line(p + [p[0]], fill=color + (255,), width=width, joint="curve")
    halo = layer.filter(ImageFilter.GaussianBlur(blur))
    return Image.alpha_composite(halo, layer)


# ---------------------------------------------------------------- hero

def hero() -> None:
    W, H = 2400, 1000
    img = Image.new("RGB", (W, H), INK)
    ph = H - 120
    pw = round(ph * 1.2)
    paint = Image.open(PAINTING).convert("RGB").resize((pw, ph), Image.LANCZOS)
    x0, y0 = W - pw - 90, 60
    # The room is dark; only light reveals the cloth. Darken it, then let Christ's light find him.
    dark = paint.point(lambda v: int(v * 0.22))
    outs = outlines()
    mask = Image.new("L", (pw, ph), 0)
    ImageDraw.Draw(mask).polygon([(x * pw, y * ph) for x, y in outs["christ"]], fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(28))
    lit = Image.composite(paint.point(lambda v: int(v * 0.9)), dark, mask)
    img.paste(lit, (x0, y0))
    polys = [[(x0 + x * pw, y0 + y * ph) for x, y in pts] for k, pts in outs.items() if k != "christ"]
    lines = glow_lines((W, H), polys, GOLD, 2, 5)
    img = Image.alpha_composite(img.convert("RGBA"), Image.eval(lines, lambda v: v)).convert("RGB")
    d = ImageDraw.Draw(img)
    lx = 110
    tracked(d, (lx, 250), "A PROJECTION-MAPPED TAPESTRY", text(26), STONE, 6)
    d.text((lx, 300), "The Wilderness", font=title(150, "Light"), fill=IVORY)
    d.text((lx, 500), "Light, cloth, and a painting", font=text(46, italic=True), fill=IVORY)
    d.text((lx, 556), "five hundred years old.", font=text(46, italic=True), fill=IVORY)
    d.line([(lx, 660), (lx + 120, 660)], fill=GOLD, width=2)
    d.text((lx, 690), "Moretto da Brescia, Christ in the Wilderness, c. 1515–20", font=text(28), fill=STONE)
    d.text((lx, 730), "60 × 50 in print  ·  Apple TV + projector  ·  iPhone", font=text(28), fill=STONE)
    img.save(MEDIA / "hero.jpg", quality=88)


# ---------------------------------------------------------------- spec drawing

def dim_h(d, x1, x2, y, label, f, color):
    d.line([(x1, y), (x2, y)], fill=color, width=2)
    for x in (x1, x2):
        d.line([(x, y - 14), (x, y + 14)], fill=color, width=2)
    for x, s in ((x1, 1), (x2, -1)):
        d.polygon([(x, y), (x + 16 * s, y - 6), (x + 16 * s, y + 6)], fill=color)
    w = d.textlength(label, font=f)
    d.rectangle([(x1 + x2) / 2 - w / 2 - 12, y - 20, (x1 + x2) / 2 + w / 2 + 12, y + 20], fill=INK)
    d.text(((x1 + x2) / 2 - w / 2, y - 18), label, font=f, fill=color)


def dim_v(d, y1, y2, x, label, f, color):
    d.line([(x, y1), (x, y2)], fill=color, width=2)
    for y in (y1, y2):
        d.line([(x - 14, y), (x + 14, y)], fill=color, width=2)
    for y, s in ((y1, 1), (y2, -1)):
        d.polygon([(x, y), (x - 6, y + 16 * s), (x + 6, y + 16 * s)], fill=color)
    w = d.textlength(label, font=f)
    d.rectangle([x - w / 2 - 10, (y1 + y2) / 2 - 22, x + w / 2 + 10, (y1 + y2) / 2 + 22], fill=INK)
    d.text((x - w / 2, (y1 + y2) / 2 - 18), label, font=f, fill=color)


def spec() -> None:
    W, H = 2400, 1500
    img = Image.new("RGB", (W, H), INK)
    d = ImageDraw.Draw(img)
    # drafting grid
    for x in range(0, W, 60):
        d.line([(x, 0), (x, H)], fill=(24, 22, 20))
    for y in range(0, H, 60):
        d.line([(0, y), (W, y)], fill=(24, 22, 20))
    # The tapestry, front elevation: 60 × 50 in at 15 px per inch.
    s = 15
    tx, ty, tw, th = 300, 220, 60 * s, 50 * s
    d.rectangle([tx, ty, tx + tw, ty + th], outline=IVORY, width=3)
    outs = outlines()
    polys = [[(tx + x * tw, ty + y * th) for x, y in pts] for pts in outs.values()]
    img = Image.alpha_composite(img.convert("RGBA"), glow_lines((W, H), polys, GOLD, 2, 3)).convert("RGB")
    d = ImageDraw.Draw(img)
    lab = text(30)
    dim_h(d, tx, tx + tw, ty - 90, "60 in", lab, STONE)
    dim_v(d, ty, ty + th, tx - 110, "50 in", lab, STONE)
    # canvas units: the app draws in a 1200 × 1000 space, 20 units to the inch
    d.text((tx, ty + th + 30), "Artwork space 1200 × 1000 units  ·  20 units per inch  ·  2 in calm margin for type",
           font=text(26, italic=True), fill=STONE)
    # 2 in text margin, dashed
    m = 2 * s
    for i in range(tx + m, tx + tw - m, 24):
        d.line([(i, ty + m), (i + 12, ty + m)], fill=(90, 82, 70), width=1)
        d.line([(i, ty + th - m), (i + 12, ty + th - m)], fill=(90, 82, 70), width=1)
    # Projector, Apple TV, phone (side schematic to the right)
    px, py = 1560, 560
    d.rounded_rectangle([px, py, px + 220, py + 110], radius=14, outline=IVORY, width=3)
    d.ellipse([px + 20, py + 25, px + 80, py + 85], outline=IVORY, width=3)
    d.text((px + 100, py + 30), "Projector", font=text(30), fill=IVORY)
    # light cone back to the cloth
    cone = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(cone).polygon([(px + 20, py + 55), (tx + tw, ty), (tx + tw, ty + th)], fill=IVORY + (22,))
    img = Image.alpha_composite(img.convert("RGBA"), cone).convert("RGB")
    d = ImageDraw.Draw(img)
    d.line([(px + 20, py + 55), (tx + tw, ty)], fill=(120, 110, 95), width=1)
    d.line([(px + 20, py + 55), (tx + tw, ty + th)], fill=(120, 110, 95), width=1)
    ax, ay = 1640, 820
    d.rounded_rectangle([ax, ay, ax + 140, ay + 60], radius=12, outline=IVORY, width=3)
    d.text((ax + 170, ay + 8), "Apple TV  ·  draws the light", font=text(30), fill=IVORY)
    d.line([(ax + 70, ay), (ax + 70, py + 110)], fill=STONE, width=2)
    d.text((ax + 82, py + 125), "HDMI", font=text(22), fill=STONE)
    hx, hy = 1660, 1010
    d.rounded_rectangle([hx, hy, hx + 70, hy + 140], radius=14, outline=IVORY, width=3)
    d.text((hx + 100, hy + 30), "iPhone  ·  guides it from the sofa", font=text(30), fill=IVORY)
    for r in (40, 64, 88):
        d.arc([hx + 35 - r, hy - r, hx + 35 + r, hy + r], 220, 320, fill=GOLD, width=2)
    d.text((hx + 100, hy + 80), "Bonjour + TCP on the home network, no cloud", font=text(24, italic=True), fill=STONE)
    # notes column
    nx, ny = 1560, 220
    tracked(d, (nx, ny), "CONSTRAINTS", text(24), GOLD, 5)
    notes = ["The projector can only add light.", "No wall beside the cloth: every word sits on it.",
             "A hanging cloth is never flat: 8-point warp.", "Read from the sofa, in a dark room."]
    for i, n in enumerate(notes):
        d.text((nx, ny + 50 + i * 46), f"{i + 1}   {n}", font=text(30), fill=IVORY)
    # title block
    bx, by, bw, bh = W - 900, H - 210, 840, 160
    d.rectangle([bx, by, bx + bw, by + bh], outline=STONE, width=2)
    d.line([(bx, by + 70), (bx + bw, by + 70)], fill=STONE, width=1)
    d.line([(bx + 520, by + 70), (bx + 520, by + bh)], fill=STONE, width=1)
    d.text((bx + 20, by + 14), "THE WILDERNESS  ·  SYSTEM ELEVATION", font=title(38, "Medium"), fill=IVORY)
    d.text((bx + 20, by + 84), "Drawn  M. McCoy", font=text(26), fill=STONE)
    d.text((bx + 20, by + 118), "Scale  NTS  ·  outlines to scale", font=text(26), fill=STONE)
    d.text((bx + 540, by + 84), "Sheet  1 of 1", font=text(26), fill=STONE)
    d.text((bx + 540, by + 118), "Nov 2026", font=text(26), fill=STONE)
    img.save(MEDIA / "spec.png", optimize=True)


# ---------------------------------------------------------------- design language

def design_language() -> None:
    W, H = 2400, 1100
    img = Image.new("RGB", (W, H), INK)
    d = ImageDraw.Draw(img)
    x = 110
    tracked(d, (x, 90), "DESIGN LANGUAGE", text(26), GOLD, 6)
    swatches = [("Ivory", IVORY, "#EDE6D6", "type and light"), ("Gold", GOLD, "#B89C5E", "outlines, the chosen"),
                ("Stone", STONE, "#998F80", "citations, quiet labels"), ("Black", (0, 0, 0), "#000000", "everywhere else: no light")]
    for i, (n, c, hx, role) in enumerate(swatches):
        sx = x + i * 290
        d.rounded_rectangle([sx, 160, sx + 240, 400], radius=10, fill=c, outline=(60, 56, 50), width=2)
        d.text((sx, 420), n, font=title(44, "Medium"), fill=IVORY)
        d.text((sx, 474), hx, font=text(26), fill=STONE)
        d.text((sx, 510), role, font=text(24, italic=True), fill=STONE)
    # type
    ty = 620
    d.text((x, ty), "Jesus Christ", font=title(96), fill=IVORY)
    d.text((x, ty + 120), "Cormorant Garamond  ·  titles  ·  56 pt on a 1200-unit canvas", font=text(26), fill=STONE)
    d.text((x, ty + 190), "He chose to be hungry and tired, as we are.", font=text(44, italic=True), fill=IVORY)
    d.text((x, ty + 250), "EB Garamond  ·  text  ·  scaled to fit its calm zone, never below the sofa floor", font=text(26), fill=STONE)
    # rules
    rx = 1360
    tracked(d, (rx, 90), "RULES THE LIGHT OBEYS", text(26), GOLD, 6)
    rules = [("Only add light.", "Black is the absence of light; there is no shadow to draw."),
             ("Never leave the cloth.", "Every word sits on the canvas, in a calm, dark zone."),
             ("Move like breath.", "Nothing cuts. Cross-fades of seconds, drifts of tens of seconds."),
             ("Grade every claim.", "Documented, likely or read from the painting: the wall says which."),
             ("Let it be quiet.", "At rest the wall breathes; the rare moments stay rare.")]
    for i, (h, b) in enumerate(rules):
        y = 160 + i * 150
        d.text((rx, y), f"{i + 1}", font=title(64, "Light"), fill=GOLD)
        d.text((rx + 70, y + 4), h, font=title(46, "Medium"), fill=IVORY)
        d.text((rx + 70, y + 64), b, font=text(28), fill=STONE)
    img.save(MEDIA / "design-language.png", optimize=True)


# ---------------------------------------------------------------- year wheel

def easter(y: int) -> dt.date:
    a, b, c = y % 19, y // 100, y % 100
    d_, e = b // 4, b % 4
    f = (b + 8) // 25
    g = (b - f + 1) // 3
    h = (19 * a + b - d_ - g + 15) % 30
    i, k = c // 4, c % 4
    l = (32 + 2 * e + 2 * i - h - k) % 7
    m = (a + 11 * h + 22 * l) // 451
    month = (h + l - 7 * m + 114) // 31
    return dt.date(y, month, (h + l - 7 * m + 114) % 31 + 1)


def advent_sunday(y: int) -> dt.date:
    xmas = dt.date(y, 12, 25)
    back = 7 if xmas.isoweekday() == 7 else xmas.isoweekday()
    return xmas - dt.timedelta(days=back + 21)


def thanksgiving(y: int) -> dt.date:
    first = dt.date(y, 11, 1)
    return first + dt.timedelta(days=(3 - first.weekday()) % 7 + 21)


def year_wheel() -> None:
    W = H = 1800
    img = Image.new("RGB", (W, H), INK)
    d = ImageDraw.Draw(img)
    cx, cy, R = W / 2, H / 2 + 30, 620
    start = dt.date(2026, 11, 1)  # the wheel runs Nov 2026 – Oct 2027, starting at the top

    def ang(day: dt.date) -> float:
        return -90 + (day - start).days / 365 * 360

    def arc(a: dt.date, b: dt.date, r: float, w: int, color) -> None:
        d.arc([cx - r, cy - r, cx + r, cy + r], ang(a), ang(b) if b > a else ang(b) + 0.01, fill=color, width=w)

    # month ring
    for m in range(12):
        day = dt.date(2026 + (10 + m) // 12, (10 + m) % 12 + 1, 1)
        a = math.radians(ang(day))
        d.line([(cx + (R + 40) * math.cos(a), cy + (R + 40) * math.sin(a)), (cx + (R + 70) * math.cos(a), cy + (R + 70) * math.sin(a))], fill=STONE, width=2)
        mid = math.radians(ang(day + dt.timedelta(days=15)))
        label = day.strftime("%b").upper()
        f = text(28)
        w = d.textlength(label, font=f)
        d.text((cx + (R + 120) * math.cos(mid) - w / 2, cy + (R + 120) * math.sin(mid) - 16), label, font=f, fill=STONE)
    d.ellipse([cx - R - 40, cy - R - 40, cx + R + 40, cy + R + 40], outline=(50, 46, 40), width=2)
    # liturgical tint ring (the background wash's colour through the year)
    tg, adv, ash, eas = thanksgiving(2026), advent_sunday(2026), easter(2027) - dt.timedelta(days=46), easter(2027)
    palm, pent = eas - dt.timedelta(days=7), eas + dt.timedelta(days=49)
    xmas, epiph = dt.date(2026, 12, 25), dt.date(2027, 1, 6)
    end = dt.date(2027, 10, 31)
    ring = [(start, adv, "green"), (adv, xmas, "violet"), (xmas, epiph + dt.timedelta(days=1), "gold"),
            (epiph + dt.timedelta(days=1), ash, "green"), (ash, palm, "violet"), (palm, palm + dt.timedelta(days=1), "red"),
            (palm + dt.timedelta(days=1), eas, "violet"), (eas, pent, "gold"), (pent, pent + dt.timedelta(days=1), "red"),
            (pent + dt.timedelta(days=1), end, "green")]
    for a, b, t in ring:
        arc(a, b, R, 34, TINTS[t])
    # what appears on the wall, inner rings
    events = [(tg - dt.timedelta(days=10), tg + dt.timedelta(days=1), R - 80, "Thanksgiving turkey", (196, 120, 70)),
              (adv, xmas, R - 140, "Advent candles", IVORY),
              (dt.date(2026, 12, 1), epiph + dt.timedelta(days=1), R - 200, "Christmas hats, snow, star", (200, 70, 60)),
              (ash, eas, R - 140, "Lent: day n of 40", IVORY),
              (eas, eas + dt.timedelta(days=1), R - 200, "Easter dawn", TINTS["gold"])]
    for a, b, r, label, color in events:
        arc(a, b, r, 18, color)
    # centre: title, then a legend, so no label crosses an arc
    t = "The year on the wall"
    f = title(64, "Light")
    w = d.textlength(t, font=f)
    d.text((cx - w / 2, cy - 250), t, font=f, fill=IVORY)
    sub = "November 2026 to October 2027"
    f2 = text(28, italic=True)
    d.text((cx - d.textlength(sub, font=f2) / 2, cy - 165), sub, font=f2, fill=STONE)
    legend = [(196, 120, 70), "Thanksgiving turkey: 16 to 26 Nov"], [IVORY, "Advent candles, then Lent's day n of 40"], \
             [(200, 70, 60), "Christmas hats, snow and star: 1 Dec to 6 Jan"], [TINTS["gold"], "Easter dawn: Easter morning"]
    lx, ly = cx - 300, cy - 80
    f3 = text(30)
    for i, (color, label) in enumerate(legend):
        y = ly + i * 56
        d.line([(lx, y + 20), (lx + 50, y + 20)], fill=color, width=10)
        d.text((lx + 72, y), label, font=f3, fill=IVORY)
    note = "Outer ring: the background wash, tinted by the church year"
    d.text((cx - d.textlength(note, font=f2) / 2, ly + 4 * 56 + 30), note, font=f2, fill=STONE)
    img.save(MEDIA / "year-wheel.png", optimize=True)


if __name__ == "__main__":
    hero(); spec(); design_language(); year_wheel()
    for n in ("hero.jpg", "spec.png", "design-language.png", "year-wheel.png"):
        print(MEDIA / n)
