# /// script
# requires-python = ">=3.11"
# dependencies = ["pillow"]
# ///
"""Draws the UI's pixel art, in the palette of ui/palette.gd:

- art/ui/frame.png: the panel frame, a 16x16 nine-slice with 5 px borders: a
  dark outline, a cream and sand rim, and the opaque dark panel inside;
- art/ui/icons.png: the dashboard's meter icons, 9x9 each, left to right:
  Integrity (a padlock), Fairness (scales), Team (two people), Budget (a coin);
- art/ui/glyphs.png: the icons the pixel font lacks, in white, one per 12x8
  cell in ui/glyphs.gd's order: a tick and a cross for the region's report,
  the controller's cross button and its Start button. ui/glyphs.gd makes
  them a fallback font, so any text can show them and they take its colour.

Run from the project root: uv run tools/draw_ui.py
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pixel import ROOT, Canvas, load_palette, with_alpha  # noqa: E402

C = load_palette()
O = C["OUTLINE"]
UI_DIR = ROOT / "art" / "ui"
FRAME = 16
# The panel inside the frame, at the alpha set in ui/palette.gd (PANEL_ALPHA).
PANEL_ALPHA = 255
ICON = 9
GLYPH_CELL = (12, 8)


def frame() -> Canvas:
    c = Canvas(FRAME, FRAME)
    rings = [O, C["WALL_CREAM"], C["SAND"], C["WOOD_DARK"]]
    for i, colour in enumerate(rings):
        c.frame(i, i, FRAME - 2 * i, FRAME - 2 * i, colour)
    c.rect(4, 4, FRAME - 8, FRAME - 8, with_alpha(C["PANEL"], PANEL_ALPHA))
    # Light from the top-left: the rim is brighter there.
    c.hline(2, 1, FRAME - 4, C["WHITE"])
    c.vline(1, 2, FRAME - 4, C["WHITE"])
    # Rounded corners.
    for x, y in ((0, 0), (FRAME - 1, 0), (0, FRAME - 1), (FRAME - 1, FRAME - 1)):
        c.px[y][x] = (0, 0, 0, 0)
    for x, y in ((1, 1), (FRAME - 2, 1), (1, FRAME - 2), (FRAME - 2, FRAME - 2)):
        c.px[y][x] = O
    return c


def icons() -> Canvas:
    c = Canvas(ICON * 4, ICON)
    legend = {"o": O, "y": C["SAND"], "Y": C["SAND_LIGHT"], "w": C["WOOD"], "b": C["DOOR_BLUE_LIGHT"],
              "B": C["DOOR_BLUE"], "s": C["SKY_LIGHT"], "g": C["LEAF_LIGHT"], "G": C["LEAF"], "r": C["RED_BRIGHT"], "S": C["STEEL"], "W": C["WHITE"]}
    padlock = [
        "...SSS...",
        "..S...S..",
        "..S...S..",
        ".ooooooo.",
        ".oYYYYyo.",
        ".oYYoyyo.",
        ".oyyoyyo.",
        ".oywwwwo.",
        ".ooooooo.",
    ]
    scales = [
        "....W....",
        ".WWWWWWW.",
        ".W..W..W.",
        "W.W.W.W.W",
        "YYY.W.YYY",
        "yyy.W.yyy",
        "....W....",
        "..WWWWW..",
        "..SSSSS..",
    ]
    team = [
        ".ooo.ooo.",
        "oYYoogggo",
        "oYYoogggo",
        ".oooooooo",
        "oBBBoGGGo",
        "oBsBoGgGo",
        "oBBBoGGGo",
        "oBBBoGGGo",
        "ooooooooo",
    ]
    coin = [
        "..ooooo..",
        ".oYYYYyo.",
        "oYYyyyyyo",
        "oYyywyyyo",
        "oYywwwyyo",
        "oYyywyywo",
        "oyyyyywwo",
        ".oywwwwo.",
        "..ooooo..",
    ]
    for i, grid in enumerate([padlock, scales, team, coin]):
        c.grid(i * ICON, 0, grid, legend)
    return c


def glyphs() -> Canvas:
    # Seven rows, like the font's capitals, standing on the cell's bottom edge: the baseline.
    tick = [
        "......#",
        ".....##",
        "#...##.",
        "##.##..",
        ".###...",
        "..#....",
        ".......",
    ]
    ballot = [
        ".....#.",
        "#...##.",
        "##.##..",
        ".###...",
        ".##.#..",
        "##...#.",
        "#.....#",
    ]
    cross = [
        "#.....#",
        "##...##",
        ".##.##.",
        "..###..",
        ".##.##.",
        "##...##",
        "#.....#",
    ]
    start = [
        ".#########.",
        "#...#.....#",
        "#...##....#",
        "#...###...#",
        "#...##....#",
        "#...#.....#",
        ".#########.",
    ]
    width, height = GLYPH_CELL
    order = [tick, ballot, cross, start]
    c = Canvas(width * len(order), height)
    for i, grid in enumerate(order):
        c.grid(i * width, height - len(grid), grid, {"#": C["WHITE"]})
    return c


def main() -> None:
    UI_DIR.mkdir(parents=True, exist_ok=True)
    frame().image().save(UI_DIR / "frame.png")
    icons().image().save(UI_DIR / "icons.png")
    glyphs().image().save(UI_DIR / "glyphs.png")
    print(f"drew frame.png, icons.png and glyphs.png in {UI_DIR.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
