#!/usr/bin/env python3
"""Generates the TEMPORARY placeholder textures of Dragon Ball: Infinite Legacy.

Every image here is procedural pixel art meant to be replaced by real art.
File names are referenced through dbil_core/config/theme.lua (HUD/FX) or by
node/item/race/enemy definitions, so replacing a file never needs code changes.

Usage: python3 tools/assets/gen_textures.py   (requires Pillow and numpy)
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "dbil"))
MODS = os.path.join(ROOT, "mods")
RNG = np.random.default_rng(1337)


def out(mod, name, img):
    path = os.path.join(MODS, mod, "textures", name)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def noise_tile(size, base, var, seed_scale=1.0, blotch=0):
    """Pixel noise around a base color. var = +- brightness variation."""
    base = np.array(hex_rgb(base), dtype=float)
    n = RNG.uniform(-var, var, (size, size, 1))
    if blotch:
        # Low-frequency variation for a less uniform look.
        coarse = RNG.uniform(-blotch, blotch, (size // 4, size // 4, 1))
        coarse = np.kron(coarse, np.ones((4, 4, 1)))
        n = n + coarse
    arr = np.clip(base + n * seed_scale, 0, 255).astype(np.uint8)
    return Image.fromarray(arr, "RGB").convert("RGBA")


def shade(color, f):
    r, g, b = hex_rgb(color) if isinstance(color, str) else color
    return (int(min(255, r * f)), int(min(255, g * f)), int(min(255, b * f)))


# ---------------------------------------------------------------- terrain ----

def terrain():
    stone = noise_tile(16, "#8a8c91", 14, blotch=8)
    d = ImageDraw.Draw(stone)
    for _ in range(5):
        x, y = RNG.integers(0, 16, 2)
        d.line([(x, y), (x + RNG.integers(-3, 4), y + RNG.integers(1, 4))], fill=(96, 98, 104, 255))
    out("dbil_world", "dbil_stone.png", stone)

    dirt = noise_tile(16, "#7a5638", 16, blotch=8)
    out("dbil_world", "dbil_dirt.png", dirt)

    grass = noise_tile(16, "#58a83c", 18, blotch=10)
    out("dbil_world", "dbil_grass_top.png", grass)
    side = dirt.copy()
    px = side.load()
    gp = grass.load()
    for x in range(16):
        h = 3 + RNG.integers(0, 3)
        for y in range(h):
            px[x, y] = gp[x, y]
    out("dbil_world", "dbil_grass_side.png", side)

    out("dbil_world", "dbil_sand.png", noise_tile(16, "#e3cf8f", 12, blotch=6))
    gravel = noise_tile(16, "#9a948a", 30)
    out("dbil_world", "dbil_gravel.png", gravel)

    # Wasteland: layered reddish rock like the canyons in the series.
    rock = Image.new("RGBA", (16, 16))
    p = rock.load()
    bands = ["#b5633c", "#c9774a", "#a8573a", "#d08a5a", "#b86a42"]
    for y in range(16):
        band = hex_rgb(bands[(y // 3) % len(bands)])
        for x in range(16):
            v = RNG.uniform(-10, 10)
            p[x, y] = tuple(int(max(0, min(255, c + v))) for c in band) + (255,)
    out("dbil_world", "dbil_wasteland_rock.png", rock)
    soil = noise_tile(16, "#c7865a", 14, blotch=8)
    out("dbil_world", "dbil_wasteland_soil.png", soil)
    sside = rock.copy()
    sp = sside.load()
    so = soil.load()
    for x in range(16):
        for y in range(2 + RNG.integers(0, 2)):
            sp[x, y] = so[x, y]
    out("dbil_world", "dbil_wasteland_soil_side.png", sside)

    def water(color):
        img = noise_tile(16, color, 10, blotch=6)
        a = np.array(img)
        a[:, :, 3] = 180
        return Image.fromarray(a, "RGBA")
    out("dbil_world", "dbil_water.png", water("#2f6fd0"))
    out("dbil_world", "dbil_river_water.png", water("#3d86d8"))

    trunk = Image.new("RGBA", (16, 16))
    tp = trunk.load()
    for x in range(16):
        stripe = 1.0 if x % 4 else 0.8
        for y in range(16):
            tp[x, y] = shade("#7a5130", stripe * RNG.uniform(0.9, 1.08)) + (255,)
    out("dbil_world", "dbil_tree_trunk.png", trunk)
    top = Image.new("RGBA", (16, 16), hex_rgb("#a07850") + (255,))
    d = ImageDraw.Draw(top)
    for r, c in ((7, "#8c6640"), (5, "#a07850"), (3, "#8c6640"), (1, "#a07850")):
        d.ellipse([8 - r, 8 - r, 7 + r, 7 + r], outline=hex_rgb(c) + (255,))
    out("dbil_world", "dbil_tree_top.png", top)

    leaves = noise_tile(16, "#3f8f30", 26, blotch=12)
    la = np.array(leaves)
    holes = RNG.random((16, 16)) < 0.12
    la[holes, 3] = 0
    out("dbil_world", "dbil_leaves.png", Image.fromarray(la, "RGBA"))

    tuft = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(tuft)
    for i in range(7):
        x = 1 + i * 2 + RNG.integers(0, 2)
        h = RNG.integers(6, 14)
        d.line([(x, 15), (x + RNG.integers(-2, 3), 15 - h)], fill=shade("#5fb042", RNG.uniform(0.8, 1.15)) + (255,))
    out("dbil_world", "dbil_grass_tuft.png", tuft)

    # Arena: light stone tiles with grooves (tournament stage look).
    tile = noise_tile(16, "#dcd6c8", 8, blotch=4)
    d = ImageDraw.Draw(tile)
    d.line([(0, 0), (15, 0)], fill=hex_rgb("#a9a293") + (255,))
    d.line([(0, 0), (0, 15)], fill=hex_rgb("#a9a293") + (255,))
    d.line([(0, 8), (15, 8)], fill=hex_rgb("#bdb6a6") + (255,))
    d.line([(8, 0), (8, 8)], fill=hex_rgb("#bdb6a6") + (255,))
    d.line([(4, 8), (4, 15)], fill=hex_rgb("#bdb6a6") + (255,))
    d.line([(12, 8), (12, 15)], fill=hex_rgb("#bdb6a6") + (255,))
    out("dbil_world", "dbil_arena_tile.png", tile)
    trim = noise_tile(16, "#b5a98f", 8)
    d = ImageDraw.Draw(trim)
    d.rectangle([0, 0, 15, 15], outline=hex_rgb("#8a7f68") + (255,))
    d.rectangle([3, 3, 12, 12], outline=hex_rgb("#c8bca2") + (255,))
    out("dbil_world", "dbil_arena_trim.png", trim)


def enemy_nodes():
    top = noise_tile(16, "#5c4a33", 14, blotch=6)
    d = ImageDraw.Draw(top)
    for _ in range(4):
        x, y = RNG.integers(2, 14, 2)
        d.point([(x, y), (x + 1, y), (x, y - 1)], fill=hex_rgb("#7fe35a") + (255,))
    d.ellipse([5, 5, 10, 10], outline=hex_rgb("#3c7d2a") + (255,))
    out("dbil_enemies", "dbil_spawner_top.png", top)
    side = noise_tile(16, "#5c4a33", 14, blotch=6)
    d = ImageDraw.Draw(side)
    for x in range(0, 16, 3):
        d.line([(x, 0), (x + 1, 4)], fill=hex_rgb("#4caf3a") + (255,))
    out("dbil_enemies", "dbil_spawner_side.png", side)


# -------------------------------------------------------------------- HUD ----

def hud():
    fill = Image.new("RGBA", (1, 16))
    for y in range(16):
        t = y / 15
        v = int(255 * (1.0 - 0.35 * t)) if y > 2 else 255
        fill.putpixel((0, y), (v, v, v, 255))
    out("dbil_ui", "dbil_hud_bar_fill.png", fill)
    out("dbil_ui", "dbil_hud_bar_back.png", Image.new("RGBA", (1, 1), (8, 10, 18, 190)))
    frame = Image.new("RGBA", (3, 3), (255, 255, 255, 120))
    frame.putpixel((1, 1), (0, 0, 0, 0))
    out("dbil_ui", "dbil_hud_bar_frame.png", frame)

    panel = Image.new("RGBA", (32, 32), (14, 20, 36, 235))
    d = ImageDraw.Draw(panel)
    d.rectangle([0, 0, 31, 31], outline=(255, 160, 40, 255))
    d.rectangle([1, 1, 30, 30], outline=(60, 80, 130, 255))
    out("dbil_ui", "dbil_ui_panel.png", panel)


# --------------------------------------------------------------------- FX ----

def radial(size, inner, outer_alpha_power=2.0, core=0.0):
    img = Image.new("RGBA", (size, size))
    p = img.load()
    c = (size - 1) / 2
    for y in range(size):
        for x in range(size):
            r = math.hypot(x - c, y - c) / c
            a = max(0.0, 1.0 - r) ** outer_alpha_power
            w = 255
            if core and r < core:
                a = 1.0
            p[x, y] = (w, w, w, int(255 * min(1.0, a * inner)))
    return img


def fx():
    out("dbil_core", "dbil_fx_glow.png", radial(32, 1.4, 1.6))
    spark = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(spark)
    d.line([(8, 1), (8, 14)], fill=(255, 255, 255, 255))
    d.line([(1, 8), (14, 8)], fill=(255, 255, 255, 255))
    d.line([(4, 4), (11, 11)], fill=(255, 255, 255, 160))
    d.line([(11, 4), (4, 11)], fill=(255, 255, 255, 160))
    out("dbil_core", "dbil_fx_spark.png", spark)

    def smoke(seed_color):
        img = Image.new("RGBA", (32, 32))
        p = img.load()
        coarse = RNG.uniform(0.6, 1.0, (8, 8))
        for y in range(32):
            for x in range(32):
                r = math.hypot(x - 15.5, y - 15.5) / 15.5
                a = max(0.0, 1 - r) ** 1.2 * coarse[y // 4, x // 4]
                p[x, y] = seed_color + (int(200 * a),)
        return img
    out("dbil_core", "dbil_fx_smoke.png", smoke((235, 235, 235)))
    out("dbil_core", "dbil_fx_dust.png", smoke((225, 215, 195)))

    # Ki ball: bright core and soft halo (tinted with ^[multiply in game).
    ball = Image.new("RGBA", (64, 64))
    p = ball.load()
    for y in range(64):
        for x in range(64):
            r = math.hypot(x - 31.5, y - 31.5) / 31.5
            if r < 0.45:
                p[x, y] = (255, 255, 255, 255)
            else:
                a = max(0.0, 1 - (r - 0.45) / 0.55) ** 1.5
                p[x, y] = (230, 240, 255, int(255 * a))
    out("dbil_core", "dbil_fx_ki_ball.png", ball)
    wave = Image.new("RGBA", (64, 64))
    p = wave.load()
    for y in range(64):
        for x in range(64):
            r = math.hypot(x - 31.5, y - 31.5) / 31.5
            if r < 0.6:
                p[x, y] = (255, 255, 255, 255)
            else:
                a = max(0.0, 1 - (r - 0.6) / 0.4) ** 1.2
                p[x, y] = (255, 250, 230, int(255 * a))
    out("dbil_core", "dbil_fx_wave_core.png", wave)
    out("dbil_core", "dbil_blank.png", Image.new("RGBA", (1, 1), (0, 0, 0, 0)))


# ------------------------------------------------------------------ items ----

def items():
    fist = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(fist)
    skin, dark = hex_rgb("#f2c6a0"), hex_rgb("#b98a64")
    d.rounded_rectangle([3, 4, 12, 12], radius=2, fill=skin + (255,), outline=dark + (255,))
    for x in (5, 7, 9):
        d.line([(x, 5), (x, 8)], fill=dark + (255,))
    d.rectangle([2, 7, 4, 11], fill=skin + (255,), outline=dark + (255,))
    d.rectangle([5, 12, 11, 15], fill=hex_rgb("#2a4fa3") + (255,))
    out("dbil_input", "dbil_item_fists.png", fist)

    flight = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(flight)
    d.polygon([(1, 11), (8, 2), (15, 11), (8, 8)], fill=(170, 225, 255, 255), outline=(60, 130, 200, 255))
    d.line([(3, 14), (7, 12)], fill=(200, 240, 255, 200))
    d.line([(9, 12), (13, 14)], fill=(200, 240, 255, 200))
    out("dbil_input", "dbil_item_flight.png", flight)

    def orb(color, ring=None):
        img = radial(16, 1.6, 1.3, core=0.35)
        a = np.array(img).astype(float)
        col = np.array(hex_rgb(color), dtype=float)
        core_mask = a[:, :, 3] > 250
        a[:, :, :3] = np.where(core_mask[:, :, None], 255, col)
        img = Image.fromarray(a.astype(np.uint8), "RGBA")
        if ring:
            d = ImageDraw.Draw(img)
            d.ellipse([0, 0, 15, 15], outline=hex_rgb(ring) + (255,))
        return img
    out("dbil_input", "dbil_item_technique.png", orb("#7fd4ff", "#2b6aa8"))
    out("dbil_techniques", "dbil_tech_ki_blast.png", orb("#45b8ff", "#1e5f9a"))
    wave = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(wave)
    d.rectangle([0, 6, 9, 10], fill=(255, 230, 120, 200))
    d.rectangle([0, 7, 9, 9], fill=(255, 255, 230, 255))
    d.ellipse([7, 3, 15, 13], fill=(255, 226, 122, 255), outline=(200, 140, 30, 255))
    d.ellipse([9, 5, 13, 11], fill=(255, 255, 240, 255))
    out("dbil_techniques", "dbil_tech_energy_wave.png", wave)

    tr = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(tr)
    d.polygon([(8, 0), (11, 6), (16, 7), (11, 9), (12, 15), (8, 11), (4, 15), (5, 9), (0, 7), (5, 6)],
              fill=(255, 216, 74, 255), outline=(190, 120, 20, 255))
    d.ellipse([6, 6, 10, 10], fill=(255, 255, 230, 255))
    out("dbil_transformations", "dbil_item_transform.png", tr)

    senzu = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(senzu)
    d.ellipse([3, 5, 12, 11], fill=hex_rgb("#7cc24a") + (255,), outline=hex_rgb("#3f7a22") + (255,))
    d.line([(5, 7), (8, 6)], fill=(200, 255, 170, 255))
    out("dbil_items", "dbil_item_senzu.png", senzu)


# ------------------------------------------------------------------ skins ----
# 64x32 classic box layout (see tools/assets/gen_model.py).

def box_uv(u0, v0, w, h, d):
    """Rectangles (x0, y0, x1, y1) of each face for a box UV block."""
    return {
        "top": (u0 + d, v0, u0 + d + w, v0 + d),
        "bottom": (u0 + d + w, v0, u0 + d + 2 * w, v0 + d),
        "right": (u0, v0 + d, u0 + d, v0 + d + h),
        "front": (u0 + d, v0 + d, u0 + d + w, v0 + d + h),
        "left": (u0 + d + w, v0 + d, u0 + 2 * d + w, v0 + d + h),
        "back": (u0 + 2 * d + w, v0 + d, u0 + 2 * d + 2 * w, v0 + d + h),
    }


PARTS = {
    "head": (0, 0, 8, 8, 8),
    "body": (16, 16, 8, 12, 4),
    "arm": (40, 16, 4, 12, 4),
    "leg": (0, 16, 4, 12, 4),
}


def fill_part(img, part, color, var=6):
    p = img.load()
    for face, (x0, y0, x1, y1) in box_uv(*PARTS[part]).items():
        for y in range(y0, y1):
            for x in range(x0, x1):
                c = color(face, x - x0, y - y0) if callable(color) else color
                if c is None:
                    continue
                v = RNG.uniform(-var, var)
                p[x, y] = tuple(int(max(0, min(255, ch + v))) for ch in c[:3]) + (255,)


def face(img, eye_color, brow=(30, 20, 15), mouth=(150, 70, 60), angry=False):
    x0, y0, _, _ = box_uv(*PARTS["head"])["front"]
    p = img.load()
    for dx in (1, 5):
        p[x0 + dx, y0 + 4] = (255, 255, 255, 255)
        p[x0 + dx + 1, y0 + 4] = eye_color + (255,)
        p[x0 + dx, y0 + 3] = brow + (255,)
        p[x0 + dx + 1, y0 + 3] = brow + (255,)
        if angry:
            p[x0 + dx + (1 if dx == 1 else 0), y0 + 2] = brow + (255,)
    p[x0 + 3, y0 + 6] = mouth + (255,)
    p[x0 + 4, y0 + 6] = mouth + (255,)


def skin_human():
    img = Image.new("RGBA", (64, 32), (0, 0, 0, 0))
    skin = hex_rgb("#f2c6a0")
    gi, blue, belt = hex_rgb("#f08a24"), hex_rgb("#2a4fa3"), hex_rgb("#2a4fa3")
    hair = hex_rgb("#1b1b22")

    def head(f, x, y):
        if f in ("top", "back"):
            return hair
        if f in ("left", "right") and y < 3:
            return hair
        if f == "front" and y < 2:
            return hair
        return skin
    fill_part(img, "head", head)
    face(img, (25, 25, 30))

    def body(f, x, y):
        if y >= 9 and y <= 10 and f != "top":
            return belt
        if f == "front" and y < 4 and 2 <= x <= 5:
            return blue  # undershirt V
        return gi
    fill_part(img, "body", body)

    def arm(f, x, y):
        if y < 4:
            return gi
        if y >= 9:
            return blue  # wristband
        return skin
    fill_part(img, "arm", arm)

    def leg(f, x, y):
        if y >= 9:
            return blue  # boots
        return gi
    fill_part(img, "leg", leg)
    out("dbil_character", "dbil_skin_human.png", img)


def skin_saiyan():
    img = Image.new("RGBA", (64, 32), (0, 0, 0, 0))
    skin = hex_rgb("#e9b98f")
    suit, armor, pads = hex_rgb("#22305e"), hex_rgb("#efe9dc"), hex_rgb("#8a6a3a")
    hair = hex_rgb("#111118")

    def head(f, x, y):
        if f in ("top", "back"):
            return hair
        if f in ("left", "right") and y < 3:
            return hair
        if f == "front" and y < 2:
            return hair
        return skin
    fill_part(img, "head", head)
    face(img, (20, 20, 25), angry=True)

    def body(f, x, y):
        if y < 2 and f in ("front", "back"):
            return pads
        if y <= 8:
            return armor
        return suit
    fill_part(img, "body", body)

    def arm(f, x, y):
        if y < 3:
            return pads
        if y >= 8:
            return armor  # gloves
        return suit
    fill_part(img, "arm", arm)

    def leg(f, x, y):
        if y >= 8:
            return armor  # boots
        return suit
    fill_part(img, "leg", leg)
    out("dbil_character", "dbil_skin_saiyan.png", img)


def skin_saibaman():
    img = Image.new("RGBA", (64, 32), (0, 0, 0, 0))
    green, dark, vein = hex_rgb("#5fbf3c"), hex_rgb("#3f8a28"), hex_rgb("#7d5aa8")

    def any_part(f, x, y):
        if (x * 7 + y * 3) % 11 == 0:
            return vein
        if (x + y) % 5 == 0:
            return dark
        return green
    for part in PARTS:
        fill_part(img, part, any_part, var=10)
    x0, y0, _, _ = box_uv(*PARTS["head"])["front"]
    p = img.load()
    for dx in (1, 5):
        p[x0 + dx, y0 + 4] = (230, 30, 30, 255)
        p[x0 + dx + 1, y0 + 4] = (230, 30, 30, 255)
        p[x0 + dx, y0 + 3] = (20, 60, 15, 255)
        p[x0 + dx + 1, y0 + 3] = (20, 60, 15, 255)
    for dx in range(2, 6):
        p[x0 + dx, y0 + 6] = (30, 40, 20, 255)
    out("dbil_enemies", "dbil_enemy_saibaman.png", img)


def skin_dummy():
    img = Image.new("RGBA", (64, 32), (0, 0, 0, 0))
    burlap, stitch = hex_rgb("#c9a56b"), hex_rgb("#7a5a2e")

    def any_part(f, x, y):
        if (x % 4 == 0) and (y % 2 == 0):
            return stitch
        return burlap
    for part in PARTS:
        fill_part(img, part, any_part, var=12)
    x0, y0, x1, y1 = box_uv(*PARTS["body"])["front"]
    d = ImageDraw.Draw(img)
    d.ellipse([x0, y0 + 2, x1 - 1, y0 + 9], outline=(200, 40, 40, 255))
    d.point([((x0 + x1) // 2, y0 + 5), ((x0 + x1) // 2 - 1, y0 + 5)], fill=(200, 40, 40, 255))
    hx, hy, _, _ = box_uv(*PARTS["head"])["front"]
    d.line([(hx + 1, hy + 3), (hx + 2, hy + 4)], fill=(60, 40, 20, 255))
    d.line([(hx + 2, hy + 3), (hx + 1, hy + 4)], fill=(60, 40, 20, 255))
    d.line([(hx + 5, hy + 3), (hx + 6, hy + 4)], fill=(60, 40, 20, 255))
    d.line([(hx + 6, hy + 3), (hx + 5, hy + 4)], fill=(60, 40, 20, 255))
    out("dbil_enemies", "dbil_enemy_dummy.png", img)


def hair(name, base, highlight):
    img = Image.new("RGBA", (16, 16))
    p = img.load()
    for y in range(16):
        for x in range(16):
            c = base
            if (x + y * 2) % 7 == 0:
                c = highlight
            v = RNG.uniform(-8, 8)
            p[x, y] = tuple(int(max(0, min(255, ch + v))) for ch in c) + (255,)
    out("dbil_character", name, img)


def menu():
    icon = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(icon)
    d.ellipse([4, 4, 59, 59], fill=(255, 150, 20, 255), outline=(200, 90, 0, 255), width=3)
    d.ellipse([12, 10, 34, 28], fill=(255, 220, 160, 140))
    cx, cy = 32, 34
    # A red star, like on a Dragon Ball.
    pts = []
    for k in range(10):
        ang = -math.pi / 2 + k * math.pi / 5
        r = 14 if k % 2 == 0 else 6
        pts.append((cx + r * math.cos(ang), cy + r * math.sin(ang)))
    d.polygon(pts, fill=(220, 30, 30, 255))
    icon.save(os.path.join(ROOT, "menu", "icon.png"))
    header = Image.new("RGBA", (256, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(header)
    d.rounded_rectangle([0, 8, 255, 56], radius=10, fill=(15, 22, 40, 220), outline=(255, 150, 20, 255), width=3)
    header.paste(icon.resize((48, 48)), (8, 8), icon.resize((48, 48)))
    d.text((66, 18), "DRAGON BALL", fill=(255, 190, 40, 255))
    d.text((66, 34), "INFINITE LEGACY", fill=(255, 255, 255, 255))
    header.save(os.path.join(ROOT, "menu", "header.png"))


def main():
    terrain()
    enemy_nodes()
    hud()
    fx()
    items()
    skin_human()
    skin_saiyan()
    skin_saibaman()
    skin_dummy()
    hair("dbil_hair_black.png", (28, 26, 34), (60, 60, 80))
    hair("dbil_hair_saiyan.png", (18, 18, 26), (55, 60, 95))
    hair("dbil_hair_gold.png", (255, 214, 60), (255, 245, 170))
    menu()
    print("textures written under", MODS)


if __name__ == "__main__":
    main()
