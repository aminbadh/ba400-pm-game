# BA 400 PM Game

A 2D top-down pixel story game for the BA 400 Project Management chapter 5 presentation at TBS. Built in Godot 4 with GDScript, exported for the web.

The player is a project manager who walks around an office and talks to people. Each conversation ends in a choice labelled **A**, **B** or **C**; the choice changes the player's XP and money, shown top-left.

## Layout

| Path | What it holds |
| --- | --- |
| `project.godot` | Display (320x180, integer scaling, nearest filtering), input map, autoloads |
| `autoload/game_state.gd` | `GameState`: `xp`, `money` and a `changed` signal |
| `actors/player/` | The player: four-direction movement, collision, and a probe for the NPC in front |
| `actors/npc/` | An NPC: set its dialogue file and start cue in the inspector |
| `world/office.tscn` | The main scene: one room on a `TileMapLayer`, the actors, a following camera, the HUD |
| `world/office_tiles.tres` | The room's tile set (floor, and wall with collision) |
| `ui/hud/` | XP and money, top-left |
| `ui/balloon/` | The dialogue balloon, which adds the A/B/C labels to the choices |
| `dialogue/` | Story text, as Dialogue Manager `.dialogue` files |
| `art/placeholder/` | Flat-coloured 16x16 stand-ins for the player, NPC, floor and wall |
| `addons/dialogue_manager/` | [Dialogue Manager](https://github.com/nathanhoad/godot_dialogue_manager) v4.1.0, vendored |
| `tests/smoke_test.gd` | Walks one branch of `dialogue/test.dialogue` and checks the score |
| `export_presets.cfg` | The `Web` export preset (single-threaded) |

## Controls

| Action | Keys |
| --- | --- |
| Move | WASD or arrow keys |
| Talk, advance, pick the highlighted choice | E, Space or Enter |
| Pick choice A, B or C directly | 1, 2, 3 (or click it) |

## Writing dialogue

Story lives in `.dialogue` files under `dialogue/`, in Dialogue Manager's syntax. A conversation starts at a cue (`~ start`); choices are lines starting with `- `; `do GameState.xp += 10` changes the score. Do not type the A/B/C letters: the balloon adds them. See `dialogue/test.dialogue` for a complete example.

To give a new character a conversation, place `actors/npc/npc.tscn` in a map and set **Dialogue Resource** and **Start Cue** in the inspector.

## Open in the editor

Use Godot 4.7 (the standard build, not .NET). Open the Project Manager, choose **Import**, and pick this folder's `project.godot`. Press F5 to run.

## Checks

Run from the project root. `godot` stands for the Godot binary (on macOS, `/Applications/Godot.app/Contents/MacOS/Godot`).

```sh
godot --headless --path . --import                   # import assets; must print no errors
godot --headless --path . --quit-after 300           # run the main scene briefly
godot --headless --path . -s tests/smoke_test.gd     # dialogue smoke test; exits 1 on failure, 2 on timeout
```

## Web build

The `Web` export preset is single-threaded, so the build runs from any static file server with no special headers. It needs the Godot 4.7.2 export templates (Editor > Manage Export Templates).

```sh
mkdir -p build/web && touch build/.gdignore      # keep Godot from importing the build
godot --headless --path . --export-release Web build/web/index.html
uv run python -m http.server -d build/web 8000
```

Then open <http://localhost:8000>. `build/` is not committed.
