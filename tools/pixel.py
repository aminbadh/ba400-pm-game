"""Small pixel-drawing helpers shared by the art generators in tools/.

The colours come from ui/palette.gd, the one place the game's colours live, so
the drawn art and the UI cannot drift apart.
"""

from __future__ import annotations

import re
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
PALETTE_PATH = ROOT / "ui" / "palette.gd"

Colour = tuple[int, int, int, int]
CLEAR: Colour = (0, 0, 0, 0)


def load_palette() -> dict[str, Colour]:
    """Every `const NAME: Color = Color("rrggbb")` in ui/palette.gd, by name."""
    found: dict[str, Colour] = {}
    pattern = re.compile(r'^const (\w+): Color = Color\("([0-9a-fA-F]{6})"\)', re.M)
    for name, hex_ in pattern.findall(PALETTE_PATH.read_text()):
        found[name] = hex_colour(hex_)
    return found


def hex_colour(hex_: str) -> Colour:
    hex_ = hex_.lstrip("#")
    return (int(hex_[0:2], 16), int(hex_[2:4], 16), int(hex_[4:6], 16), 255)


def with_alpha(colour: Colour, alpha: int) -> Colour:
    return (colour[0], colour[1], colour[2], alpha)


class Canvas:
    """A grid of RGBA pixels with the few drawing calls pixel art needs."""

    def __init__(self, width: int, height: int) -> None:
        self.width = width
        self.height = height
        self.px: list[list[Colour]] = [[CLEAR] * width for _ in range(height)]

    def inside(self, x: int, y: int) -> bool:
        return 0 <= x < self.width and 0 <= y < self.height

    def get(self, x: int, y: int) -> Colour:
        return self.px[y][x] if self.inside(x, y) else CLEAR

    def set(self, x: int, y: int, colour: Colour) -> None:
        if self.inside(x, y):
            if colour[3] == 255 or self.px[y][x][3] == 0:
                self.px[y][x] = colour
            else:
                self.px[y][x] = _blend(self.px[y][x], colour)

    def opaque(self, x: int, y: int) -> bool:
        return self.get(x, y)[3] > 0

    def rect(self, x: int, y: int, w: int, h: int, colour: Colour) -> None:
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.set(xx, yy, colour)

    def frame(self, x: int, y: int, w: int, h: int, colour: Colour) -> None:
        self.hline(x, y, w, colour)
        self.hline(x, y + h - 1, w, colour)
        self.vline(x, y, h, colour)
        self.vline(x + w - 1, y, h, colour)

    def hline(self, x: int, y: int, w: int, colour: Colour) -> None:
        for xx in range(x, x + w):
            self.set(xx, y, colour)

    def vline(self, x: int, y: int, h: int, colour: Colour) -> None:
        for yy in range(y, y + h):
            self.set(x, yy, colour)

    def disc(self, cx: float, cy: float, r: float, colour: Colour) -> None:
        for yy in range(int(cy - r) - 1, int(cy + r) + 2):
            for xx in range(int(cx - r) - 1, int(cx + r) + 2):
                if (xx + 0.5 - cx) ** 2 + (yy + 0.5 - cy) ** 2 <= r * r:
                    self.set(xx, yy, colour)

    def blit(self, other: "Canvas", x: int, y: int) -> None:
        for yy in range(other.height):
            for xx in range(other.width):
                c = other.px[yy][xx]
                if c[3]:
                    self.set(x + xx, y + yy, c)

    def grid(self, x: int, y: int, rows: list[str], legend: dict[str, Colour]) -> None:
        """Draw a character grid: each character is a legend key, '.' is clear."""
        for yy, row in enumerate(rows):
            for xx, ch in enumerate(row):
                if ch != "." and ch != " ":
                    self.set(x + xx, y + yy, legend[ch])

    def outline(self, colour: Colour, diagonals: bool = False) -> None:
        """Ring every opaque shape with a 1 px line on the clear pixels around it."""
        around = [(1, 0), (-1, 0), (0, 1), (0, -1)]
        if diagonals:
            around += [(1, 1), (-1, -1), (1, -1), (-1, 1)]
        marks = []
        for yy in range(self.height):
            for xx in range(self.width):
                if self.px[yy][xx][3] == 0 and any(self.opaque(xx + dx, yy + dy) and self.get(xx + dx, yy + dy) != colour for dx, dy in around):
                    marks.append((xx, yy))
        for xx, yy in marks:
            self.px[yy][xx] = colour

    def crop(self, x: int, y: int, w: int, h: int) -> "Canvas":
        out = Canvas(w, h)
        for yy in range(h):
            for xx in range(w):
                out.px[yy][xx] = self.get(x + xx, y + yy)
        return out

    def flipped(self) -> "Canvas":
        out = Canvas(self.width, self.height)
        for yy in range(self.height):
            out.px[yy] = list(reversed(self.px[yy]))
        return out

    def recoloured(self, mapping: dict[Colour, Colour]) -> "Canvas":
        out = Canvas(self.width, self.height)
        for yy in range(self.height):
            out.px[yy] = [mapping.get(c, c) for c in self.px[yy]]
        return out

    def image(self) -> Image.Image:
        img = Image.new("RGBA", (self.width, self.height))
        img.putdata([c for row in self.px for c in row])
        return img

    @staticmethod
    def from_image(img: Image.Image) -> "Canvas":
        img = img.convert("RGBA")
        out = Canvas(img.width, img.height)
        data = list(img.getdata())
        for yy in range(img.height):
            out.px[yy] = [tuple(c) for c in data[yy * img.width:(yy + 1) * img.width]]  # type: ignore[misc]
        return out


def _blend(under: Colour, over: Colour) -> Colour:
    a = over[3] / 255
    return (
        round(over[0] * a + under[0] * (1 - a)),
        round(over[1] * a + under[1] * (1 - a)),
        round(over[2] * a + under[2] * (1 - a)),
        max(under[3], over[3]),
    )
