# /// script
# requires-python = ">=3.11"
# dependencies = ["pillow"]
# ///
"""Draws the player and the eight characters: map sprites and portraits.

Every character shares one small big-headed body, drawn in the Ninja Adventure
pack's palette and dark outline, and is told apart by silhouette and clothing:
a headscarf, a cap, grey hair and a teacher's white coat, a phone at the ear,
a folder or a clipboard, a backpack.

Writes, for each id in content/scenes.json plus "player":
- art/characters/<id>.png: 16x16 frames, three columns (standing, two walking
  steps) and four rows (facing down, left, right, up);
- art/portraits/<id>.png (not for the player): three 48x48 portraits side by
  side, neutral, worried and pleased.

Run from the project root: uv run tools/draw_characters.py
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pixel import ROOT, Canvas, load_palette  # noqa: E402

C = load_palette()
O = C["OUTLINE"]
T = 16
DIRECTIONS = ["down", "left", "right", "up"]
EXPRESSIONS = ["neutral", "worried", "pleased"]
SPRITE_DIR = ROOT / "art" / "characters"
PORTRAIT_DIR = ROOT / "art" / "portraits"
PORTRAIT = 48


def ramp(light: str, mid: str, dark: str) -> tuple:
    return (C[light], C[mid], C[dark])


SKIN_LIGHT = ramp("PEACH", "SKIN", "SKIN_MID")
SKIN_WARM = ramp("SKIN", "SKIN_MID", "SKIN_DARK")
SKIN_DEEP = ramp("SKIN_MID", "SKIN_DARK", "WOOD_DARK")

# Each character: skin, hair (style and colours), headwear, top, coat, legs,
# shoes and what they carry. Colours are (light, mid, dark) ramps.
CAST: dict[str, dict] = {
    "player": {
        "skin": SKIN_WARM, "hair": "short", "hair_colour": ramp("GREY", "GREY_DARK", "NIGHT"),
        "top": ramp("SKY", "TEAL", "TEAL_DARK"), "collar": "shirt", "lanyard": C["RED_BRIGHT"],
        "legs": ramp("SLATE", "NIGHT", "OUTLINE"), "shoes": C["BROWN_DARK"],
    },
    "jlassi": {
        "skin": SKIN_DEEP, "hair": "receding", "hair_colour": ramp("STEEL", "GREY", "GREY_DARK"),
        "top": ramp("DOOR_BLUE", "DOOR_NAVY", "NIGHT"), "collar": "tie", "tie": C["RED"],
        "legs": ramp("DOOR_BLUE_DARK", "DOOR_NAVY", "NIGHT"), "shoes": C["OUTLINE"], "carry": "phone",
    },
    "kchaou": {
        "skin": SKIN_LIGHT, "hair": "bob", "hair_colour": ramp("WOOD", "WOOD_DARK", "BROWN_DARK"), "glasses": True,
        "top": ramp("LILAC", "MAUVE", "PLUM"), "collar": "shirt",
        "legs": ramp("GREY", "GREY_DARK", "NIGHT"), "skirt": True, "shoes": C["OUTLINE"], "carry": "clipboard",
    },
    "salma": {
        "skin": SKIN_WARM, "hair": "scarf", "hair_colour": ramp("SKY_LIGHT", "SKY", "TEAL"),
        "top": ramp("ORANGE_LIGHT", "ORANGE", "ORANGE_DARK"), "collar": "plain", "long_top": True,
        "legs": ramp("GREY", "GREY_DARK", "NIGHT"), "shoes": C["BROWN_DARK"], "carry": "folder",
    },
    "hedi": {
        "skin": SKIN_WARM, "hair": "bald", "hair_colour": ramp("WHITE", "STEEL", "STEEL_DARK"), "moustache": True,
        "top": ramp("WHITE", "MIST", "SKY_LIGHT"), "collar": "sweater", "sweater": C["LEAF_DARK"], "long_top": True,
        "legs": ramp("GREY", "GREY_DARK", "NIGHT"), "shoes": C["BROWN_DARK"],
    },
    "aziz": {
        "skin": SKIN_LIGHT, "hair": "spiky", "hair_colour": ramp("WOOD_DARK", "BROWN_DARK", "OUTLINE"),
        "top": ramp("SAND_LIGHT", "SAND", "OLIVE"), "collar": "shirt",
        "legs": ramp("DOOR_BLUE", "DOOR_BLUE_DARK", "DOOR_NAVY"), "shoes": C["WHITE"], "carry": "notebook",
    },
    "fethi": {
        "skin": SKIN_DEEP, "hair": "short", "hair_colour": ramp("GREY_DARK", "NIGHT", "OUTLINE"), "cap": "uniform",
        "top": ramp("SKY", "SLATE", "NIGHT"), "collar": "badge",
        "legs": ramp("SLATE", "NIGHT", "OUTLINE"), "shoes": C["OUTLINE"], "belt": True,
    },
    "nour": {
        "skin": SKIN_WARM, "hair": "ponytail", "hair_colour": ramp("WOOD_DARK", "BROWN_DARK", "OUTLINE"),
        "top": ramp("PINK", "ROSE", "WINE"), "collar": "hood",
        "legs": ramp("DOOR_BLUE", "DOOR_BLUE_DARK", "DOOR_NAVY"), "shoes": C["WHITE"], "carry": "backpack",
    },
    "lassaad": {
        "skin": SKIN_DEEP, "hair": "short", "hair_colour": ramp("STEEL", "GREY_MID", "GREY"), "cap": "flat", "moustache": True,
        "top": ramp("WOOD_LIGHT", "WOOD", "WOOD_DARK"), "collar": "sweater", "sweater": C["SAND"], "wide": True,
        "legs": ramp("GREY", "GREY_DARK", "NIGHT"), "shoes": C["BROWN_DARK"],
    },
}


# ---------------------------------------------------------------------------
# Map sprites: 16x16, the head on rows 1 to 8, the body below.


def sprite(spec: dict, facing: str, step: int) -> Canvas:
    """One frame. [step] is 0 standing, 1 and 2 the two walking steps."""
    flip = facing == "right"
    facing = "left" if flip else facing
    c = Canvas(T, T)
    _legs(c, spec, facing, step)
    _body(c, spec, facing, step)
    _head(c, spec, facing)
    _carry(c, spec, facing, step)
    c.outline(O)
    _details_after_outline(c, spec, facing)
    if flip:
        c = c.flipped()
    return c


def _legs(c: Canvas, spec: dict, facing: str, step: int) -> None:
    light, mid, dark = spec["legs"]
    shoes = spec["shoes"]
    if facing in ("down", "up"):
        left_up = step == 1
        right_up = step == 2
        for x0, up in ((5, left_up), (9, right_up)):
            bottom = 13 if up else 14
            c.rect(x0, 13, 2, bottom - 13, mid if not spec.get("skirt") else spec["skin"][1])
            c.rect(x0, bottom, 2, 1, shoes)
        if spec.get("skirt"):
            c.rect(4, 12, 8, 2, mid)
            c.hline(4, 13, 8, dark)
    else:
        # Seen from the left: legs apart when walking.
        if step == 0:
            c.rect(6, 13, 4, 1, mid)
            c.rect(5, 14, 4, 1, shoes)
        else:
            front, back = (4, 9) if step == 1 else (5, 8)
            c.rect(front + 1, 13, 2, 1, mid)
            c.rect(front, 14, 3, 1, shoes)
            c.rect(back, 13, 2, 1, dark)
            c.rect(back, 14, 2, 1, shoes)
        if spec.get("skirt"):
            c.rect(5, 12, 6, 2, mid)


def _body(c: Canvas, spec: dict, facing: str, step: int) -> None:
    light, mid, dark = spec["top"]
    skin = spec["skin"]
    wide = spec.get("wide", False)
    long_top = spec.get("long_top", False)
    bottom = 13 if long_top else 12
    if facing in ("down", "up"):
        x0, w = (3, 10) if wide else (4, 8)
        c.rect(x0, 9, w, bottom - 8, mid)
        c.vline(x0 + w - 1, 9, bottom - 8, dark)
        c.hline(x0, 9, w, light)
        if long_top:
            c.vline(7, 11, 3, dark)
        # Arms swing opposite to the legs.
        for ax, swing in ((x0 - 1, step == 2), (x0 + w, step == 1)):
            top = 9
            c.rect(ax, top, 1, 3 - (1 if swing else 0), mid if facing == "down" else dark)
            c.set(ax, 12 - (1 if swing else 0), skin[1])
        if facing == "down":
            _collar(c, spec)
        else:
            c.vline(7, 10, bottom - 10, dark)
    else:
        x0, w = (4, 7) if wide else (5, 6)
        c.rect(x0, 9, w, bottom - 8, mid)
        c.hline(x0, 9, w, light)
        c.vline(x0 + w - 1, 9, bottom - 8, dark)
        # The near arm, swinging.
        hand = {0: (7, 12), 1: (5, 12), 2: (9, 12)}[step]
        c.rect(7, 9, 2, 2, dark)
        c.rect(min(7, hand[0]), 11, abs(hand[0] - 7) + 2, 1, dark)
        c.rect(hand[0], hand[1], 2, 1, skin[1])
        if spec.get("collar") == "badge":
            c.set(x0, 10, C["SAND"])


def _collar(c: Canvas, spec: dict) -> None:
    kind = spec.get("collar")
    skin = spec["skin"]
    if kind in ("shirt", "tie"):
        c.set(6, 9, C["WHITE"])
        c.set(9, 9, C["WHITE"])
        c.set(7, 9, skin[1])
        c.set(8, 9, skin[1])
        if kind == "tie":
            c.vline(7, 10, 2, spec["tie"])
            c.vline(8, 10, 2, spec["tie"])
            c.set(7, 9, C["WHITE"])
            c.set(8, 9, C["WHITE"])
    elif kind == "sweater":
        c.rect(6, 9, 4, 2, spec["sweater"])
        c.set(7, 9, skin[1])
        c.set(8, 9, skin[1])
    elif kind == "badge":
        c.set(9, 10, C["SAND"])
        c.set(6, 10, C["SKY"])
    elif kind == "hood":
        c.hline(5, 9, 6, spec["top"][0])
        c.set(6, 10, C["WHITE"])
        c.set(9, 10, C["WHITE"])
    if spec.get("lanyard"):
        c.set(8, 11, C["WHITE"])
    if spec.get("belt"):
        c.hline(4, 12, 8, O)
        c.set(8, 12, C["SAND"])


def _head(c: Canvas, spec: dict, facing: str) -> None:
    skin_l, skin, skin_d = spec["skin"]
    hl, hm, hd = spec["hair_colour"]
    style = spec["hair"]
    # The head: a rounded block, rows 1 to 8, columns 3 to 12.
    for y in range(1, 9):
        for x in range(3, 13):
            if (x in (3, 12)) and y in (1, 8):
                continue
            c.set(x, y, skin)
    if facing != "up":
        c.hline(4, 8, 8, skin_d)
    if facing == "down":
        # Ears.
        c.set(3, 6, skin_d)
        c.set(12, 6, skin_d)
    hair_rows = {"short": 3, "receding": 2, "bob": 3, "spiky": 3, "ponytail": 3, "bald": 0, "scarf": 3}
    top_rows = hair_rows[style]

    if style == "scarf":
        _scarf(c, spec, facing)
    elif facing == "up":
        for y in range(1, 8):
            for x in range(3, 13):
                if not ((x in (3, 12)) and y == 1):
                    c.set(x, y, hm)
        c.hline(4, 1, 6, hl)
        c.hline(4, 7, 8, hd)
        if style == "bald":
            c.rect(5, 1, 6, 3, skin)
            c.hline(6, 1, 3, skin_l)
        if style in ("bob", "ponytail"):
            c.hline(3, 8, 10, hd)
        if style == "ponytail":
            c.rect(7, 8, 2, 3, hd)
    elif facing == "down":
        if style == "bald":
            for x in (3, 4, 11, 12):
                c.vline(x, 3, 3, hm)
            c.set(5, 3, hl)
            c.set(10, 3, hl)
        else:
            c.rect(3, 1, 10, top_rows, hm)
            c.set(3, 1, (0, 0, 0, 0))
            c.set(12, 1, (0, 0, 0, 0))
            c.hline(5, 1, 4, hl)
            c.vline(3, 4, 2, hm)
            c.vline(12, 4, 2, hm)
            if style in ("short", "spiky"):
                c.rect(4, 4, 3, 1, hm)
                c.set(10, 4, hm)
                c.set(11, 4, hm)
            if style == "spiky":
                c.rect(5, 4, 2, 1, hd)
            if style == "receding":
                c.set(4, 3, hm)
                c.set(11, 3, hm)
            if style in ("bob", "ponytail"):
                c.rect(4, 4, 8, 1, hm)
                c.hline(5, 4, 2, hd)
                c.vline(3, 4, 5, hm)
                c.vline(12, 4, 5, hm)
                c.vline(3, 6, 3, hd)
                c.vline(12, 6, 3, hd)
            if style == "ponytail":
                c.rect(12, 3, 2, 5, hd)
                c.set(13, 2, hm)
    else:
        # Facing left: the face on the left, hair over the back of the head.
        if style == "bald":
            c.rect(9, 3, 4, 3, hm)
            c.set(8, 3, hl)
        else:
            c.rect(3, 1, 10, top_rows, hm)
            c.set(3, 1, (0, 0, 0, 0))
            c.set(12, 1, (0, 0, 0, 0))
            c.hline(4, 1, 5, hl)
            back_bottom = 8 if style in ("bob", "ponytail") else 6
            c.rect(9, 3, 4, back_bottom - 2, hm)
            c.vline(12, 3, back_bottom - 2, hd)
            c.set(3, 4, hm)
            if style == "spiky":
                c.rect(3, 4, 3, 1, hm)
            if style == "ponytail":
                c.rect(13, 3, 1, 5, hd)
                c.rect(12, 6, 2, 3, hm)
        c.set(9, 6, skin_d)

    # Spiky hair and a ponytail stick out of the outline: drawn as dark bumps.
    if style == "spiky" and facing != "up":
        for x in (4, 7, 10):
            c.set(x, 0, hm)
    _cap(c, spec, facing)


def _scarf(c: Canvas, spec: dict, facing: str) -> None:
    """A headscarf framing the face and falling to the shoulders."""
    hl, hm, hd = spec["hair_colour"]
    skin_l, skin, skin_d = spec["skin"]
    for y in range(1, 10):
        for x in range(2, 14):
            if (x in (2, 13)) and (y < 3 or y > 8):
                continue
            if (x in (3, 12)) and y == 1:
                continue
            c.set(x, y, hm)
    c.hline(4, 1, 6, hl)
    c.hline(2, 9, 12, hd)
    if facing == "down":
        for y in range(3, 9):
            for x in range(4, 12):
                if (x in (4, 11)) and y in (3, 8):
                    continue
                c.set(x, y, skin)
        c.hline(5, 8, 6, skin_d)
    elif facing == "left":
        for y in range(3, 9):
            for x in range(3, 8):
                if (x == 7 and y in (3, 8)):
                    continue
                c.set(x, y, skin)
        c.hline(3, 8, 4, skin_d)
        c.set(2, 5, (0, 0, 0, 0))
        c.set(2, 6, (0, 0, 0, 0))
        c.set(2, 7, (0, 0, 0, 0))
        c.set(2, 4, (0, 0, 0, 0))
    else:
        c.vline(7, 3, 6, hd)


def _cap(c: Canvas, spec: dict, facing: str) -> None:
    kind = spec.get("cap")
    if not kind:
        return
    if kind == "uniform":
        light, mid, dark = C["SKY"], C["SLATE"], C["NIGHT"]
    else:
        light, mid, dark = C["GREY_LIGHT"], C["GREY_MID"], C["GREY"]
    c.rect(3, 1, 10, 3, mid)
    c.hline(4, 1, 6, light)
    c.set(3, 1, (0, 0, 0, 0))
    c.set(12, 1, (0, 0, 0, 0))
    if facing == "down":
        c.hline(3, 4, 10, dark)
        if kind == "uniform":
            c.set(7, 2, C["SAND"])
            c.set(8, 2, C["SAND"])
    elif facing == "left":
        c.hline(1, 4, 7, dark)
        c.hline(9, 4, 4, mid)
    else:
        c.hline(3, 4, 10, dark)


def _details_after_outline(c: Canvas, spec: dict, facing: str) -> None:
    """Eyes, glasses and moustaches, drawn after the outline so they stay inside."""
    if facing == "up":
        return
    eyes = [(5, 5), (10, 5)] if facing == "down" else [(4, 5)]
    for x, y in eyes:
        c.set(x, y, O)
        c.set(x, y + 1, O)
    if spec.get("glasses"):
        if facing == "down":
            for x in (4, 6, 9, 11):
                c.set(x, 5, O)
            c.hline(7, 5, 2, O)
            c.set(5, 5, C["SKY_LIGHT"])
            c.set(10, 5, C["SKY_LIGHT"])
        else:
            c.set(3, 5, O)
            c.set(5, 5, O)
            c.hline(6, 5, 3, O)
            c.set(4, 5, C["SKY_LIGHT"])
    if spec.get("moustache"):
        colour = spec["hair_colour"][2]
        if facing == "down":
            c.hline(6, 7, 4, colour)
        else:
            c.hline(3, 7, 3, colour)
    elif facing == "down":
        # A little blush.
        c.set(4, 7, C["PINK"])
        c.set(11, 7, C["PINK"])


def _carry(c: Canvas, spec: dict, facing: str, step: int) -> None:
    kind = spec.get("carry")
    if not kind:
        return
    skin = spec["skin"][1]
    if kind == "phone":
        # A hand raised to the ear, holding a phone.
        if facing == "down":
            c.rect(12, 5, 2, 3, O)
            c.set(12, 8, skin)
            c.set(13, 8, skin)
            c.rect(12, 9, 2, 1, spec["top"][1])
            c.set(12, 10, (0, 0, 0, 0))
            c.set(12, 11, (0, 0, 0, 0))
            c.set(12, 12, (0, 0, 0, 0))
        elif facing == "left":
            c.rect(8, 5, 2, 3, O)
            c.rect(9, 8, 2, 1, skin)
        else:
            c.rect(11, 5, 2, 3, O)
    elif kind == "folder" and facing != "up":
        if facing == "down":
            c.rect(8, 10, 4, 3, C["DOOR_BLUE"])
            c.hline(8, 10, 4, C["DOOR_BLUE_LIGHT"])
        else:
            c.rect(4, 10, 3, 3, C["DOOR_BLUE"])
    elif kind == "clipboard" and facing != "up":
        if facing == "down":
            c.rect(3, 10, 4, 4, C["WOOD_LIGHT"])
            c.rect(4, 11, 2, 2, C["WHITE"])
            c.set(4, 10, C["STEEL_DARK"])
        else:
            c.rect(3, 10, 3, 4, C["WOOD_LIGHT"])
            c.rect(3, 11, 2, 2, C["WHITE"])
    elif kind == "notebook" and facing != "up":
        if facing == "down":
            c.rect(9, 11, 3, 2, C["SKY_LIGHT"])
            c.set(9, 11, C["DOOR_BLUE"])
    elif kind == "backpack":
        if facing == "up":
            c.rect(4, 9, 8, 4, C["DOOR_BLUE"])
            c.hline(4, 9, 8, C["DOOR_BLUE_LIGHT"])
            c.rect(6, 11, 4, 1, C["DOOR_BLUE_DARK"])
        elif facing == "down":
            c.vline(5, 9, 3, C["DOOR_BLUE"])
            c.vline(10, 9, 3, C["DOOR_BLUE"])
        else:
            c.rect(10, 9, 3, 4, C["DOOR_BLUE"])


def sprite_sheet(spec: dict) -> Image.Image:
    sheet = Canvas(3 * T, 4 * T)
    for row, facing in enumerate(DIRECTIONS):
        for step in range(3):
            sheet.blit(sprite(spec, facing, step), step * T, row * T)
    return sheet.image()


# ---------------------------------------------------------------------------
# Portraits: 48x48, head and shoulders, three expressions.


def portrait(spec: dict, expression: str) -> Canvas:
    c = Canvas(PORTRAIT, PORTRAIT)
    skin_l, skin, skin_d = spec["skin"]
    hl, hm, hd = spec["hair_colour"]
    tl, tm, td = spec["top"]
    style = spec["hair"]

    # Shoulders and clothes.
    wide = 2 if spec.get("wide") else 0
    for y in range(36, 48):
        half = 13 + wide + min(6, (y - 36))
        c.hline(24 - half, y, 2 * half, tm)
    c.hline(11 - wide, 36, 26 + 2 * wide, tl)
    for y in range(38, 48):
        c.set(24 + 13 + wide + min(6, y - 36) - 1, y, td)
    # Neck.
    c.rect(20, 32, 8, 6, skin_d)
    _portrait_collar(c, spec)

    # The head: a big rounded face.
    face = Canvas(PORTRAIT, PORTRAIT)
    face.disc(24, 21, 13.5, skin)
    face.rect(12, 21, 24, 8, skin)
    face.disc(24, 26, 11.5, skin)
    c.blit(face, 0, 0)
    for y in range(28, 35):
        for x in range(10, 38):
            if c.get(x, y) == skin and x > 32 + (34 - y) // 3:
                c.set(x, y, skin_d)
    c.disc(10.5, 24, 2.6, skin)
    c.disc(37.5, 24, 2.6, skin)
    c.set(10, 24, skin_d)
    c.set(37, 24, skin_d)

    _portrait_hair(c, spec)
    _portrait_cap(c, spec)
    _portrait_carry(c, spec, back=True)
    c.outline(O)
    _portrait_face(c, spec, expression)
    _portrait_carry(c, spec, back=False)
    return c


def _portrait_collar(c: Canvas, spec: dict) -> None:
    kind = spec.get("collar")
    skin_d = spec["skin"][2]
    if kind in ("shirt", "tie"):
        for i in range(5):
            c.hline(18 - i // 2, 36 + i, 3, C["WHITE"])
            c.hline(27 + i // 2, 36 + i, 3, C["WHITE"])
        c.rect(21, 36, 6, 3, skin_d)
        if kind == "tie":
            c.rect(22, 38, 4, 2, spec["tie"])
            c.rect(23, 40, 3, 8, spec["tie"])
            c.vline(25, 41, 7, C["WINE"])
        else:
            c.rect(20, 39, 8, 9, C["WHITE"])
            c.vline(24, 40, 8, C["MIST"])
        if spec.get("lanyard"):
            for i in range(10):
                c.set(17 + i // 3, 38 + i, spec["lanyard"])
                c.set(31 - i // 3, 38 + i, spec["lanyard"])
            c.rect(26, 44, 5, 4, C["WHITE"])
            c.hline(27, 45, 3, C["DOOR_BLUE"])
    elif kind == "sweater":
        c.rect(17, 36, 14, 6, spec["sweater"])
        c.rect(21, 36, 6, 3, skin_d)
        c.rect(22, 39, 4, 2, spec["sweater"])
        if spec["top"][0] == C["WHITE"]:
            # A teacher's white coat over it, open at the front.
            c.rect(18, 42, 12, 6, spec["sweater"])
            c.vline(17, 38, 10, spec["top"][2])
            c.vline(30, 38, 10, spec["top"][2])
    elif kind == "badge":
        c.rect(29, 40, 4, 4, C["SAND"])
        c.frame(29, 40, 4, 4, C["WOOD"])
        c.rect(14, 40, 5, 2, C["SKY"])
        c.rect(21, 36, 6, 2, spec["skin"][2])
        c.vline(24, 38, 10, spec["top"][2])
    elif kind == "hood":
        c.rect(14, 35, 20, 4, spec["top"][0])
        c.hline(14, 38, 20, spec["top"][2])
        c.vline(20, 39, 6, C["WHITE"])
        c.vline(27, 39, 6, C["WHITE"])
    elif kind == "plain":
        c.rect(19, 36, 10, 3, spec["top"][0])


def _portrait_hair(c: Canvas, spec: dict) -> None:
    hl, hm, hd = spec["hair_colour"]
    skin_l, skin, skin_d = spec["skin"]
    style = spec["hair"]
    if style == "scarf":
        scarf = Canvas(PORTRAIT, PORTRAIT)
        scarf.disc(24, 21, 16.5, hm)
        scarf.rect(8, 21, 32, 18, hm)
        for y in range(36, 44):
            scarf.hline(6 + (y - 36) // 3, y, 36 - 2 * ((y - 36) // 3), hm)
        # Cut out the face.
        for y in range(12, 36):
            for x in range(10, 39):
                inside = ((x - 24) / 11.5) ** 2 + ((y - 23) / 12.5) ** 2 <= 1
                if inside:
                    scarf.set(x, y, (0, 0, 0, 0))
                    scarf.px[y][x] = (0, 0, 0, 0)
        for y in range(PORTRAIT):
            for x in range(PORTRAIT):
                if scarf.opaque(x, y):
                    shade = hl if (x + y) < 34 else (hd if x > 34 or y > 40 else hm)
                    c.set(x, y, shade)
        # Repaint the face inside the scarf.
        for y in range(12, 36):
            for x in range(10, 39):
                if ((x - 24) / 11.5) ** 2 + ((y - 23) / 12.5) ** 2 <= 1:
                    c.set(x, y, skin if y < 31 or x < 31 else skin_d)
        c.hline(14, 12, 20, hd)
        return
    if style == "bald":
        for y in range(14, 27):
            inset = 1 if y in (14, 26) else 0
            c.hline(10 + inset, y, 3 - inset, hm)
            c.hline(35, y, 3 - inset, hm)
        c.vline(10, 16, 8, hl)
        c.vline(37, 16, 9, hd)
        c.hline(18, 8, 12, skin_l)
        c.hline(20, 9, 6, C["WHITE"])
        return
    hair = Canvas(PORTRAIT, PORTRAIT)
    hair.disc(24, 19, 15, hm)
    if style == "receding":
        hair.rect(9, 19, 30, 6, hm)
    else:
        hair.rect(9, 19, 30, 4, hm)
    if style in ("bob", "ponytail"):
        hair.rect(8, 19, 6, 17, hm)
        hair.rect(34, 19, 6, 17, hm)
    # The fringe leaves the face open below row 17 or so.
    for y in range(PORTRAIT):
        for x in range(PORTRAIT):
            if not hair.opaque(x, y):
                continue
            in_face = 12 <= x <= 35 and y >= _fringe(style, x)
            if in_face:
                continue
            shade = hl if (y < 10 and x < 28) else (hd if x > 34 or y > 24 else hm)
            c.set(x, y, shade)
    if style == "spiky":
        for x0 in (12, 18, 24, 30):
            for i in range(4):
                c.hline(x0 + i // 2, 4 - i + 1, 4 - i, hm)
        c.set(19, 3, hl)
        c.set(25, 3, hl)
    if style == "ponytail":
        c.rect(38, 14, 5, 16, hd)
        c.rect(39, 15, 3, 13, hm)
        c.rect(38, 13, 4, 3, C["DOOR_BLUE"])


def _fringe(style: str, x: int) -> int:
    """The row where the hair stops and the forehead starts, at column x."""
    if style == "receding":
        return 11 if 16 <= x <= 31 else 14
    if style == "spiky":
        return 15 + (2 if (x // 4) % 2 else 0) if 14 <= x <= 33 else 13
    if style in ("bob", "ponytail"):
        return 14 + (3 if x < 22 else 0) if x < 30 else 15
    return 15 if 14 <= x <= 33 else 13


def _portrait_cap(c: Canvas, spec: dict) -> None:
    kind = spec.get("cap")
    if not kind:
        return
    if kind == "uniform":
        light, mid, dark = C["SKY"], C["SLATE"], C["NIGHT"]
    else:
        light, mid, dark = C["GREY_LIGHT"], C["GREY_MID"], C["GREY"]
    cap = Canvas(PORTRAIT, PORTRAIT)
    cap.disc(24, 13, 14, mid)
    for y in range(PORTRAIT):
        for x in range(PORTRAIT):
            if cap.opaque(x, y) and y <= 13:
                c.set(x, y, light if y < 5 and x < 26 else mid)
    c.rect(8, 13, 32, 3, dark)
    if kind == "uniform":
        c.rect(6, 15, 36, 2, O)
        c.rect(21, 6, 6, 5, C["SAND"])
        c.frame(21, 6, 6, 5, C["WOOD"])
    else:
        c.rect(7, 15, 27, 2, mid)
        c.hline(7, 16, 27, dark)


def _portrait_face(c: Canvas, spec: dict, expression: str) -> None:
    skin_l, skin, skin_d = spec["skin"]
    hd = spec["hair_colour"][2]
    brow = spec["hair_colour"][2] if spec["hair"] not in ("bald", "scarf") else C["BROWN_DARK"]
    if spec["hair"] == "bald":
        brow = C["GREY"]
    eye_y = 22
    for ex in (17, 31):
        if expression == "pleased":
            # Closed, smiling eyes.
            c.set(ex - 2, eye_y + 1, O)
            c.hline(ex - 1, eye_y, 3, O)
            c.set(ex + 2, eye_y + 1, O)
        else:
            c.rect(ex - 1, eye_y - 1, 3, 4, O)
            c.set(ex, eye_y - 1, C["WHITE"])
            if expression == "worried":
                c.hline(ex - 1, eye_y + 3, 3, skin_d)
    # Eyebrows.
    for ex, inner in ((17, 1), (31, -1)):
        if expression == "worried":
            # Raised at the middle of the face, lowered at the sides.
            for i, dy in enumerate((0, -1, -2, -3)):
                c.set(ex - 2 * inner + i * inner, eye_y - 4 + dy, brow)
                c.set(ex - 2 * inner + i * inner, eye_y - 3 + dy, brow)
        elif expression == "pleased":
            c.hline(ex - 2, eye_y - 5, 5, brow)
            c.set(ex - 2, eye_y - 4, brow)
            c.set(ex + 2, eye_y - 4, brow)
        else:
            c.hline(ex - 2, eye_y - 4, 5, brow)
    if spec.get("glasses"):
        for ex in (17, 31):
            c.frame(ex - 4, eye_y - 3, 9, 7, O)
        c.hline(22, eye_y - 1, 5, O)
        c.set(13, eye_y + 2, C["SKY_LIGHT"])
        c.set(27, eye_y + 2, C["SKY_LIGHT"])
    # Nose.
    c.set(24, 26, skin_d)
    c.set(25, 27, skin_d)
    # Cheeks.
    if expression == "pleased" or not spec.get("moustache"):
        c.hline(13, 27, 3, C["PINK"])
        c.hline(33, 27, 3, C["PINK"])
    # Mouth.
    mouth_y = 30
    if spec.get("moustache"):
        c.rect(19, 28, 11, 2, hd)
        c.set(18, 29, hd)
        c.set(30, 29, hd)
        mouth_y = 31
    if expression == "neutral":
        c.hline(22, mouth_y, 5, C["WOOD_DARK"])
    elif expression == "worried":
        c.set(21, mouth_y + 1, C["WOOD_DARK"])
        c.hline(22, mouth_y, 2, C["WOOD_DARK"])
        c.hline(24, mouth_y + 1, 2, C["WOOD_DARK"])
        c.set(26, mouth_y, C["WOOD_DARK"])
        # A drop of sweat at the temple.
        c.rect(36, 15, 2, 3, C["SKY_LIGHT"])
        c.set(36, 15, C["WHITE"])
        c.frame(35, 14, 4, 5, C["DOOR_BLUE"])
    else:
        c.hline(20, mouth_y, 9, O)
        c.rect(21, mouth_y + 1, 7, 2, C["WINE"])
        c.hline(22, mouth_y + 1, 5, C["WHITE"])
        c.hline(22, mouth_y + 3, 5, O)
        c.set(20, mouth_y + 1, O)
        c.set(28, mouth_y + 1, O)


def _portrait_carry(c: Canvas, spec: dict, back: bool) -> None:
    kind = spec.get("carry")
    skin = spec["skin"][1]
    if kind == "phone" and not back:
        # A phone held to the ear.
        c.rect(36, 18, 6, 12, O)
        c.rect(37, 19, 4, 10, C["SLATE"])
        c.rect(37, 20, 4, 6, C["SKY"])
        c.rect(36, 29, 8, 7, skin)
        c.frame(35, 28, 10, 9, O)
        c.rect(38, 37, 8, 11, spec["top"][1])
        c.frame(37, 36, 10, 12, O)
    elif kind == "folder" and not back:
        c.rect(26, 38, 16, 10, C["DOOR_BLUE"])
        c.hline(26, 38, 16, C["DOOR_BLUE_LIGHT"])
        c.rect(29, 41, 9, 2, C["WHITE"])
        c.frame(25, 37, 18, 11, O)
        c.rect(23, 42, 4, 4, skin)
        c.frame(22, 41, 6, 6, O)
    elif kind == "clipboard" and not back:
        c.rect(5, 34, 15, 14, C["WOOD_LIGHT"])
        c.rect(7, 37, 11, 11, C["WHITE"])
        for y in (39, 42, 45):
            c.hline(8, y, 8, C["GREY_MID"])
        c.rect(9, 33, 7, 3, C["STEEL"])
        c.frame(4, 33, 17, 15, O)
        c.frame(8, 32, 9, 4, O)
    elif kind == "notebook" and not back:
        c.rect(29, 39, 13, 9, C["SKY_LIGHT"])
        c.vline(30, 40, 8, C["DOOR_BLUE"])
        c.hline(32, 42, 8, C["DOOR_BLUE_LIGHT"])
        c.hline(32, 44, 7, C["DOOR_BLUE_LIGHT"])
        c.frame(28, 38, 15, 10, O)
    elif kind == "backpack" and not back:
        c.rect(11, 36, 3, 12, C["DOOR_BLUE"])
        c.rect(34, 36, 3, 12, C["DOOR_BLUE"])
        c.frame(10, 35, 5, 13, O)
        c.frame(33, 35, 5, 13, O)


def portrait_strip(spec: dict) -> Image.Image:
    strip = Canvas(PORTRAIT * len(EXPRESSIONS), PORTRAIT)
    for i, expression in enumerate(EXPRESSIONS):
        strip.blit(portrait(spec, expression), i * PORTRAIT, 0)
    return strip.image()


def main() -> None:
    SPRITE_DIR.mkdir(parents=True, exist_ok=True)
    PORTRAIT_DIR.mkdir(parents=True, exist_ok=True)
    for character, spec in CAST.items():
        sprite_sheet(spec).save(SPRITE_DIR / f"{character}.png")
        if character != "player":
            portrait_strip(spec).save(PORTRAIT_DIR / f"{character}.png")
    print(f"drew {len(CAST)} sprite sheets in {SPRITE_DIR.relative_to(ROOT)} and {len(CAST) - 1} portrait strips in {PORTRAIT_DIR.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
