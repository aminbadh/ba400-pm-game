# BA 400 PM Game

A 2D top-down pixel story game for the BA 400 Project Management chapter 5 presentation at TBS. Built in Godot 4 with GDScript, exported for the web.

The player runs exam centre 26 for the Tunisian baccalauréat 2026 as its project manager. Each scene teaches one part of the chapter on a concept card, then the room votes on a choice with its **A**, **B** and **C** cards and the presenter presses the room's answer. Votes move four meters on the project dashboard (Integrity, Fairness, Team, Budget) and set flags that pay off on exam day; the meters decide one of three endings, followed by what really happened in June 2026 and a debrief of every vote.

## Layout

| Path | What it holds |
| --- | --- |
| `project.godot` | Display (320x180, integer scaling, nearest filtering), input map, autoloads |
| `autoload/game_state.gd` | `GameState`: the four meters, the story flags, the room's votes, the cards collected, the current scene, Short mode |
| `autoload/story.gd` | `Story`: sets the pixel font, loads the content files, starts each scene, and gives the dialogue its calls (`show_card`, `show_exhibit`, `run_inspection`, `backdrop`, the binder) |
| `dialogue/` | The story, one Dialogue Manager `.dialogue` file per scene (`s00_charter` to `s10_ending`) |
| `content/cards.json` | The nine concept cards and each vote's debrief lines |
| `content/exhibits.json` | The charter, the organisational chart, the RACI chart and the resource histogram |
| `content/inspection.json` | Scene 4's gate checklist and its five rehearsal candidates |
| `content/scenes.json` | The scene order, who starts each scene and where, the characters' names and colours, the place names |
| `ui/palette.gd` | Every colour: the pack's palette, the lycée's cream walls and blue doors, the UI colours and every text and background pair |
| `ui/ui_style.gd` | The pixel frame, the dark name plates and labels every screen shares, and the spacing rule: `INSET` (6 px) inside every frame, `GAP` (4) between separate items, `TIGHT` (2) between the lines of a list, `EDGE` (4) from a panel to the screen's edge, `PLATE_X` and `PLATE_Y` (3, 1) inside the small plates |
| `ui/title/` | The title screen: Full or Short |
| `ui/balloon/` | The dialogue box: portrait, name plate, typed pages of three lines, optional voices; the votes as A/B/C cards with the 20-second bar, "The room chose B" |
| `ui/stage/` | Full-screen moments: cards, charts, the gate inspection, the ending backdrop |
| `ui/card_view/` | A card or the charter drawn as a lecture slide |
| `ui/dashboard/` | The four meters, top-left, each with an icon, label, bar and number; who to talk to next, at the bottom |
| `ui/binder/` | The planning binder: quest log, card viewer, debrief |
| `ui/pause_menu/` | Resume, Binder, Voices on or off, Skip to next scene, Restart to title |
| `world/centre.tscn` | The map: gate, courtyard, admin office, Room 12, staff room, deposit room; the characters; the scene spots. Its tile layers are filled by `tools/build_map.py` |
| `actors/player/` | The player: four-direction movement and walk frames, collision, and a probe for the character in front |
| `actors/npc/` | A character: set **Character** to an id from `content/scenes.json`; it faces down, and turns to the player who talks to it |
| `art/tiles/`, `art/characters/`, `art/portraits/`, `art/ui/` | The drawn art: the map's tile atlas, the sprites, the portraits (neutral, worried, pleased), the frame, icons and title picture |
| `art/ninja_adventure/` | The files used from the Ninja Adventure pack, at their path in the pack |
| `art/LICENSES.md` | Where every image and sound under `art/` comes from |
| `tools/` | The art generators (Python, run with `uv`), the screenshot capture and its washed-out filter, the licence check |
| `fonts/` | Ark Pixel 10 px and its licence |
| `addons/dialogue_manager/` | [Dialogue Manager](https://github.com/nathanhoad/godot_dialogue_manager) v4.1.0, vendored |
| `tests/` | `story_test.gd` plays the story to each ending and with scene 8 skipped; `flow_test.gd` drives restart and skip; `route_test.gd` walks the player to each scene's character; `content_test.gd` checks the content files; `contrast_test.gd` checks every text colour reaches 7:1; `spacing_test.gd` checks every margin, separation and offset under `ui/` comes from `UiStyle`'s constants |
| `export_presets.cfg` | The `Web` export preset (single-threaded) |

## Controls

| Action | Keys |
| --- | --- |
| Move | WASD or arrow keys |
| Talk, show the whole line while it types, advance, turn a card's page | E, Space or Enter |
| Vote A, B or C | 1, 2, 3 (or click the option) |
| Gate inspection: admit or stop | 1 admit, 2 stop |
| Open or close the binder | B |
| Pause menu | Escape |
| Choose in the binder and menus | Up and Down, then E |

Votes are never picked for the presenter: the bar fills over 20 seconds and turns red, and waits. Cards and charts stay until the presenter presses E. The characters' voices are off by default; **Voices** in the pause menu switches them on (they need the laptop's sound).

## Running a session

On the title screen, press **1** for **Full** (about 30 minutes) or **2** for **Short** (about 20). Short mode drops the optional votes in scenes 0, 2 and 5 (their cards still show), replaces scene 4's gate inspection with its check vote, keeps only the exam-day beats that a flag sets, and trims the ending to the ending line, three real figures and the debrief.

Walk to the character with the marker over them and press E; the line at the bottom of the screen says who and where. Only that character answers. After scene 9 the ending starts on its own.

Escape opens the pause menu. **Skip to next scene** abandons the current scene with no effect on the meters, and its vote shows as "Not voted" in the debrief. During the ending it goes straight to the debrief, then the last screen. **Restart to title** starts over.

## Changing the story

Story text lives in the `.dialogue` files under `dialogue/`, in Dialogue Manager's syntax, one file per scene. Each starts at `~ start`. A line is `Name: text`, or plain text for narration; options are lines starting with `- `, and the balloon adds the A/B/C letters, so do not type them. Write `\:` for a colon followed by a space in narration or an option, or the text before it becomes a speaker's name.

| In a dialogue file | What it does |
| --- | --- |
| `do GameState.integrity += 10` | Change a meter: `integrity`, `fairness`, `team` (0 to 100) or `budget` (TND, 0 to 3,000) |
| `do GameState.set_flag("raci_clear")` | Set a flag; `if GameState.has_flag("raci_clear")` tests it |
| `if GameState.short_mode` | Branch on Short mode |
| `do GameState.record_vote(6, "A")` | Record the room's vote in a scene, for the debrief |
| `do Story.show_card(7)` | Show a card full screen until the presenter presses E, and add it to the binder |
| `do Story.show_exhibit("raci")` | Show the charter or a chart from `content/exhibits.json` |
| `Si Hédi: [#worried] We'll see on the day.` | Show the speaker's worried portrait for this line; `[#pleased]` for pleased. A line with no tag is neutral |

A line longer than three lines in the box pages inside it on its own: there is no need to split it.

Card text lives in `content/cards.json`. Each card has a number, title, slide range, one or more `pages` of body text, and its vote's `debrief` line for A, B and C. Card 5 also has `debrief_inspection`, the line for Full mode's gate inspection, where `{right}` and `{total}` become the count of right calls. Mark a key term as `**term**` to draw it in the accent colour; `\n` starts a new paragraph. If a page is too long, `tests/content_test.gd` fails and names it: split its text into two pages rather than shortening a definition.

## Art

The art is drawn in code and the PNGs are committed; run a generator again after changing it. Each is a standalone script run with [uv](https://docs.astral.sh/uv/), from the project root. Colours come from `ui/palette.gd`.

```sh
uv run tools/build_map.py         # draw the tiles, write art/tiles/centre.png, world/centre_tiles.tres and the map's layers, check the map
uv run tools/build_map.py --check # only check the map, writing nothing
uv run tools/draw_characters.py   # draw the sprites and portraits
uv run tools/draw_ui.py           # draw the frame and the meter icons
uv run tools/check_licenses.py    # check art/LICENSES.md lists every file under art/
```

The map's layout (rooms, beds, props, wall decorations) is the lists at the top of `tools/build_map.py`; edit them there rather than painting tiles in the editor, which the next run would overwrite. The map check uses the player's collision box from `actors/player/` and every place a character can stand: each character can be reached and talked to, nowhere leaves the player stuck, a walkway two tiles wide joins the start to both sides of every door, and nothing stands within a tile of a doorway.

**Projector check.** `tools/capture_screens.gd` plays through every kind of screen and saves each at 1920x1080 to `build/screens/`; `tools/washout.py` adds a washed-out copy of each (blacks lifted to 25%, contrast and saturation down 30%), as a worn projector shows them. The capture needs a window:

```sh
godot --path . -s tools/capture_screens.gd --resolution 1920x1080
uv run tools/washout.py
```

## Open in the editor

Use Godot 4.7 (the standard build, not .NET). Open the Project Manager, choose **Import**, and pick this folder's `project.godot`. Press F5 to run.

## Checks

Run from the project root. `godot` stands for the Godot binary (on macOS, `/Applications/Godot.app/Contents/MacOS/Godot`).

```sh
godot --headless --path . --import                   # import assets; must print no errors
godot --headless --path . --quit-after 300           # run the title screen briefly
godot --headless --path . -s tests/story_test.gd     # play the story to each ending; exits 1 on failure, 2 on timeout
godot --headless --path . -s tests/flow_test.gd      # restart, new game and skip, and skipping the ending; exits 1 on failure
godot --headless --path . --fixed-fps 60 -s tests/route_test.gd  # walk to each scene's character with the movement keys; exits 1 if the player stops short
godot --headless --path . -s tests/content_test.gd   # cards, debrief lines, flags, page and title fit; exits 1 on failure
godot --headless --path . -s tests/contrast_test.gd  # every text colour pair at 7:1 or more; exits 1 on failure
godot --headless --path . -s tests/spacing_test.gd   # no number literal for a margin, separation or offset under ui/; exits 1 on failure
```

## Web build

The `Web` export preset is single-threaded, so the build runs from any static file server with no special headers. It needs the Godot 4.7.2 export templates (Editor > Manage Export Templates).

```sh
mkdir -p build/web && touch build/.gdignore      # keep Godot from importing the build
godot --headless --path . --export-release Web build/web/index.html
uv run python -m http.server -d build/web 8000
```

Then open <http://localhost:8000>. `build/` is not committed.

## Credits

- [Ark Pixel Font](https://github.com/TakWolf/ark-pixel-font) by TakWolf, 10 px proportional, Latin build: SIL Open Font License 1.1 ([`fonts/OFL.txt`](fonts/OFL.txt)).
- [Dialogue Manager](https://github.com/nathanhoad/godot_dialogue_manager) by Nathan Hoad: MIT licence ([`addons/dialogue_manager/LICENSE`](addons/dialogue_manager/LICENSE)).
- [Ninja Adventure Asset Pack](https://pixel-boy.itch.io/ninja-adventure-asset-pack) by Pixel-boy and AAA: floors, plants, some furniture and the voices. Creative Commons Zero v1.0 Universal ([`art/ninja_adventure/LICENSE.txt`](art/ninja_adventure/LICENSE.txt)); the files used are listed in [`art/LICENSES.md`](art/LICENSES.md).
- The lycée's walls, doors, furniture, trees, the characters, portraits and UI were drawn for this project, in the pack's palette.
- Every person in the story is fictional. The 2026 figures in the ending are as reported by the press.
