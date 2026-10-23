# /// script
# requires-python = ">=3.11"
# dependencies = ["pillow"]
# ///
"""Draws the exam centre's tiles and lays out the map.

Draws the lycée's own pieces (rendered walls with a blue dado, blue doors and
window frames, the gate and its guard post, olive and palm trees, the flagpole,
benches, classroom desks, the blackboard, the wall clock, office desks, filing
cabinets, the locked cabinet, sealed envelopes, notice boards) in the Ninja
Adventure pack's palette and outline, and takes floors, plants and furniture
from the pack's tilesets in art/ninja_adventure/. Then:

- writes the atlas to art/tiles/centre.png,
- writes the TileSet, with collision on walls and solid props, to world/centre_tiles.tres,
- fills the map's tile layers in world/centre.tscn from the layout below,
- checks the map can be walked (see check_map),
- paints the title screen's picture of the lycée to art/ui/title.png.

Run from the project root: uv run tools/build_map.py
To check the map without writing anything: uv run tools/build_map.py --check
"""

from __future__ import annotations

import random
import re
import struct
import sys
from collections import deque
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pixel import ROOT, Canvas, load_palette, with_alpha  # noqa: E402

T = 16
PACK = ROOT / "art" / "ninja_adventure" / "Backgrounds" / "Tilesets"
ATLAS_PATH = ROOT / "art" / "tiles" / "centre.png"
TILESET_PATH = ROOT / "world" / "centre_tiles.tres"
MAP_PATH = ROOT / "world" / "centre.tscn"
ATLAS_COLUMNS = 16
TITLE_PATH = ROOT / "art" / "ui" / "title.png"

C = load_palette()
O = C["OUTLINE"]

# The map, one character per tile: '#' wall, 'G' the gate, and a floor for
# each place: a admin office, r Room 12, s staff room, d deposit room,
# c courtyard, p the paved forecourt inside the gate. Doorways carry their room's floor.
FLOOR_MAP = [
    "####################################",
    "#aaaaaaaaaa#rrrrrrrrrrrr#ssssssssss#",
    "#aaaaaaaaaa#rrrrrrrrrrrr#ssssssssss#",
    "#aaaaaaaaaa#rrrrrrrrrrrr#ssssssssss#",
    "#aaaaaaaaaa#rrrrrrrrrrrr#ssssssssss#",
    "#aaaaaaaaaa#rrrrrrrrrrrr#ssssssssss#",
    "#aaaaaaaaaa#rrrrrrrrrrrr#ssssssssss#",
    "#aaaaaaaaaa#rrrrrrrrrrrr#ssssssssss#",
    "#####aa##########rr#########ss######",
    "#cccccccccccccccccccccc#ddddddddddd#",
    "#cccccccccccccccccccccc#ddddddddddd#",
    "#cccccccccccccccccccccc#ddddddddddd#",
    "#cccccccccccccccccccccc#ddddddddddd#",
    "#ccccccccccccccccccccccdddddddddddd#",
    "#ccccccccccccccccccccccdddddddddddd#",
    "#cccccccccccccccccccccc#ddddddddddd#",
    "#cccccccccccccccccccccc#ddddddddddd#",
    "#cccccccppppppppccccccc#ddddddddddd#",
    "#cccccccppppppppccccccc#ddddddddddd#",
    "#cccccccppppppppccccccc#ddddddddddd#",
    "#cccccccppppppppccccccc#ddddddddddd#",
    "#########GGGGGG#####################",
]
WIDTH = len(FLOOR_MAP[0])
HEIGHT = len(FLOOR_MAP)

# Grass beds in the courtyard, as (x, y, width, height) in tiles.
GRASS_BEDS = [(1, 9, 4, 2), (19, 9, 4, 3), (1, 14, 3, 3), (18, 17, 5, 4), (1, 18, 5, 3)]

# The doorways in the rooms' south walls, each half with its door folded
# against the left (L) or right (R) side.
DOORWAYS = [(5, 8, "L"), (6, 8, "R"), (17, 8, "L"), (18, 8, "R"), (28, 8, "L"), (29, 8, "R")]

# Wall decorations: (name, x, y) on a wall face, the leftmost tile for wide ones.
WALL_DECOR = [
    # Admin office, its north wall.
    ("window", 3, 0), ("notice", 6, 0), ("window", 9, 0),
    # Room 12: the blackboard, a window each side, the clock.
    ("window", 13, 0), ("blackboard", 15, 0), ("clock", 20, 0), ("window", 22, 0),
    # Staff room: a notice board, a window, the staffing chart.
    ("notice", 28, 0), ("window", 30, 0), ("chart", 32, 0),
    # The courtyard side of the rooms, and the exam timetable.
    ("window", 2, 8), ("window", 9, 8), ("timetable", 11, 8), ("window", 14, 8), ("window", 21, 8),
    # The deposit room's side of the staff room wall.
    ("notice", 25, 8), ("clock", 34, 8),
]

# Props: (name, x, y) with x, y the top-left tile.
PROPS = [
    # Admin office: M. Jlassi's desk, Mme Salma's desk, cabinets, shelves, plants.
    ("filing", 1, 1), ("filing", 2, 1), ("bookshelf", 7, 1), ("plant", 10, 1),
    ("office_desk", 3, 4), ("office_desk", 8, 5), ("drawers", 1, 6), ("plant", 10, 6),
    ("photocopier", 3, 1), ("water_cooler", 5, 1), ("flag_stand", 6, 1),
    # Room 12: the teacher's desk and double desks in rows, an aisle down the middle.
    ("teacher_desk", 19, 2),
    ("school_desk", 13, 4), ("school_desk", 15, 4), ("school_desk", 13, 6), ("school_desk", 15, 6),
    ("school_desk", 20, 4), ("school_desk", 22, 4), ("school_desk", 22, 6),
    ("bin", 12, 7), ("plant", 23, 1),
    # Staff room: the big table, shelves and drawers.
    ("bookshelf", 25, 1), ("staff_table", 29, 4), ("drawers", 34, 1), ("plant", 34, 6),
    ("lockers", 27, 1), ("lockers", 28, 1), ("water_cooler", 25, 5), ("tea_table", 25, 7),
    # Deposit room: the locked cabinet, the envelopes, exam boxes, a logbook desk.
    ("steel_cabinet", 31, 9), ("dresser", 25, 9), ("filing", 34, 9),
    ("envelope_table", 27, 15), ("office_desk", 25, 19),
    ("boxes", 33, 19), ("boxes", 34, 19), ("boxes", 34, 18), ("bin", 24, 20),
    ("photocopier", 24, 9), ("boxes", 33, 9), ("plant", 34, 15),
    # Courtyard: olive and palm trees in their beds, the flag, benches.
    ("olive", 20, 9), ("olive", 1, 14), ("palm", 20, 17), ("palm", 2, 18),
    ("flag", 11, 9), ("bench", 5, 11), ("bench", 16, 11),
    ("bush", 1, 9), ("bush_round", 4, 10), ("sunflower", 2, 9), ("bush", 22, 11),
    ("flower_red", 3, 16), ("bush_round", 18, 20), ("bush", 5, 20), ("bin", 22, 16),
    ("plant", 3, 9), ("plant", 15, 9),
    # The gate: the guard post.
    ("booth", 14, 17),
]

# Paved paths across the courtyard: (x, y, width, height) in tiles.
PATHS = [(4, 13, 19, 2), (11, 12, 2, 5), (8, 17, 8, 4)]

# Rugs, a red mergoum under the desks: (x, y, width, height) in tiles.
RUGS = [(2, 3, 4, 2), (28, 3, 5, 4)]

# Small things on the ground that do not block: (name, x, y).
FLOOR_DECOR = [
    ("tuft", 3, 10), ("flower_white", 1, 10), ("tuft", 21, 11), ("tuft", 19, 11),
    ("tuft", 3, 14), ("flower_white", 2, 16), ("tuft", 18, 17), ("flower_white", 22, 17),
    ("tuft", 19, 20), ("tuft", 1, 18), ("flower_white", 4, 19), ("tuft", 5, 18),
    ("pebbles", 7, 16), ("pebbles", 14, 10), ("crack", 18, 16), ("pebbles", 10, 16),
    ("crack", 4, 12), ("pebbles", 20, 15),
]

# The doorways' two tiles each, in the rooms' south walls ("v": walked through
# north to south) and the deposit room's west wall ("h": west to east).
DOOR_GAPS = [((5, 8), (6, 8), "v"), ((17, 8), (18, 8), "v"), ((28, 8), (29, 8), "v"), ((23, 13), (23, 14), "h")]

# The player's start, the scene spots and the characters' starts are read from
# world/centre.tscn, and the bodies' collision boxes from actors/player/ and actors/npc/.
PLAYER_SCENE = ROOT / "actors" / "player" / "player.tscn"
NPC_SCENE = ROOT / "actors" / "npc" / "npc.tscn"

random.seed(26)


# ---------------------------------------------------------------------------
# The atlas: each tile drawn once, then placed by name.


class Atlas:
    def __init__(self) -> None:
        self.tiles: list[Canvas] = []
        self.meta: list[dict] = []
        self.index: dict[str, int] = {}

    def add(self, key: str, tile: Canvas, solid: bool = False, sort_offset: int = 0) -> tuple[int, int]:
        if key not in self.index:
            self.index[key] = len(self.tiles)
            self.tiles.append(tile)
            self.meta.append({"solid": solid, "sort": sort_offset, "key": key})
        return self.coords(key)

    def coords(self, key: str) -> tuple[int, int]:
        i = self.index[key]
        return (i % ATLAS_COLUMNS, i // ATLAS_COLUMNS)

    def image(self) -> Image.Image:
        rows = (len(self.tiles) + ATLAS_COLUMNS - 1) // ATLAS_COLUMNS
        img = Image.new("RGBA", (ATLAS_COLUMNS * T, rows * T))
        for i, tile in enumerate(self.tiles):
            img.alpha_composite(tile.image(), ((i % ATLAS_COLUMNS) * T, (i // ATLAS_COLUMNS) * T))
        return img


def pack_tile(sheet: str, tx: int, ty: int, w: int = 1, h: int = 1) -> Canvas:
    img = Image.open(PACK / sheet).convert("RGBA").crop((tx * T, ty * T, (tx + w) * T, (ty + h) * T))
    return Canvas.from_image(img)


def add_object(atlas: Atlas, name: str, art: Canvas, solid_rows: set[int] | None = None, solid: bool = True) -> list[list[tuple[int, int]]]:
    """Slice a multi-tile drawing into tiles. Rows above the bottom one sort at
    the bottom row, so a character behind a tree's crown is drawn under it."""
    tw, th = art.width // T, art.height // T
    solid_rows = set(range(th)) if solid_rows is None else solid_rows
    out = []
    for ry in range(th):
        row = []
        for rx in range(tw):
            piece = art.crop(rx * T, ry * T, T, T)
            row.append(atlas.add(f"{name}_{rx}_{ry}", piece, solid and ry in solid_rows, (th - 1 - ry) * T))
        out.append(row)
    return out


# ---------------------------------------------------------------------------
# Drawn walls.


def wall_cap(n: bool, e: bool, s: bool, w: bool) -> Canvas:
    """The top of a wall seen from above; a dark edge where no wall continues."""
    c = Canvas(T, T)
    c.rect(0, 0, T, T, C["WALL_CREAM"])
    for x in range(T):
        for y in range(T):
            if (x * 7 + y * 13) % 23 == 0:
                c.set(x, y, C["WALL_SHADE"])
    if not n:
        c.hline(0, 1, T, C["WALL_WHITE"])
        c.hline(0, 0, T, O)
    if not w:
        c.vline(1, 0, T, C["WALL_WHITE"])
        c.vline(0, 0, T, O)
    if not s:
        c.hline(0, T - 2, T, C["WALL_SHADE"])
        c.hline(0, T - 1, T, O)
    if not e:
        c.vline(T - 2, 0, T, C["WALL_SHADE"])
        c.vline(T - 1, 0, T, O)
    return c


def wall_face(n: bool, e: bool, w: bool) -> Canvas:
    """The front of a wall: a strip of its top, white render, a blue dado."""
    c = Canvas(T, T)
    c.rect(0, 0, T, 3, C["WALL_CREAM"])
    c.hline(0, 1, T, C["WALL_WHITE"])
    if not n:
        c.hline(0, 0, T, O)
    c.hline(0, 3, T, O)
    c.rect(0, 4, T, 8, C["WALL_WHITE"])
    c.hline(0, 4, T, C["WALL_SHADE"])
    for x in range(T):
        for y in range(5, 12):
            if (x * 5 + y * 11) % 19 == 0:
                c.set(x, y, C["WALL_CREAM"])
    c.hline(0, 11, T, C["WALL_CREAM"])
    c.hline(0, 12, T, C["DOOR_BLUE_LIGHT"])
    c.rect(0, 13, T, 2, C["DOOR_BLUE"])
    c.hline(0, 14, T, C["DOOR_BLUE_DARK"])
    c.hline(0, 15, T, O)
    if not w:
        c.vline(1, 0, T, C["WALL_WHITE"])
        c.vline(0, 0, T, O)
    if not e:
        c.vline(T - 2, 0, T, C["WALL_SHADE"])
        c.vline(T - 1, 0, T, O)
    return c


def wall_shadow() -> Canvas:
    c = Canvas(T, T)
    for y, a in enumerate([90, 50, 25]):
        c.hline(0, y, T, with_alpha(O, a))
    return c


def window() -> Canvas:
    c = Canvas(T, T)
    c.rect(3, 4, 10, 8, C["DOOR_BLUE"])
    c.rect(4, 5, 8, 6, C["SKY_LIGHT"])
    c.rect(4, 8, 8, 3, C["SKY"])
    c.set(5, 6, C["WHITE"])
    c.set(6, 6, C["WHITE"])
    c.set(5, 7, C["WHITE"])
    # The blue grille.
    c.vline(7, 5, 6, C["DOOR_BLUE_DARK"])
    c.vline(8, 5, 6, C["DOOR_BLUE_DARK"])
    c.hline(4, 7, 8, C["DOOR_BLUE_DARK"])
    c.hline(3, 4, 10, C["DOOR_BLUE_LIGHT"])
    c.frame(2, 3, 12, 10, O)
    c.hline(2, 12, 12, C["WALL_SHADE"])
    c.hline(1, 13, 14, O)
    c.hline(2, 12, 12, C["WALL_DEEP"])
    return c


def notice_board(width_tiles: int = 1, header: bool = False) -> Canvas:
    w = width_tiles * T
    c = Canvas(w, T)
    c.rect(2, 4, w - 4, 9, C["WOOD_LIGHT"])
    for x in range(3, w - 3):
        for y in range(5, 12):
            if (x * 3 + y * 7) % 11 == 0:
                c.set(x, y, C["WOOD"])
    if header:
        c.rect(3, 5, w - 6, 2, C["DOOR_BLUE"])
        # A timetable: a grid of small cells.
        for col in range(4, w - 4, 4):
            for row in range(8, 12, 2):
                c.rect(col, row, 3, 1, C["WHITE"])
    else:
        sheets = [(4, 5, 4, 5), (9, 6, 4, 4)] if w == T else [(4, 5, 5, 6), (11, 6, 4, 4), (17, 5, 5, 5), (24, 6, 4, 5)]
        for sx, sy, sw, sh in sheets:
            c.rect(sx, sy, sw, sh, C["WHITE"])
            for ly in range(sy + 1, sy + sh - 1, 2):
                c.hline(sx + 1, ly, sw - 2, C["GREY_MID"])
            c.set(sx + sw // 2, sy, C["RED_BRIGHT"])
    c.frame(1, 3, w - 2, 11, C["WOOD_DARK"])
    c.frame(0, 2, w, 13, O)
    return c


def blackboard() -> Canvas:
    w = 4 * T
    c = Canvas(w, T)
    c.rect(2, 3, w - 4, 9, C["BOARD_GREEN"])
    c.hline(3, 4, w - 6, C["BOARD_GREEN_LIGHT"])
    # Chalk: a title, a few lines, a little diagram.
    for x0, y0, length in [(5, 5, 14), (5, 7, 22), (5, 9, 18), (34, 6, 10), (48, 8, 9)]:
        for x in range(x0, x0 + length):
            if (x * 7) % 5 != 0:
                c.set(x, y0, C["MIST"])
    c.frame(33, 5, 12, 5, C["SKY_LIGHT"])
    c.frame(1, 2, w - 2, 11, C["WOOD"])
    c.frame(0, 1, w, 13, O)
    c.rect(4, 13, w - 8, 2, C["WOOD_LIGHT"])
    c.hline(4, 15, w - 8, O)
    c.rect(10, 13, 3, 1, C["WHITE"])
    c.rect(40, 13, 2, 1, C["SAND_LIGHT"])
    return c


def wall_clock() -> Canvas:
    c = Canvas(T, T)
    c.disc(8, 8, 5.2, O)
    c.disc(8, 8, 4.2, C["WHITE"])
    c.set(8, 5, O)
    c.set(8, 6, O)
    c.set(8, 7, O)
    c.set(9, 8, O)
    c.set(10, 8, O)
    c.set(7, 9, C["RED_BRIGHT"])
    c.set(8, 8, C["DOOR_BLUE_DARK"])
    return c


def staffing_chart() -> Canvas:
    w = 2 * T
    c = Canvas(w, T)
    c.rect(2, 2, w - 4, 12, C["WHITE"])
    c.vline(4, 3, 9, O)
    c.hline(4, 12, w - 8, O)
    for i, height in enumerate([8, 5, 4, 6, 4, 3]):
        c.rect(6 + i * 4, 12 - height, 3, height, C["DOOR_BLUE"])
    for x in range(5, w - 4, 2):
        c.set(x, 6, C["RED_BRIGHT"])
    c.frame(1, 1, w - 2, 14, O)
    return c


def door_leaves() -> Canvas:
    """An open pair of blue doors and their lintel, over a doorway."""
    c = Canvas(T, T)
    c.rect(0, 0, T, 3, C["DOOR_BLUE"])
    c.hline(0, 0, T, O)
    c.hline(0, 1, T, C["DOOR_BLUE_LIGHT"])
    c.hline(0, 3, T, O)
    c.rect(0, 4, T, 3, with_alpha(O, 60))
    return c


def doorway_post(left: bool) -> Canvas:
    """The blue door folded open against the doorway's side."""
    c = Canvas(T, T)
    x = 0 if left else T - 4
    c.rect(x, 3, 4, 12, C["DOOR_BLUE"])
    c.vline(x + (1 if left else 2), 4, 10, C["DOOR_BLUE_LIGHT"])
    c.rect(x + 1, 6, 2, 3, C["DOOR_BLUE_DARK"])
    c.rect(x + 1, 10, 2, 3, C["DOOR_BLUE_DARK"])
    c.frame(x, 3, 4, 13, O)
    return c


def gate_bars() -> Canvas:
    c = Canvas(T, T)
    for x in (1, 5, 9, 13):
        c.rect(x, 2, 2, 13, C["DOOR_BLUE"])
        c.set(x, 3, C["DOOR_BLUE_LIGHT"])
        c.rect(x, 0, 2, 2, C["SAND"])
    c.rect(0, 5, T, 2, C["DOOR_BLUE_DARK"])
    c.rect(0, 12, T, 2, C["DOOR_BLUE_DARK"])
    c.hline(0, 5, T, C["DOOR_BLUE_LIGHT"])
    c.outline(O)
    c.hline(0, 15, T, O)
    return c


# ---------------------------------------------------------------------------
# Drawn props.


def box(c: Canvas, x: int, y: int, w: int, h: int, top: int, top_colour, front_colour, top_light=None, front_dark=None) -> None:
    """A block seen in three-quarter view: a lit top face over a front face."""
    c.rect(x, y, w, top, top_colour)
    c.rect(x, y + top, w, h - top, front_colour)
    if top_light:
        c.hline(x, y, w, top_light)
    if front_dark:
        c.hline(x, y + h - 1, w, front_dark)
    c.hline(x, y + top, w, front_dark or front_colour)


def filing_cabinet() -> Canvas:
    c = Canvas(T, T)
    box(c, 3, 1, 10, 14, 3, C["SKY_LIGHT"], C["STEEL"], C["WHITE"], C["STEEL_DARK"])
    for y in (5, 9):
        c.hline(4, y + 3, 8, C["STEEL_DARK"])
    for y in (5, 9, 13):
        c.rect(7, y, 2, 1, O)
    c.vline(4, 4, 10, C["SKY_LIGHT"])
    c.outline(O)
    return c


def desk(width_tiles: int, teacher: bool = False) -> Canvas:
    w = width_tiles * T
    c = Canvas(w, T)
    box(c, 1, 2, w - 2, 11, 6, C["WOOD_LIGHT"], C["WOOD"], C["SAND"], C["WOOD_DARK"])
    c.rect(2, 13, 2, 2, C["WOOD_DARK"])
    c.rect(w - 4, 13, 2, 2, C["WOOD_DARK"])
    # Drawers on the right.
    c.frame(w - 13, 9, 10, 3, C["WOOD_DARK"])
    c.rect(w - 9, 10, 2, 1, C["SAND_LIGHT"])
    # Papers, and a phone or a pile of books.
    c.rect(4, 3, 7, 4, C["WHITE"])
    c.hline(5, 4, 5, C["GREY_MID"])
    c.hline(5, 6, 4, C["GREY_MID"])
    if teacher:
        c.rect(w - 12, 2, 7, 2, C["RED"])
        c.rect(w - 11, 4, 7, 2, C["DOOR_BLUE"])
        c.rect(w - 12, 6, 7, 1, C["LEAF"])
        c.rect(14, 4, 4, 3, C["SAND_LIGHT"])
    else:
        c.rect(w - 11, 4, 6, 3, C["SLATE"])
        c.rect(w - 10, 3, 4, 1, C["NIGHT"])
        c.rect(15, 3, 3, 3, C["RED_BRIGHT"])
        c.set(15, 3, C["WHITE"])
    c.outline(O)
    return c


def school_desk() -> Canvas:
    """A double desk with its two chairs, seen from behind the pupils."""
    w = 2 * T
    c = Canvas(w, T)
    box(c, 1, 1, w - 2, 7, 4, C["WOOD_LIGHT"], C["WOOD"], C["SAND"], C["WOOD_DARK"])
    c.rect(2, 8, 2, 4, C["STEEL_DARK"])
    c.rect(w - 4, 8, 2, 4, C["STEEL_DARK"])
    c.rect(5, 2, 6, 2, C["WHITE"])
    c.set(8, 2, C["GREY_MID"])
    c.rect(20, 2, 4, 2, C["DOOR_BLUE_LIGHT"])
    for cx in (6, 20):
        c.rect(cx, 9, 7, 4, C["DOOR_BLUE"])
        c.hline(cx, 9, 7, C["DOOR_BLUE_LIGHT"])
        c.rect(cx, 13, 1, 2, C["STEEL_DARK"])
        c.rect(cx + 6, 13, 1, 2, C["STEEL_DARK"])
    c.outline(O)
    return c


def staff_table() -> Canvas:
    w, h = 3 * T, 2 * T
    c = Canvas(w, h)
    # Chair backs behind the table.
    for cx in (6, 20, 34):
        c.rect(cx, 1, 8, 5, C["WOOD_DARK"])
        c.hline(cx, 1, 8, C["WOOD"])
    box(c, 1, 5, w - 2, 20, 15, C["WOOD_LIGHT"], C["WOOD"], C["SAND"], C["WOOD_DARK"])
    for y in (10, 15):
        c.hline(2, y, w - 4, C["SAND_DARK"])
    c.rect(2, 25, 3, 5, C["WOOD_DARK"])
    c.rect(w - 5, 25, 3, 5, C["WOOD_DARK"])
    # Papers, cups, a laptop.
    c.rect(5, 7, 8, 6, C["WHITE"])
    c.hline(6, 9, 6, C["GREY_MID"])
    c.hline(6, 11, 5, C["GREY_MID"])
    c.rect(18, 8, 10, 6, C["SLATE"])
    c.rect(19, 9, 8, 4, C["SKY"])
    c.rect(33, 9, 3, 3, C["WHITE"])
    c.set(34, 10, C["WOOD_DARK"])
    c.rect(39, 14, 3, 3, C["RED_BRIGHT"])
    c.rect(10, 15, 7, 5, C["SAND_LIGHT"])
    c.outline(O)
    return c


def steel_cabinet() -> Canvas:
    w = h = 2 * T
    c = Canvas(w, h)
    box(c, 2, 2, w - 4, h - 3, 4, C["SKY_LIGHT"], C["STEEL"], C["WHITE"], C["STEEL_DARK"])
    c.vline(15, 6, h - 8, C["STEEL_DARK"])
    c.vline(16, 6, h - 8, C["SKY_LIGHT"])
    c.vline(3, 6, h - 8, C["SKY_LIGHT"])
    for y in (9, 22):
        c.hline(5, y, 8, C["STEEL_DARK"])
        c.hline(19, y, 8, C["STEEL_DARK"])
    # A chain across the doors and a big padlock.
    for x in range(4, w - 4, 2):
        c.set(x, 15 + (x // 2) % 2, C["GREY_LIGHT"])
    c.rect(13, 14, 6, 2, O)
    c.frame(14, 12, 4, 4, O)
    c.rect(12, 16, 8, 6, C["SAND"])
    c.hline(12, 16, 8, C["SAND_LIGHT"])
    c.hline(12, 21, 8, C["WOOD"])
    c.rect(15, 18, 2, 2, O)
    c.frame(11, 15, 10, 8, O)
    # A red "sealed" label.
    c.rect(22, 25, 5, 3, C["FLAG_RED"])
    c.outline(O)
    return c


def envelope_table() -> Canvas:
    w = 2 * T
    c = Canvas(w, T)
    box(c, 1, 5, w - 2, 9, 5, C["WOOD_LIGHT"], C["WOOD"], C["SAND"], C["WOOD_DARK"])
    c.rect(2, 14, 2, 2, C["WOOD_DARK"])
    c.rect(w - 4, 14, 2, 2, C["WOOD_DARK"])
    # Stacks of sealed exam envelopes, each with a red seal.
    for sx, sy, layers in [(3, 4, 3), (12, 3, 4), (21, 5, 2)]:
        for i in range(layers):
            y = sy + 3 - i * 2
            c.rect(sx, y, 8, 3, C["SAND_LIGHT"] if i % 2 == 0 else C["SAND"])
            c.hline(sx, y + 2, 8, C["SAND_DARK"])
        c.rect(sx + 3, sy + 4 - (layers - 1) * 2, 2, 2, C["FLAG_RED"])
    c.outline(O)
    return c


def boxes() -> Canvas:
    c = Canvas(T, T)
    box(c, 2, 4, 12, 11, 4, C["SAND"], C["WOOD_LIGHT"], C["SAND_LIGHT"], C["WOOD"])
    c.vline(7, 4, 4, C["SAND_LIGHT"])
    c.vline(8, 4, 11, C["SAND_DARK"])
    c.rect(4, 10, 3, 2, C["WHITE"])
    c.outline(O)
    return c


def bin_() -> Canvas:
    c = Canvas(T, T)
    c.rect(4, 6, 8, 9, C["LEAF_DARK"])
    c.rect(4, 6, 8, 2, C["PINE_DARK"])
    c.hline(4, 6, 8, C["LEAF"])
    c.vline(5, 8, 6, C["LEAF"])
    c.rect(6, 5, 3, 1, C["WHITE"])
    c.outline(O)
    return c


def bench() -> Canvas:
    w = 2 * T
    c = Canvas(w, T)
    # Backrest, then the seat, on iron legs.
    c.rect(2, 1, w - 4, 2, C["WOOD_LIGHT"])
    c.rect(2, 4, w - 4, 2, C["WOOD_LIGHT"])
    c.hline(2, 2, w - 4, C["WOOD"])
    c.hline(2, 5, w - 4, C["WOOD"])
    c.rect(4, 3, 2, 4, C["STEEL_DARK"])
    c.rect(w - 6, 3, 2, 4, C["STEEL_DARK"])
    c.rect(1, 7, w - 2, 4, C["SAND"])
    c.hline(1, 7, w - 2, C["SAND_LIGHT"])
    c.hline(1, 10, w - 2, C["WOOD"])
    c.rect(3, 11, 2, 4, C["STEEL_DARK"])
    c.rect(w - 5, 11, 2, 4, C["STEEL_DARK"])
    c.outline(O)
    return c


def flagpole() -> Canvas:
    c = Canvas(T, 3 * T)
    c.rect(6, 3, 2, 39, C["STEEL"])
    c.vline(6, 3, 39, C["WHITE"])
    c.rect(5, 1, 4, 3, C["SAND"])
    c.set(5, 1, C["SAND_LIGHT"])
    # The flag of Tunisia: red, a white disc, a red crescent and star.
    c.rect(8, 3, 8, 7, C["FLAG_RED"])
    c.vline(15, 4, 7, C["FLAG_RED"])
    c.disc(11.5, 6.5, 2.6, C["WHITE"])
    c.set(10, 5, C["FLAG_RED"])
    c.set(10, 6, C["FLAG_RED"])
    c.set(10, 7, C["FLAG_RED"])
    c.set(11, 8, C["FLAG_RED"])
    c.set(11, 4, C["FLAG_RED"])
    c.set(12, 6, C["FLAG_RED"])
    # A stone base.
    box(c, 2, 40, 10, 7, 3, C["WALL_CREAM"], C["WALL_SHADE"], C["WALL_WHITE"], C["WALL_DEEP"])
    c.outline(O)
    return c


def shaded_blob(c: Canvas, discs: list[tuple[float, float, float]], light, mid, dark, speck, y_limit: int) -> None:
    """A leafy crown: discs merged, lit from the top-left, with leaf specks."""
    mask = Canvas(c.width, c.height)
    for cx, cy, r in discs:
        mask.disc(cx, cy, r, light)
    top = min(cy - r for _, cy, r in discs)
    for y in range(c.height):
        for x in range(c.width):
            if mask.opaque(x, y) and y <= y_limit:
                depth = (y - top) / max(1.0, y_limit - top) + (x / c.width) * 0.35
                colour = light if depth < 0.42 else (mid if depth < 0.85 else dark)
                if random.random() < 0.12:
                    colour = speck if colour != light else mid
                c.set(x, y, colour)


def olive_tree() -> Canvas:
    c = Canvas(2 * T, 2 * T)
    # A gnarled trunk splitting in two.
    for y in range(17, 30):
        spread = 0 if y > 24 else (24 - y) // 3
        c.rect(14 - spread, y, 3, 1, C["GREY_MID"])
        c.rect(16 + spread, y, 3, 1, C["GREY"])
    c.rect(13, 28, 7, 2, C["GREY"])
    c.set(12, 29, C["GREY_DARK"])
    c.set(20, 29, C["GREY_DARK"])
    shaded_blob(c, [(10, 9, 7.5), (20, 8, 7.5), (16, 13, 8), (7, 15, 5), (25, 14, 5.5)],
                C["SAGE_LIGHT"], C["SAGE"], C["SAGE_DARK"], C["LEAF_DARK"], 20)
    for x, y in [(9, 12), (19, 10), (23, 15), (13, 16)]:
        c.set(x, y, C["NIGHT"])
    c.outline(O)
    return c


def palm_tree() -> Canvas:
    c = Canvas(2 * T, 3 * T)
    # A ringed trunk, leaning a little.
    for y in range(14, 46):
        x = 14 + (46 - y) // 14
        c.rect(x, y, 4, 1, C["WOOD_LIGHT"] if (y // 2) % 2 else C["WOOD"])
        c.set(x + 3, y, C["WOOD_DARK"])
    # Dates under the crown.
    for x, y in [(13, 15), (15, 16), (18, 15), (20, 16), (16, 18)]:
        c.rect(x, y, 2, 2, C["ORANGE_DARK"])
    # Fronds from the crown.
    centre = (16, 12)
    fronds = [(-14, 6), (-12, -3), (-5, -10), (4, -11), (12, -4), (14, 6), (-8, 11), (8, 11)]
    for dx, dy in fronds:
        steps = 14
        for i in range(steps + 1):
            t = i / steps
            x = centre[0] + dx * t
            y = centre[1] + dy * t + 4 * t * t
            width = 2.2 * (1 - t) + 0.8
            c.disc(x, y, width, C["LEAF"] if i % 3 else C["LEAF_LIGHT"])
            if i > 2:
                c.set(int(x), int(y + width), C["LEAF_DARK"])
    c.disc(16, 12, 3, C["LEAF_DARK"])
    c.outline(O)
    return c


def booth() -> Canvas:
    w = h = 2 * T
    c = Canvas(w, h)
    # A flat blue roof over white walls.
    c.rect(1, 2, w - 2, 6, C["DOOR_BLUE_LIGHT"])
    c.rect(1, 6, w - 2, 2, C["DOOR_BLUE_DARK"])
    c.hline(1, 2, w - 2, C["SKY_LIGHT"])
    c.rect(3, 8, w - 6, 22, C["WALL_WHITE"])
    c.vline(3, 8, 22, C["WALL_CREAM"])
    c.hline(3, 8, w - 6, C["WALL_SHADE"])
    c.rect(3, 26, w - 6, 3, C["DOOR_BLUE"])
    # The window the guard looks out of, and the door.
    c.rect(5, 11, 11, 8, C["DOOR_BLUE"])
    c.rect(6, 12, 9, 6, C["SKY_LIGHT"])
    c.rect(6, 15, 9, 3, C["SKY"])
    c.set(7, 13, C["WHITE"])
    c.hline(5, 19, 11, C["WALL_DEEP"])
    c.rect(19, 12, 8, 17, C["DOOR_BLUE"])
    c.vline(20, 13, 15, C["DOOR_BLUE_LIGHT"])
    c.rect(21, 14, 4, 5, C["DOOR_BLUE_DARK"])
    c.rect(21, 21, 4, 5, C["DOOR_BLUE_DARK"])
    c.set(25, 20, C["SAND"])
    c.frame(5, 11, 11, 8, O)
    c.frame(19, 12, 8, 17, O)
    c.rect(3, 29, w - 6, 1, C["DOOR_BLUE_DARK"])
    c.outline(O)
    return c


def photocopier() -> Canvas:
    c = Canvas(T, T)
    box(c, 1, 3, 14, 12, 5, C["MIST"], C["SAGE_LIGHT"], C["WHITE"], C["SAGE"])
    c.rect(3, 4, 6, 2, C["SLATE"])
    c.rect(10, 4, 3, 1, C["LEAF"])
    c.rect(3, 10, 10, 2, C["WHITE"])
    c.hline(3, 12, 10, C["SAGE"])
    c.rect(1, 15, 2, 1, O)
    c.outline(O)
    return c


def water_cooler() -> Canvas:
    c = Canvas(T, 2 * T)
    c.rect(4, 3, 8, 11, C["SKY"])
    c.rect(5, 4, 6, 9, C["SKY_LIGHT"])
    c.vline(5, 4, 8, C["WHITE"])
    c.rect(6, 1, 4, 2, C["DOOR_BLUE"])
    c.rect(3, 14, 10, 16, C["WHITE"])
    c.vline(12, 14, 16, C["MIST"])
    c.hline(3, 14, 10, C["SAGE_LIGHT"])
    c.rect(5, 18, 2, 2, C["DOOR_BLUE"])
    c.rect(9, 18, 2, 2, C["RED_BRIGHT"])
    c.rect(5, 22, 6, 1, C["SAGE"])
    c.outline(O)
    return c


def flag_stand() -> Canvas:
    c = Canvas(T, 2 * T)
    c.rect(4, 4, 1, 25, C["SAND"])
    c.rect(5, 4, 9, 10, C["FLAG_RED"])
    c.disc(9.5, 9, 2.8, C["WHITE"])
    c.set(8, 8, C["FLAG_RED"])
    c.set(8, 9, C["FLAG_RED"])
    c.set(9, 10, C["FLAG_RED"])
    c.set(10, 8, C["FLAG_RED"])
    c.vline(13, 6, 9, C["WINE"])
    c.rect(3, 2, 3, 2, C["SAND_LIGHT"])
    c.rect(2, 28, 6, 2, C["WOOD_DARK"])
    c.outline(O)
    return c


def lockers() -> Canvas:
    c = Canvas(T, 2 * T)
    box(c, 1, 2, 14, 29, 3, C["SKY_LIGHT"], C["TEAL"], C["WHITE"], C["TEAL_DARK"])
    c.vline(8, 5, 25, C["TEAL_DARK"])
    for x in (3, 10):
        for y in (7, 9, 11):
            c.rect(x, y, 3, 1, C["TEAL_DARK"])
        c.rect(x + 2, 17, 1, 3, C["SAND"])
    c.outline(O)
    return c


def tea_table() -> Canvas:
    """A low table with a teapot and small glasses of mint tea."""
    c = Canvas(T, T)
    box(c, 1, 7, 14, 6, 3, C["WOOD_LIGHT"], C["WOOD"], C["SAND"], C["WOOD_DARK"])
    c.rect(2, 13, 2, 2, C["WOOD_DARK"])
    c.rect(12, 13, 2, 2, C["WOOD_DARK"])
    c.rect(4, 3, 5, 4, C["STEEL"])
    c.hline(4, 3, 5, C["WHITE"])
    c.rect(5, 2, 3, 1, C["STEEL_DARK"])
    c.set(9, 4, C["STEEL"])
    c.set(10, 3, C["STEEL"])
    for x in (10, 12):
        c.rect(x, 6, 2, 2, C["LEAF"])
        c.set(x, 6, C["SKY_LIGHT"])
    c.outline(O)
    return c


def rug(w_tiles: int, h_tiles: int) -> Canvas:
    """A red mergoum with a woven border and diamonds."""
    w, h = w_tiles * T, h_tiles * T
    c = Canvas(w, h)
    c.rect(2, 2, w - 4, h - 4, C["RED"])
    c.frame(3, 3, w - 6, h - 6, C["SAND"])
    c.frame(5, 5, w - 10, h - 10, C["WINE"])
    for cx in range(14, w - 8, 14):
        for cy in range(14, h - 8, 12):
            for d in range(4):
                for sx, sy in ((d, 4 - d), (-d, 4 - d), (d, d - 4), (-d, d - 4)):
                    c.set(cx + sx, cy + sy, C["SAND_LIGHT"])
            c.set(cx, cy, C["DOOR_BLUE"])
    for x in range(2, w - 2, 2):
        c.set(x, 1, C["SAND_LIGHT"])
        c.set(x, h - 2, C["SAND_LIGHT"])
    return c


# ---------------------------------------------------------------------------
# Grass beds: the pack's grass inside a stone kerb.


def grass_tile(variant: Canvas, n: bool, e: bool, s: bool, w: bool) -> Canvas:
    c = variant.crop(0, 0, T, T)
    kerb, kerb_top = C["WALL_DEEP"], C["WALL_SHADE"]
    if not n:
        c.hline(0, 0, T, O)
        c.hline(0, 1, T, kerb_top)
        c.hline(0, 2, T, kerb)
    if not s:
        c.hline(0, T - 3, T, kerb_top)
        c.hline(0, T - 2, T, kerb)
        c.hline(0, T - 1, T, O)
    if not w:
        c.vline(0, 0, T, O)
        c.vline(1, 0, T, kerb_top)
        c.vline(2, 0, T, kerb)
    if not e:
        c.vline(T - 3, 0, T, kerb)
        c.vline(T - 2, 0, T, kerb_top)
        c.vline(T - 1, 0, T, O)
    if not n:
        c.hline(0, 0, T, O)
    if not s:
        c.hline(0, T - 1, T, O)
    return c


# ---------------------------------------------------------------------------
# Building the map.


FLOORS = {
    "a": [("Interior/TilesetInteriorFloor.png", 12, 1)],
    "r": [("Interior/TilesetInteriorFloor.png", 1, 1)],
    "s": [("Interior/TilesetInteriorFloor.png", 1, 7)],
    "d": [("Interior/TilesetInteriorFloor.png", x, y) for x in (5, 6) for y in (13, 14, 15)],
    "c": [("TilesetFloor.png", 1, 1)],
}
FLOOR_DETAIL = {
    "pebbles": ("TilesetFloor.png", 1, 4),
    "crack": ("TilesetFloor.png", 0, 4),
    "tuft": ("TilesetFloorDetail.png", 3, 2),
    "flower_white": ("TilesetFloorDetail.png", 5, 2),
}
GRASS = [("TilesetFloor.png", 0, 12)] * 4 + [("TilesetFloor.png", x, 12) for x in (1, 2, 3)] + [("TilesetFloor.png", 3, 11)]


def is_wall(x: int, y: int) -> bool:
    return 0 <= x < WIDTH and 0 <= y < HEIGHT and FLOOR_MAP[y][x] == "#"


def is_face(x: int, y: int) -> bool:
    return is_wall(x, y) and 0 <= y + 1 < HEIGHT and FLOOR_MAP[y + 1][x] not in "#G"


def in_bed(x: int, y: int) -> bool:
    return any(bx <= x < bx + bw and by <= y < by + bh for bx, by, bw, bh in GRASS_BEDS)


def in_path(x: int, y: int) -> bool:
    return any(px <= x < px + pw and py <= y < py + ph for px, py, pw, ph in PATHS) and FLOOR_MAP[y][x] in "cpG"


def paving(n: bool, e: bool, s: bool, w: bool, odd: int) -> Canvas:
    """Stone slabs in a running bond, with a darker edge against the sand."""
    c = Canvas(T, T)
    c.rect(0, 0, T, T, C["WALL_SHADE"])
    for row in range(2):
        y0 = row * 8
        shift = 4 if (row + odd) % 2 else 0
        c.hline(0, y0, T, C["WALL_DEEP"])
        for x0 in (shift, shift + 8):
            c.vline(x0 % T, y0, 8, C["WALL_DEEP"])
        c.hline(0, y0 + 1, T, C["WALL_CREAM"])
    if (odd + 1) % 2:
        c.rect(9, 10, 6, 5, C["SAND_DARK"])
    for flag, line in ((n, lambda: c.hline(0, 0, T, C["GREY_LIGHT"])), (s, lambda: c.hline(0, T - 1, T, C["GREY_LIGHT"])),
                       (w, lambda: c.vline(0, 0, T, C["GREY_LIGHT"])), (e, lambda: c.vline(T - 1, 0, T, C["GREY_LIGHT"]))):
        if not flag:
            line()
    return c


def build(check_only: bool = False) -> None:
    atlas = Atlas()
    layers: dict[str, dict[tuple[int, int], tuple[int, int]]] = {"Floor": {}, "Shade": {}, "Walls": {}, "Decor": {}, "Props": {}}
    solid: set[tuple[int, int]] = set()

    def floor_variant(key: tuple[str, int, int]) -> tuple[int, int]:
        sheet, tx, ty = key
        return atlas.add(f"floor:{sheet}:{tx},{ty}", pack_tile(sheet, tx, ty))

    # Floors, grass beds and the gate.
    for y in range(HEIGHT):
        for x in range(WIDTH):
            ch = FLOOR_MAP[y][x]
            if ch == "G":
                layers["Floor"][(x, y)] = atlas.add("paving:(True, True, True, True):0", paving(True, True, True, True, 0))
                layers["Walls"][(x, y)] = atlas.add("gate", gate_bars(), True)
                solid.add((x, y))
            elif ch == "#":
                if is_face(x, y):
                    key = f"face:{is_wall(x, y - 1)}{is_wall(x + 1, y)}{is_wall(x - 1, y)}"
                    tile = wall_face(is_wall(x, y - 1), is_wall(x + 1, y), is_wall(x - 1, y))
                else:
                    n, e, s, w = (is_wall(x, y - 1) or y == 0, is_wall(x + 1, y) or x == WIDTH - 1, is_wall(x, y + 1) or y == HEIGHT - 1 or FLOOR_MAP[min(y + 1, HEIGHT - 1)][x] == "G", is_wall(x - 1, y) or x == 0)
                    key = f"cap:{n}{e}{s}{w}"
                    tile = wall_cap(n, e, s, w)
                layers["Walls"][(x, y)] = atlas.add(key, tile, True)
                solid.add((x, y))
            elif in_path(x, y) and ch in "cp":
                edge = (in_path(x, y - 1), in_path(x + 1, y), in_path(x, y + 1), in_path(x - 1, y))
                layers["Floor"][(x, y)] = atlas.add(f"paving:{edge}:{(x + y) % 2}", paving(*edge, (x + y) % 2))
            elif in_bed(x, y) and ch == "c":
                variant = random.choice(GRASS)
                sheet, tx, ty = variant
                edge = (in_bed(x, y - 1), in_bed(x + 1, y), in_bed(x, y + 1), in_bed(x - 1, y))
                if all(edge):
                    layers["Floor"][(x, y)] = floor_variant(variant)
                else:
                    base = ("TilesetFloor.png", 0, 12)
                    layers["Floor"][(x, y)] = atlas.add(f"grass:{edge}", grass_tile(pack_tile(*base), *edge))
            else:
                options = FLOORS[ch]
                layers["Floor"][(x, y)] = floor_variant(random.choice(options))
            # A soft shadow on the floor under each wall face.
            if ch != "#" and ch != "G" and is_wall(x, y - 1):
                layers["Shade"][(x, y)] = atlas.add("shadow", wall_shadow())

    # Doorways through the rooms' south walls get open blue doors.
    for x, y, side in DOORWAYS:
        layers["Decor"][(x, y)] = atlas.add(f"door{side}", _merge(door_leaves(), doorway_post(side == "L")))

    # Wall decorations.
    makers = {
        "window": lambda: window(), "notice": lambda: notice_board(), "clock": lambda: wall_clock(),
        "blackboard": blackboard, "chart": staffing_chart, "timetable": lambda: notice_board(2, header=True),
    }
    for name, x, y in WALL_DECOR:
        art = makers[name]()
        for i in range(art.width // T):
            assert is_face(x + i, y), f"{name} at {x + i},{y} is not on a wall face"
            layers["Decor"][(x + i, y)] = atlas.add(f"{name}_{i}", art.crop(i * T, 0, T, T))

    for rx, ry, rw, rh in RUGS:
        art = rug(rw, rh)
        for ty in range(rh):
            for tx in range(rw):
                layers["Decor"][(rx + tx, ry + ty)] = atlas.add(f"rug{rw}x{rh}_{tx}_{ty}", art.crop(tx * T, ty * T, T, T))

    for name, x, y in FLOOR_DECOR:
        sheet, tx, ty = FLOOR_DETAIL[name]
        layers["Decor"][(x, y)] = atlas.add(f"detail:{name}", pack_tile(sheet, tx, ty))

    # Props.
    drawn = {
        "filing": (filing_cabinet, None), "office_desk": (lambda: desk(2), None), "teacher_desk": (lambda: desk(2, True), None),
        "school_desk": (school_desk, None), "staff_table": (staff_table, None), "steel_cabinet": (steel_cabinet, None),
        "envelope_table": (envelope_table, None), "boxes": (boxes, None), "bin": (bin_, None), "bench": (bench, None),
        "photocopier": (photocopier, None), "water_cooler": (water_cooler, {1}), "flag_stand": (flag_stand, {1}),
        "lockers": (lockers, None), "tea_table": (tea_table, None),
        "flag": (flagpole, {2}), "olive": (olive_tree, {1}), "palm": (palm_tree, {2}), "booth": (booth, None),
    }
    from_pack = {
        "plant": (("TilesetElement.png", 0, 7, 1, 2), {1}),
        "bookshelf": (("TilesetElement.png", 8, 7, 2, 2), None),
        "dresser": (("TilesetElement.png", 6, 7, 2, 2), None),
        "drawers": (("TilesetElement.png", 1, 7, 1, 2), None),
        "bush": (("TilesetNature.png", 1, 10, 1, 1), None),
        "bush_round": (("TilesetNature.png", 6, 10, 1, 1), None),
        "sunflower": (("TilesetNature.png", 1, 11, 1, 1), None),
        "flower_red": (("TilesetNature.png", 3, 11, 1, 1), None),
    }
    cache: dict[str, list] = {}
    for name, x, y in PROPS:
        if name not in cache:
            if name in drawn:
                maker, rows = drawn[name]
                cache[name] = add_object(atlas, name, maker(), rows)
            else:
                (sheet, tx, ty, w, h), rows = from_pack[name]
                cache[name] = add_object(atlas, name, pack_tile(sheet, tx, ty, w, h), rows)
        tiles = cache[name]
        for ry, row in enumerate(tiles):
            for rx, coords in enumerate(row):
                cell = (x + rx, y + ry)
                assert FLOOR_MAP[cell[1]][cell[0]] not in "#G", f"{name} at {cell} sits on a wall"
                assert cell not in layers["Props"], f"{name} at {cell} overlaps another prop"
                layers["Props"][cell] = coords
                if atlas.meta[atlas.index[_key_at(atlas, coords)]]["solid"]:
                    solid.add(cell)

    check_map(solid, set(layers["Props"]))
    if check_only:
        return
    ATLAS_PATH.parent.mkdir(parents=True, exist_ok=True)
    atlas.image().save(ATLAS_PATH)
    write_tileset(atlas)
    write_layers(layers)
    title_backdrop().image().save(TITLE_PATH)
    print(f"atlas: {len(atlas.tiles)} tiles in {ATLAS_PATH.relative_to(ROOT)}")
    print(f"layers: " + ", ".join(f"{k} {len(v)} cells" for k, v in layers.items()))


def _key_at(atlas: Atlas, coords: tuple[int, int]) -> str:
    return atlas.meta[coords[1] * ATLAS_COLUMNS + coords[0]]["key"]


def _merge(under: Canvas, over: Canvas) -> Canvas:
    out = under.crop(0, 0, under.width, under.height)
    out.blit(over, 0, 0)
    return out


def title_backdrop() -> Canvas:
    """The title screen's picture: the lycée's front under a bright sky, from the map's pieces."""
    w, h = 320, 180
    c = Canvas(w, h)
    # Sky, lighter towards the horizon, with a few clouds.
    for y in range(80):
        c.hline(0, y, w, C["SKY"] if y < 30 else (C["SKY_LIGHT"] if y < 62 else C["MIST"]))
    for cx, cy, r in [(40, 18, 7), (52, 16, 9), (64, 19, 6), (250, 28, 8), (262, 25, 10), (276, 29, 7)]:
        c.disc(cx, cy, r, C["WHITE"])
    # The front wall: white render, a roof edge, a blue dado, windows and the gate's door.
    top, bottom = 60, 128
    c.rect(0, top, w, bottom - top, C["WALL_WHITE"])
    c.rect(0, top, w, 5, C["WALL_CREAM"])
    c.hline(0, top, w, O)
    c.hline(0, top + 5, w, O)
    c.hline(0, top + 6, w, C["WALL_SHADE"])
    c.rect(0, bottom - 12, w, 11, C["DOOR_BLUE"])
    c.hline(0, bottom - 12, w, C["DOOR_BLUE_LIGHT"])
    c.hline(0, bottom - 2, w, C["DOOR_BLUE_DARK"])
    c.hline(0, bottom - 1, w, O)
    for x in list(range(8, 120, 26)) + list(range(208, 312, 26)):
        c.blit(window(), x, top + 14)
        c.blit(window(), x, top + 34)
    # A tall blue double door with a lintel, and the flag over it.
    door_x = 136
    c.rect(door_x - 4, top + 8, 56, 4, C["DOOR_BLUE_DARK"])
    c.rect(door_x, top + 12, 48, bottom - top - 12, C["DOOR_BLUE"])
    c.vline(door_x + 24, top + 12, bottom - top - 12, O)
    for px in (door_x + 4, door_x + 28):
        c.frame(px, top + 18, 16, 18, C["DOOR_BLUE_DARK"])
        c.frame(px, top + 40, 16, 20, C["DOOR_BLUE_DARK"])
        c.vline(px + 1, top + 19, 16, C["DOOR_BLUE_LIGHT"])
    c.frame(door_x - 1, top + 11, 50, bottom - top - 11, O)
    pole = flagpole()
    c.blit(pole.crop(0, 0, T, 2 * T), door_x + 16, top - 30)
    # Paving in front, palms and olive trees either side.
    for y in range(bottom, h, T):
        for x in range(0, w, T):
            c.blit(paving(True, True, True, True, (x // T + y // T) % 2), x, y)
    c.blit(palm_tree(), 6, bottom - 40)
    c.blit(palm_tree(), w - 38, bottom - 40)
    c.blit(olive_tree(), 70, bottom - 22)
    c.blit(olive_tree(), w - 102, bottom - 22)
    c.blit(bench(), 40, bottom + 20)
    c.blit(bench(), w - 72, bottom + 20)
    return c


def read_box(scene: Path, shape_id: str) -> tuple[int, int, int, int]:
    """A body's collision box from its scene: (offset x, offset y, width, height) in pixels."""
    text = scene.read_text()
    size = re.search(r'id="' + shape_id + r'"\]\nsize = Vector2\(([\d.]+), ([\d.]+)\)', text)
    if size is None:
        sys.exit(f"no box {shape_id} in {scene.relative_to(ROOT)}")
    node = re.search(r'\[node name="CollisionShape2D"[^\]]*\]\n((?:\w.*\n)*)', text)
    offset = re.search(r"position = Vector2\((-?[\d.]+), (-?[\d.]+)\)", node.group(1)) if node else None
    ox, oy = (int(float(offset.group(1))), int(float(offset.group(2)))) if offset else (0, 0)
    return ox, oy, int(float(size.group(1))), int(float(size.group(2)))


def read_positions(parent: str) -> dict[str, tuple[int, int]]:
    """The position of each node directly under [param parent] in the map, in pixels."""
    found = {}
    pattern = re.compile(r'\[node name="(\w+)"[^\]]*parent="' + parent + r'"[^\]]*\]\n((?:\w.*\n)*)')
    for name, body in pattern.findall(MAP_PATH.read_text()):
        pos = re.search(r"position = Vector2\((-?[\d.]+), (-?[\d.]+)\)", body)
        if pos:
            found[name] = (int(float(pos.group(1))), int(float(pos.group(2))))
    return found


def blocked_centres(rects: list[tuple[int, int, int, int]], box: tuple[int, int, int, int]) -> bytearray:
    """For every pixel of the map, whether a box centred there overlaps any of
    [param rects] (x0, y0, x1, y1). Touching is not overlapping, as in Godot."""
    ox, oy, bw, bh = box
    w, h = WIDTH * T, HEIGHT * T
    grid = bytearray(w * h)
    for x0, y0, x1, y1 in rects:
        # The box spans [cx + ox - bw/2, cx + ox + bw/2]; it overlaps when that
        # interval's inside meets the rect's inside on both axes.
        cx0, cx1 = x0 - ox - bw // 2 + 1, x1 - ox + (bw + 1) // 2 - 1
        cy0, cy1 = y0 - oy - bh // 2 + 1, y1 - oy + (bh + 1) // 2 - 1
        for cy in range(max(cy0, 0), min(cy1, h - 1) + 1):
            row = cy * w
            for cx in range(max(cx0, 0), min(cx1, w - 1) + 1):
                grid[row + cx] = 1
    # Off the map counts as blocked.
    for cy in range(h):
        for cx in range(w):
            if cx + ox - bw // 2 < 0 or cx + ox + (bw + 1) // 2 > w or cy + oy - bh // 2 < 0 or cy + oy + (bh + 1) // 2 > h:
                grid[cy * w + cx] = 1
    return grid


def flood(start: int, can_step) -> bytearray:
    """Every pixel the player's centre can reach from [param start], one pixel at a time."""
    w, h = WIDTH * T, HEIGHT * T
    seen = bytearray(w * h)
    seen[start] = 1
    queue = deque([start])
    while queue:
        i = queue.popleft()
        x, y = i % w, i // w
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if 0 <= x + dx < w and 0 <= y + dy < h:
                j = i + dx + dy * w
                if not seen[j] and can_step(i, j, dx != 0):
                    seen[j] = 1
                    queue.append(j)
    return seen


def check_map(solid: set[tuple[int, int]], prop_cells: set[tuple[int, int]]) -> None:
    """Checks the map can be walked, with the player's real collision box and
    every character standing at any place it can be (its start or a scene spot):

    - every character's spot can be reached, with a tile beside it to talk from;
    - nowhere the player can get to leaves it stuck: from every position its box
      can reach, it can still move in some direction. A box exactly as tall as a
      gap (a tile between a wall and a plant) fits in Godot but cannot slide along
      it, so a move fails when the box touches something on both sides across it;
    - a walkway two tiles wide joins the player's start to both sides of every door;
    - nothing stands within a tile of a doorway, on either side.
    """
    player_box = read_box(PLAYER_SCENE, "RectangleShape2D_body")
    npc_box = read_box(NPC_SCENE, "RectangleShape2D_body")
    spots = read_positions("Spots")
    actors = {name: pos for name, pos in read_positions("Actors").items() if name != "Player"}
    player = read_positions("Actors")["Player"]
    w = WIDTH * T

    # Every place a character can stand is in the way: its start, and every spot.
    stands = set(spots.values()) | set(actors.values())
    nox, noy, nbw, nbh = npc_box
    rects = [(x * T, y * T, (x + 1) * T, (y + 1) * T) for x, y in solid]
    rects += [(sx + nox - nbw // 2, sy + noy - nbh // 2, sx + nox + nbw // 2, sy + noy + nbh // 2) for sx, sy in stands]

    bw, bh = player_box[2], player_box[3]
    body = blocked_centres(rects, player_box)
    start = player[1] * w + player[0]
    problems = []
    if body[start]:
        problems.append(f"the player's start {player} is blocked")

    def pinched(i: int, horizontal: bool) -> bool:
        # Touching something on both sides across the way of moving.
        step = w if horizontal else 1
        return body[i - step] and body[i + step]

    def moves_freely(i: int, j: int, horizontal: bool) -> bool:
        return not body[j] and not pinched(i, horizontal) and not pinched(j, horizontal)

    can_reach = flood(start, lambda i, j, horizontal: not body[j])
    walks = flood(start, moves_freely)

    # Stuck: the box got somewhere it fits, but cannot move from there.
    stuck_tiles: set[tuple[int, int]] = set()
    for i, reached in enumerate(can_reach):
        if not reached:
            continue
        x, y = i % w, i // w
        if not any(0 <= x + dx < w and moves_freely(i, i + dx + dy * w, dx != 0) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
            stuck_tiles.add((x // T, y // T))
    for tile in sorted(stuck_tiles):
        problems.append(f"the player can get stuck at tile {tile}")

    # Each spot and character: reachable, with a tile beside it to talk from.
    for name, (sx, sy) in sorted({**spots, **actors}.items()):
        sides = [(sx + dx * T, sy + dy * T) for dx, dy in ((0, 1), (0, -1), (1, 0), (-1, 0))]
        if not any(0 <= px < w and 0 <= py < HEIGHT * T and walks[py * w + px] for px, py in sides):
            problems.append(f"{name} at tile {(sx // T, sy // T)} has no tile beside it the player can walk to")

    # Two tiles wide: a 2x2 block of free tiles, moved a tile at a time.
    stand_tiles = {(sx // T, sy // T) for sx, sy in stands}
    in_way = solid | stand_tiles

    def block_free(x: int, y: int) -> bool:
        return all(0 <= x + a < WIDTH and 0 <= y + b < HEIGHT and (x + a, y + b) not in in_way for a in (0, 1) for b in (0, 1))

    px, py = player[0] // T, player[1] // T
    first = [(x, y) for x in (px - 1, px) for y in (py - 1, py) if block_free(x, y)]
    seen = set(first)
    queue = deque(first)
    while queue:
        x, y = queue.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nxt = (x + dx, y + dy)
            if nxt not in seen and block_free(*nxt):
                seen.add(nxt)
                queue.append(nxt)
    for a, b, axis in DOOR_GAPS:
        fronts = [(a[0], a[1] - 2), (a[0], a[1] + 1)] if axis == "v" else [(a[0] - 2, a[1]), (a[0] + 1, a[1])]
        for front in fronts:
            if front not in seen:
                problems.append(f"no walkway two tiles wide from the start to the door at {a}, its side at {front}")
        # Nothing within a tile of the doorway, on either side.
        near = {(x, y) for x in range(a[0] - 1, b[0] + 2) for y in range(a[1] - 1, b[1] + 2)} - {a, b}
        for cell in sorted(near & (prop_cells | stand_tiles)):
            problems.append(f"something stands at {cell}, within a tile of the door at {a}")

    if problems:
        sys.exit("map check failed:\n  " + "\n  ".join(problems))
    print(f"map check: the player's {bw}x{bh} box reaches all {len(spots) + len(actors)} spots and characters "
          f"from {(px, py)} and cannot get stuck; every door has a walkway two tiles wide and a clear tile around it")


def write_tileset(atlas: Atlas) -> None:
    lines = [
        "[gd_resource type=\"TileSet\" load_steps=3 format=3]",
        "",
        "[ext_resource type=\"Texture2D\" path=\"res://art/tiles/centre.png\" id=\"1_tiles\"]",
        "",
        "[sub_resource type=\"TileSetAtlasSource\" id=\"TileSetAtlasSource_centre\"]",
        "texture = ExtResource(\"1_tiles\")",
    ]
    for i, meta in enumerate(atlas.meta):
        x, y = i % ATLAS_COLUMNS, i // ATLAS_COLUMNS
        lines.append(f"{x}:{y}/0 = 0")
        if meta["sort"]:
            lines.append(f"{x}:{y}/0/y_sort_origin = {meta['sort']}")
        if meta["solid"]:
            lines.append(f"{x}:{y}/0/physics_layer_0/polygon_0/points = PackedVector2Array(-8, -8, 8, -8, 8, 8, -8, 8)")
    lines += [
        "",
        "[resource]",
        "physics_layer_0/collision_layer = 1",
        "physics_layer_0/collision_mask = 0",
        "sources/0 = SubResource(\"TileSetAtlasSource_centre\")",
        "",
    ]
    TILESET_PATH.write_text("\n".join(lines))


def write_layers(layers: dict[str, dict[tuple[int, int], tuple[int, int]]]) -> None:
    """Replace each TileMapLayer's tile_map_data in centre.tscn."""
    text = MAP_PATH.read_text()
    for name, cells in layers.items():
        data = bytearray(struct.pack("<H", 0))
        for (x, y), (ax, ay) in sorted(cells.items(), key=lambda item: (item[0][1], item[0][0])):
            data += struct.pack("<hhHHHH", x, y, 0, ax, ay, 0)
        encoded = "tile_map_data = PackedByteArray(" + ", ".join(str(b) for b in data) + ")"
        pattern = re.compile(r'(\[node name="' + name + r'" type="TileMapLayer"[^\]]*\]\n)(tile_map_data = PackedByteArray\([^)]*\)\n)?')
        if not pattern.search(text):
            sys.exit(f"no TileMapLayer named {name} in {MAP_PATH.name}")
        text = pattern.sub(lambda m: m.group(1) + encoded + "\n", text, count=1)
    MAP_PATH.write_text(text)


if __name__ == "__main__":
    build(check_only="--check" in sys.argv[1:])
