# /// script
# requires-python = ">=3.11"
# dependencies = ["pillow"]
# ///
"""Makes a "washed-out projector" copy of each screenshot in build/screens/:
blacks lifted to about 25% grey, contrast and saturation cut by about 30%, as
a worn classroom projector shows them. Each copy is saved beside its original
with a _washed suffix.

Run from the project root, after tools/capture_screens.gd:
    uv run tools/washout.py
"""

from pathlib import Path

from PIL import Image, ImageEnhance

SCREENS = Path(__file__).resolve().parent.parent / "build" / "screens"
BLACK_LIFT = 0.25
CONTRAST = 0.7
SATURATION = 0.7


def wash(image: Image.Image) -> Image.Image:
    image = image.convert("RGB")
    image = ImageEnhance.Contrast(image).enhance(CONTRAST)
    image = ImageEnhance.Color(image).enhance(SATURATION)
    # Lift the blacks: map 0..255 to 25%..100%.
    floor = round(255 * BLACK_LIFT)
    return image.point(lambda v: floor + v * (255 - floor) // 255)


def main() -> None:
    originals = sorted(p for p in SCREENS.glob("*.png") if not p.stem.endswith("_washed"))
    for path in originals:
        wash(Image.open(path)).save(path.with_name(path.stem + "_washed.png"))
    print(f"washed out {len(originals)} screenshots in {SCREENS}")


if __name__ == "__main__":
    main()
