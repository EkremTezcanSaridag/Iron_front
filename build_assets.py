#!/usr/bin/env python3
"""Compose Sığınak art from CC0 Kenney packs + Google Fonts (Barlow)."""
from __future__ import annotations

import math
import os
import random
import shutil
import struct
import wave
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent
KENNEY = Path("/tmp/kenney-mirror")
FONTS_SRC = Path("/tmp/assets-dl")
OUT = ROOT / "assets"

PAL = {
    "bg": (18, 16, 14),
    "earth": (62, 44, 32),
    "earth2": (42, 30, 22),
    "metal": (58, 62, 66),
    "amber": (224, 161, 74),
    "text": (242, 230, 208),
    "sage": (125, 154, 106),
    "water": (91, 163, 181),
    "rust": (196, 92, 62),
}


def load(path: Path) -> Image.Image:
    return Image.open(path).convert("RGBA")


def tint(im: Image.Image, color: tuple[int, int, int], amount: float = 0.35) -> Image.Image:
    overlay = Image.new("RGBA", im.size, color + (int(255 * amount),))
    base = im.copy()
    return Image.alpha_composite(base, Image.composite(overlay, Image.new("RGBA", im.size, (0, 0, 0, 0)), im.split()[-1]))


def paste(dst: Image.Image, src: Image.Image, xy: tuple[int, int], scale: float = 1.0) -> None:
    im = src if scale == 1.0 else src.resize(
        (max(1, int(src.width * scale)), max(1, int(src.height * scale))), Image.Resampling.NEAREST
    )
    dst.alpha_composite(im, xy)


def industrial(n: int) -> Image.Image:
    p = KENNEY / "kenney_platformerpack_industrial" / "PNG" / "Retina" / f"platformIndustrial_{n:03d}.png"
    return load(p)


def bit_tile(col: int, row: int, size: int = 64) -> Image.Image:
    sheet = load(KENNEY / "1bitpack_kenney_1.1" / "Tilesheet" / "colored_transparent_packed.png")
    tile = sheet.crop((col * 16, row * 16, col * 16 + 16, row * 16 + 16))
    return tile.resize((size, size), Image.Resampling.NEAREST)


def copy_fonts() -> None:
    dest = OUT / "fonts"
    dest.mkdir(parents=True, exist_ok=True)
    for name in [
        "Barlow-Regular.ttf",
        "Barlow-Medium.ttf",
        "Barlow-SemiBold.ttf",
        "Barlow-Bold.ttf",
        "BarlowCondensed-Regular.ttf",
        "BarlowCondensed-SemiBold.ttf",
        "BarlowCondensed-Bold.ttf",
    ]:
        shutil.copy2(FONTS_SRC / name, dest / name)


def copy_ui() -> None:
    dest = OUT / "art" / "ui"
    dest.mkdir(parents=True, exist_ok=True)
    src = KENNEY / "uipack_fixed" / "PNG"
    mapping = {
        "grey_panel.png": "panel.png",
        "grey_button00.png": "btn.png",
        "grey_button01.png": "btn_wide.png",
        "grey_button02.png": "btn_square.png",
        "grey_button03.png": "btn_alt.png",
        "grey_button05.png": "btn_small.png",
        "grey_box.png": "box.png",
        "grey_sliderDown.png": "slider.png",
        "grey_circle.png": "circle.png",
        "grey_tickWhite.png": "tick.png",
    }
    for src_name, dst_name in mapping.items():
        p = src / src_name
        if p.exists():
            im = load(p)
            # Recolor light Kenney greys toward bunker metal
            shutil.copy2(p, dest / f"raw_{dst_name}")
            dest.joinpath(dst_name).parent.mkdir(exist_ok=True)
            dark = recolor_ui(im)
            dark.save(dest / dst_name)
    # Pixel 9-slice
    nine = KENNEY / "pixeluipack" / "9-Slice" / "Colored"
    for name, dest_name in [("grey.png", "slice_panel.png"), ("yellow.png", "slice_amber.png"),
                            ("red.png", "slice_danger.png"), ("green.png", "slice_ok.png")]:
        im = load(nine / name)
        recolor_ui(im).save(dest / dest_name)
    # Game icons (white) for chrome
    gi = KENNEY / "gameicons" / "PNG" / "White" / "2x"
    for name in ["pause.png", "fastForward.png", "gear.png", "home.png", "locked.png",
                 "plus.png", "minus.png", "power.png", "save.png", "musicOn.png",
                 "audioOn.png", "question.png", "exclamation.png", "checkmark.png"]:
        p = gi / name
        if p.exists():
            load(p).save(dest / f"ico_{name}")


def recolor_ui(im: Image.Image) -> Image.Image:
    px = im.load()
    w, h = im.size
    out = im.copy()
    opx = out.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            # map light greys to dark bunker browns, keep highlights
            lum = (r + g + b) / 3
            t = lum / 255.0
            nr = int(28 + t * 70)
            ng = int(24 + t * 58)
            nb = int(20 + t * 48)
            opx[x, y] = (nr, ng, nb, a)
    return out


def extract_icons() -> None:
    dest = OUT / "art" / "icons"
    dest.mkdir(parents=True, exist_ok=True)
    # Kenney 1-bit packed 16px, 48 columns. Chosen by labeled atlas.
    picks = {
        "food": (33, 18),       # apple
        "water": (38, 11),      # blue flask
        "health": (40, 10),     # heart
        "medicine": (39, 11),   # potion
        "power": (45, 16),      # gear (overwritten by industrial light below)
        "scrap": (45, 16),      # gear
        "ammo": (41, 8),        # firearm
        "radio": (41, 16),      # device
        "person": (24, 1),
        "skull": (22, 10),
        "home": (42, 16),
        "moon": (37, 16),
        "sun": (40, 16),
        "shield": (32, 9),
        "bag": (34, 11),
        "alert": (40, 20),
        "door": (0, 8),
        "bed": (1, 8),
        "plant": (2, 0),
        "wrench": (34, 8),
        "star": (40, 14),
    }
    for name, (c, r) in picks.items():
        bit_tile(c, r, 96).save(dest / f"{name}.png")
    # Also tinted HUD chips
    colors = {
        "food": (222, 168, 72),
        "water": (86, 168, 196),
        "power": (232, 196, 86),
        "medicine": (86, 196, 140),
        "scrap": (176, 168, 160),
        "ammo": (196, 92, 62),
        "health": (220, 80, 80),
        "morale": (232, 176, 96),
    }
    for name, col in colors.items():
        src = dest / f"{name}.png"
        if not src.exists():
            continue
        im = load(src)
        # keep silhouette, recolor non-transparent to palette
        px = im.load()
        for y in range(im.height):
            for x in range(im.width):
                r, g, b, a = px[x, y]
                if a < 16:
                    continue
                lum = (r + g + b) / 3 / 255.0
                px[x, y] = (
                    min(255, int(col[0] * (0.45 + lum * 0.7))),
                    min(255, int(col[1] * (0.45 + lum * 0.7))),
                    min(255, int(col[2] * (0.45 + lum * 0.7))),
                    a,
                )
        im.save(dest / f"hud_{name}.png")
    # Cohesive industrial thumbnails for a few resources
    ind_icons = {"water": 90, "power": 39, "scrap": 43}
    for name, n in ind_icons.items():
        src = industrial(n)
        src.thumbnail((96, 96), Image.Resampling.LANCZOS)
        canvas = Image.new("RGBA", (96, 96), (0, 0, 0, 0))
        canvas.alpha_composite(src, ((96 - src.width) // 2, (96 - src.height) // 2))
        canvas.save(dest / f"{name}.png")
        canvas.save(dest / f"hud_{name}.png")


def compose_character(kind: str, dest: Path) -> None:
    base = KENNEY / "kenney_tooncharacters1" / kind / "PNG" / "Parts HD"
    body = load(base / "body.png")
    head = load(base / "head.png")
    arm = load(base / "arm.png")
    # legs optional
    leg = load(base / "leg.png") if (base / "leg.png").exists() else None
    canvas = Image.new("RGBA", (220, 320), (0, 0, 0, 0))
    # Approximate Kenney toon assembly
    if leg:
        paste(canvas, leg, (70, 210), 0.85)
        paste(canvas, leg.transpose(Image.Transpose.FLIP_LEFT_RIGHT), (110, 210), 0.85)
    paste(canvas, body, (50, 110), 0.9)
    paste(canvas, arm, (28, 130), 0.85)
    paste(canvas, arm.transpose(Image.Transpose.FLIP_LEFT_RIGHT), (142, 130), 0.85)
    paste(canvas, head, (48, 8), 0.72)
    bbox = canvas.getbbox()
    canvas = canvas.crop(bbox)
    canvas.save(dest)


def portraits() -> None:
    dest_p = OUT / "art" / "portraits"
    dest_c = OUT / "art" / "characters"
    dest_p.mkdir(parents=True, exist_ok=True)
    dest_c.mkdir(parents=True, exist_ok=True)
    kinds = [
        "Male person",
        "Female person",
        "Male adventurer",
        "Female adventurer",
        "Robot",
        "Zombie",
    ]
    rings = [(224, 161, 74), (91, 163, 181), (125, 154, 106), (196, 92, 62), (160, 140, 200), (90, 90, 90)]
    for i, kind in enumerate(kinds):
        head = load(KENNEY / "kenney_tooncharacters1" / kind / "PNG" / "Parts HD" / "head.png")
        # circular portrait
        size = 256
        canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        draw = ImageDraw.Draw(canvas)
        draw.ellipse((8, 8, size - 9, size - 9), fill=(32, 28, 24, 255), outline=rings[i] + (255,), width=8)
        target = int(size * 0.78)
        scale = target / max(head.width, head.height)
        h = head.resize((int(head.width * scale), int(head.height * scale)), Image.Resampling.LANCZOS)
        canvas.alpha_composite(h, ((size - h.width) // 2, (size - h.height) // 2 + 18))
        canvas.save(dest_p / f"p{i}.png")
        compose_character(kind, dest_c / f"c{i}.png")
        slug = kind.lower().replace(" ", "_")
        canvas.save(dest_p / f"{slug}.png")


def fill_rect(im: Image.Image, box, color) -> None:
    draw = ImageDraw.Draw(im)
    draw.rectangle(box, fill=color)


def tile_row(dst: Image.Image, tile: Image.Image, y: int, x0: int, x1: int, scale: float = 0.55) -> None:
    t = tile.resize((int(tile.width * scale), int(tile.height * scale)), Image.Resampling.LANCZOS)
    x = x0
    while x < x1:
        dst.alpha_composite(t, (x, y))
        x += t.width - 8


def make_room(kind: str, path: Path) -> None:
    w, h = 720, 280
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    # earth around the vault
    earth = Image.new("RGBA", (w, h), PAL["earth2"] + (255,))
    noise = Image.effect_noise((w, h), 28).convert("L")
    earth.putalpha(180)
    im.paste(Image.new("RGBA", (w, h), PAL["earth"] + (255,)))
    # inner chamber
    fill_rect(im, (18, 18, w - 18, h - 18), (38, 40, 44, 255))
    fill_rect(im, (26, 26, w - 26, h - 26), (48, 50, 54, 255))
    # floor
    floor_tile = industrial(111 if kind != "hydroponics" else 108)
    tile_row(im, floor_tile, h - 78, 26, w - 26, 0.42)
    # ceiling pipes
    try:
        tile_row(im, industrial(87), 22, 40, w - 50, 0.42)
    except Exception:
        pass

    props: list[tuple[int, tuple[int, int], float]] = []
    if kind == "living":
        props = [(43, (50, 90), 0.55), (44, (200, 90), 0.55), (43, (350, 90), 0.55),
                 (39, (520, 40), 0.7), (32, (560, 80), 0.55)]
        for i, x in enumerate((70, 220, 370)):
            paste(im, bit_tile(i % 3, 8, 88), (x, 70))
    elif kind == "hydroponics":
        props = [(108, (40, 90), 0.7), (109, (180, 90), 0.7), (108, (320, 90), 0.7),
                 (25, (40, 40), 0.8), (26, (200, 30), 0.8)]
        # 1-bit plants
        for i, x in enumerate(range(70, 620, 90)):
            paste(im, bit_tile(i % 6, 0, 72), (x, 88))
    elif kind == "water":
        props = [(90, (70, 70), 0.85), (91, (220, 70), 0.85), (100, (390, 60), 0.8),
                 (85, (540, 40), 0.7), (86, (600, 80), 0.7)]
    elif kind == "generator":
        props = [(67, (80, 70), 0.9), (68, (260, 110), 0.85), (69, (420, 110), 0.85),
                 (45, (520, 50), 0.7), (54, (40, 30), 0.8), (53, (160, 20), 0.8)]
    elif kind == "infirmary":
        props = [(61, (50, 90), 0.7), (59, (240, 90), 0.7), (32, (460, 50), 0.7),
                 (40, (620, 30), 0.75)]
        paste(im, bit_tile(40, 10, 80), (80, 50))
        paste(im, bit_tile(42, 10, 80), (180, 50))
    elif kind == "workshop":
        props = [(67, (60, 80), 0.8), (74, (250, 70), 0.75), (75, (430, 70), 0.75),
                 (43, (560, 80), 0.65)]
    elif kind == "storage":
        props = [(43, (40, 70), 0.75), (44, (180, 70), 0.75), (57, (320, 70), 0.75),
                 (58, (460, 70), 0.75), (71, (580, 90), 0.7)]
    elif kind == "radio":
        props = [(31, (70, 50), 0.85), (32, (250, 50), 0.85), (45, (430, 50), 0.8),
                 (46, (560, 70), 0.75), (41, (40, 20), 0.7)]
    elif kind == "empty":
        fill_rect(im, (26, 26, w - 26, h - 26), (28, 24, 22, 255))
        props = []
    elif kind == "locked":
        fill_rect(im, (26, 26, w - 26, h - 26), (22, 20, 18, 255))
        props = [(57, (280, 80), 0.9)]

    for n, xy, sc in props:
        try:
            paste(im, industrial(n), xy, sc)
        except Exception:
            pass
    # inner shadow
    shadow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rectangle((18, 18, w - 19, h - 19), outline=(0, 0, 0, 90), width=10)
    im = Image.alpha_composite(im, shadow)
    # warm light vignette
    vig = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    vd = ImageDraw.Draw(vig)
    vd.ellipse((80, -40, w - 80, 140), fill=(224, 161, 74, 28))
    im = Image.alpha_composite(im, vig)
    im.save(path)


def rooms() -> None:
    dest = OUT / "art" / "rooms"
    dest.mkdir(parents=True, exist_ok=True)
    for kind in ["living", "hydroponics", "water", "generator", "infirmary",
                 "workshop", "storage", "radio", "empty", "locked"]:
        make_room(kind, dest / f"{kind}.png")


def backgrounds() -> None:
    dest = OUT / "art" / "bg"
    dest.mkdir(parents=True, exist_ok=True)
    w, h = 1080, 1920
    im = Image.new("RGBA", (w, h), PAL["bg"] + (255,))
    draw = ImageDraw.Draw(im)
    # deep earth
    for y in range(h):
        t = y / h
        col = (
            int(12 + t * 18),
            int(10 + t * 12),
            int(9 + t * 8),
        )
        draw.line((0, y, w, y), fill=col + (255,))
    # surface strip
    draw.rectangle((0, 0, w, 220), fill=(28, 24, 22, 255))
    for x in range(0, w, 90):
        try:
            paste(im, industrial(1), (x, 40), 0.7)
        except Exception:
            pass
    # ruined sky gradient
    for y in range(0, 160):
        a = int(90 * (1 - y / 160))
        draw.line((0, y, w, y), fill=(196, 92, 62, a))
    im.save(dest / "menu.png")
    # in-game bg simpler
    g = Image.new("RGBA", (w, h), (16, 14, 13, 255))
    gd = ImageDraw.Draw(g)
    gd.rectangle((0, 0, w, 90), fill=(34, 28, 22, 255))
    g.save(dest / "game.png")


def app_icon() -> None:
    dest = OUT / "icon"
    dest.mkdir(parents=True, exist_ok=True)
    size = 512
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((16, 16, size - 17, size - 17), 90, fill=(28, 24, 22, 255), outline=PAL["amber"] + (255,), width=14)
    # door
    d.rounded_rectangle((150, 120, 362, 430), 24, fill=(48, 50, 54, 255), outline=(18, 16, 14, 255), width=8)
    d.ellipse((230, 240, 282, 292), fill=PAL["amber"] + (255,))
    try:
        paste(im, industrial(67), (160, 160), 1.1)
    except Exception:
        pass
    head = load(KENNEY / "kenney_tooncharacters1" / "Male person" / "PNG" / "Parts HD" / "head.png")
    h = head.resize((180, 180), Image.Resampling.LANCZOS)
    im.alpha_composite(h, (166, 70))
    im.save(dest / "app_512.png")
    im.resize((192, 192), Image.Resampling.LANCZOS).save(dest / "app_192.png")
    im.resize((432, 432), Image.Resampling.LANCZOS).save(dest / "app_432.png")
    shutil.copy2(dest / "app_192.png", OUT / "icon" / "app_icon.png")


def copy_audio() -> None:
    dest = OUT / "audio"
    dest.mkdir(parents=True, exist_ok=True)
    pairs = [
        (KENNEY / "kenney_interfacesounds" / "Audio" / "click_001.ogg", "click.ogg"),
        (KENNEY / "kenney_interfacesounds" / "Audio" / "confirmation_002.ogg", "confirm.ogg"),
        (KENNEY / "kenney_interfacesounds" / "Audio" / "error_003.ogg", "error.ogg"),
        (KENNEY / "kenney_interfacesounds" / "Audio" / "question_001.ogg", "question.ogg"),
        (KENNEY / "kenney_interfacesounds" / "Audio" / "switch_002.ogg", "switch.ogg"),
        (KENNEY / "kenney_interfacesounds" / "Audio" / "maximize_004.ogg", "open.ogg"),
        (KENNEY / "kenney_rpgaudio" / "Audio" / "doorOpen_1.ogg", "door.ogg"),
        (KENNEY / "kenney_rpgaudio" / "Audio" / "creak1.ogg", "creak.ogg"),
        (KENNEY / "kenney_rpgaudio" / "Audio" / "cloth1.ogg", "cloth.ogg"),
        (KENNEY / "kenney_digitalaudio" / "Audio" / "powerUp7.ogg", "success.ogg"),
        (KENNEY / "kenney_digitalaudio" / "Audio" / "lowDown.ogg", "fail.ogg"),
        (KENNEY / "kenney_impactsounds" / "Audio" / "impactGeneric_light_000.ogg", "impact.ogg"),
        (KENNEY / "kenney_musicjingles" / "Audio" / "Pizzicato jingles" / "jingles_PIZZI00.ogg", "jingle_win.ogg"),
        (KENNEY / "kenney_musicjingles" / "Audio" / "Pizzicato jingles" / "jingles_PIZZI15.ogg", "jingle_lose.ogg"),
    ]
    for src, name in pairs:
        if src.exists():
            shutil.copy2(src, dest / name)
        else:
            print("missing audio", src)
    make_ambient(dest / "ambient.wav")
    make_ambient(dest / "menu_ambient.wav", menu=True)


def make_ambient(path: Path, menu: bool = False) -> None:
    sr = 22050
    seconds = 24
    n = sr * seconds
    rng = random.Random(3 if menu else 7)
    with wave.open(str(path), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        frames = bytearray()
        for i in range(n):
            t = i / sr
            # loop-friendly envelope (fade ends)
            fade = min(1.0, t / 1.5, (seconds - t) / 1.5)
            v = 0.12 * math.sin(2 * math.pi * (46 if menu else 55) * t)
            v += 0.07 * math.sin(2 * math.pi * (69 if menu else 82.4) * t + 0.4)
            v += 0.04 * math.sin(2 * math.pi * 110 * t * (0.5 + 0.5 * math.sin(t * 0.15)))
            v += 0.015 * math.sin(2 * math.pi * 220 * t) * math.sin(t * 0.07)
            v += (rng.random() - 0.5) * 0.02
            sample = int(max(-0.95, min(0.95, v * fade)) * 32767)
            frames += struct.pack("<h", sample)
        w.writeframes(bytes(frames))


def copy_licenses() -> None:
    dest = ROOT / "third_party_licenses"
    dest.mkdir(exist_ok=True)
    for folder, name in [
        ("kenney_tooncharacters1", "kenney_tooncharacters.txt"),
        ("kenney_platformerpack_industrial", "kenney_industrial.txt"),
        ("1bitpack_kenney_1.1", "kenney_1bit.txt"),
        ("gameicons", "kenney_gameicons.txt"),
        ("uipack_fixed", "kenney_uipack.txt"),
        ("pixeluipack", "kenney_pixelui.txt"),
        ("kenney_interfacesounds", "kenney_ui_audio.txt"),
        ("kenney_rpgaudio", "kenney_rpg_audio.txt"),
        ("kenney_digitalaudio", "kenney_digital_audio.txt"),
        ("kenney_musicjingles", "kenney_jingles.txt"),
        ("kenney_impactsounds", "kenney_impact.txt"),
    ]:
        src = KENNEY / folder
        for cand in ["License.txt", "license.txt", "License.txt.txt"]:
            p = src / cand
            if p.exists():
                shutil.copy2(p, dest / name)
                break


def main() -> None:
    for sub in ["fonts", "art/rooms", "art/portraits", "art/characters", "art/icons",
                "art/ui", "art/bg", "audio", "icon"]:
        (OUT / sub).mkdir(parents=True, exist_ok=True)
    copy_fonts()
    copy_ui()
    extract_icons()
    portraits()
    rooms()
    backgrounds()
    app_icon()
    copy_audio()
    copy_licenses()
    print("Assets written to", OUT)


if __name__ == "__main__":
    main()
