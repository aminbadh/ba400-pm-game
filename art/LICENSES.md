# Art and sound licences

Every image and sound under `art/`, where it comes from and its licence. `uv run tools/check_licenses.py` fails if a file under `art/` is missing here.

## From the Ninja Adventure Asset Pack

[Ninja Adventure Asset Pack](https://pixel-boy.itch.io/ninja-adventure-asset-pack) by [Pixel-boy](https://pixel-boy.itch.io/) and [AAA](https://www.instagram.com/challenger.aaa/), released under **Creative Commons Zero v1.0 Universal** (CC0 1.0): the pack's licence is copied unchanged to [`ninja_adventure/LICENSE.txt`](ninja_adventure/LICENSE.txt). Files are copied unchanged, at their path in the pack under `art/ninja_adventure/`. The tilesets are sources for `tools/build_map.py` (Godot does not import them); the map uses the tiles named.

| Path in the pack | Path in the repo | Used for |
| --- | --- | --- |
| `LICENSE.txt` | `art/ninja_adventure/LICENSE.txt` | The pack's CC0 1.0 licence |
| `Backgrounds/Tilesets/TilesetFloor.png` | `art/ninja_adventure/Backgrounds/Tilesets/TilesetFloor.png` | Courtyard sand, grass, pebbles and cracks |
| `Backgrounds/Tilesets/TilesetFloorDetail.png` | `art/ninja_adventure/Backgrounds/Tilesets/TilesetFloorDetail.png` | Grass tufts and small flowers |
| `Backgrounds/Tilesets/Interior/TilesetInteriorFloor.png` | `art/ninja_adventure/Backgrounds/Tilesets/Interior/TilesetInteriorFloor.png` | The floors of the four rooms |
| `Backgrounds/Tilesets/TilesetElement.png` | `art/ninja_adventure/Backgrounds/Tilesets/TilesetElement.png` | Bookshelves, a dresser, drawers, potted plants |
| `Backgrounds/Tilesets/TilesetNature.png` | `art/ninja_adventure/Backgrounds/Tilesets/TilesetNature.png` | Bushes, a sunflower, a red flower |
| `Audio/Sounds/Voice/Voice1.wav` | `art/ninja_adventure/Audio/Sounds/Voice/Voice1.wav` | M. Jlassi's voice |
| `Audio/Sounds/Voice/Voice2.wav` | `art/ninja_adventure/Audio/Sounds/Voice/Voice2.wav` | Mme Kchaou's voice |
| `Audio/Sounds/Voice/Voice3.wav` | `art/ninja_adventure/Audio/Sounds/Voice/Voice3.wav` | Mme Salma's voice |
| `Audio/Sounds/Voice/Voice4.wav` | `art/ninja_adventure/Audio/Sounds/Voice/Voice4.wav` | Si Hédi's voice |
| `Audio/Sounds/Voice/Voice5.wav` | `art/ninja_adventure/Audio/Sounds/Voice/Voice5.wav` | Aziz's voice |
| `Audio/Sounds/Voice/Voice6.wav` | `art/ninja_adventure/Audio/Sounds/Voice/Voice6.wav` | Agent Fethi's voice |
| `Audio/Sounds/Voice/Voice7.wav` | `art/ninja_adventure/Audio/Sounds/Voice/Voice7.wav` | Nour's voice |
| `Audio/Sounds/Voice/Voice8.wav` | `art/ninja_adventure/Audio/Sounds/Voice/Voice8.wav` | Am Lassaad's voice |

## Drawn for this project

Drawn in code by the generators in `tools/`, in the pack's palette (see `ui/palette.gd`), and licensed with this project. Run a generator again to redraw its files.

| Path in the repo | Generator | What it is |
| --- | --- | --- |
| `art/tiles/centre.png` | `tools/build_map.py` | The map's tile atlas: the drawn walls, doors, windows, gate, guard post, trees, flag, furniture, notice boards, blackboard, clock, rugs and paving, with the pack tiles listed above placed beside them |
| `art/ui/title.png` | `tools/build_map.py` | The title screen's picture of the lycée |
| `art/characters/player.png` | `tools/draw_characters.py` | The player's walk frames |
| `art/characters/jlassi.png` | `tools/draw_characters.py` | M. Jlassi's frames |
| `art/characters/kchaou.png` | `tools/draw_characters.py` | Mme Kchaou's frames |
| `art/characters/salma.png` | `tools/draw_characters.py` | Mme Salma's frames |
| `art/characters/hedi.png` | `tools/draw_characters.py` | Si Hédi's frames |
| `art/characters/aziz.png` | `tools/draw_characters.py` | Aziz's frames |
| `art/characters/fethi.png` | `tools/draw_characters.py` | Agent Fethi's frames |
| `art/characters/nour.png` | `tools/draw_characters.py` | Nour's frames |
| `art/characters/lassaad.png` | `tools/draw_characters.py` | Am Lassaad's frames |
| `art/portraits/jlassi.png` | `tools/draw_characters.py` | M. Jlassi's portraits |
| `art/portraits/kchaou.png` | `tools/draw_characters.py` | Mme Kchaou's portraits |
| `art/portraits/salma.png` | `tools/draw_characters.py` | Mme Salma's portraits |
| `art/portraits/hedi.png` | `tools/draw_characters.py` | Si Hédi's portraits |
| `art/portraits/aziz.png` | `tools/draw_characters.py` | Aziz's portraits |
| `art/portraits/fethi.png` | `tools/draw_characters.py` | Agent Fethi's portraits |
| `art/portraits/nour.png` | `tools/draw_characters.py` | Nour's portraits |
| `art/portraits/lassaad.png` | `tools/draw_characters.py` | Am Lassaad's portraits |
| `art/ui/frame.png` | `tools/draw_ui.py` | The nine-slice panel frame |
| `art/ui/icons.png` | `tools/draw_ui.py` | The dashboard's meter icons |
