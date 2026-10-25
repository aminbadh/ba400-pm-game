# BA 400 PM Game

**Play it:** <https://aminbadh.github.io/ba400-pm-game/>

A 2D top-down pixel story game for the BA 400 Project Management chapter 5 presentation at TBS. Built in Godot 4 with GDScript, exported for Windows (for the presentation) and the web.

The player runs exam centre 26 for the Tunisian baccalauréat 2026 as its project manager. Each scene teaches one part of the chapter on a concept card, then the room votes on a choice with its **A**, **B** and **C** cards and the presenter presses the room's answer. Votes move four meters on the project dashboard (Integrity, Fairness, Team, Budget) and set flags that pay off on exam day. The story ends on the region's report, which checks the charter's success criteria against the room's choices, then one of three endings set by the meters, a debrief of every vote, and the cast's thank-you.

## Layout

| Path | What it holds |
| --- | --- |
| `project.godot` | Display (320x180, integer scaling, nearest filtering), input map, autoloads |
| `autoload/game_state.gd` | `GameState`: the four meters, the story flags, the room's votes, the cards collected, the current scene |
| `autoload/music.gd` | `Music`: the background music, one constant per track, crossfaded, quiet under speech on its own bus, faded out while a card shows; mutes music and voices for the Sound switch |
| `autoload/hints.gd` | `Hints`: whether the last input came from the keyboard or a controller, and the on-screen hints for it |
| `autoload/stick.gd` | `Stick`: turns each push of the left stick into one D-pad press for menus, the binder, the votes and the gate, repeating while held |
| `autoload/screen.gd` | `Screen`: full screen on or off, on F11, Alt+Enter or the pause menu's item |
| `autoload/story.gd` | `Story`: sets the pixel font, loads the content files, starts each scene and its music, and gives the dialogue its calls (`show_card`, `show_exhibit`, `open_overview`, `flash_dashboard`, `run_inspection`, `show_report`, `backdrop`, `open_debrief`, `show_last_screen`); builds the debrief's lines and the region's report |
| `dialogue/` | The story, one Dialogue Manager `.dialogue` file per scene (`s00_charter` to `s10_ending`) |
| `content/cards.json` | The nine concept cards, each vote's debrief line per option and its best choice |
| `content/report.json` | The region's report: the charter's success criteria, the line when each is met and the reason, by flag, when it is not |
| `content/exhibits.json` | The charter, the organisational chart, the RACI chart and the resource histogram |
| `content/inspection.json` | Scene 4's gate checklist, its five rehearsal candidates, and what a right or wrong call scores for each kind: Fairness for a candidate who should be admitted, Integrity for one who should be stopped |
| `content/scenes.json` | The scene order, who starts each scene and where, the characters' names and colours, the last screen's line-up, the place names |
| `ui/palette.gd` | Every colour: the pack's palette, the lycée's cream walls and blue doors, the UI colours and every text and background pair |
| `ui/ui_style.gd` | The pixel frame, the dark name plates and labels every screen shares, and the spacing rule: `INSET` (6 px) inside every frame, `GAP` (4) between separate items, `TIGHT` (2) between the lines of a list, `EDGE` (4) from a panel to the screen's edge, `PLATE_X` and `PLATE_Y` (3, 1) inside the small plates |
| `ui/glyphs.gd` | The icons the pixel font lacks (a tick, a cross, the controller's cross and Start buttons), as a fallback font, so any text can show them |
| `ui/title/` | The title screen: one prompt to start |
| `ui/balloon/` | The dialogue box: portrait, name plate, typed pages of three lines, voices; the votes as A/B/C cards with the 20-second bar, "The room chose B" |
| `ui/stage/` | Full-screen moments: cards, charts, the gate inspection, the region's report, the ending backdrop, and the last screen (`last_screen.gd`) |
| `ui/card_view/` | A card, the charter or the region's report drawn as a lecture slide |
| `ui/dashboard/` | The four meters in a strip along the top, each cell with an icon, name, number and a bar under it, live from the first scene; who to talk to next, in a strip at the bottom. The map's camera keeps both strips clear of the map |
| `ui/binder/` | The planning binder: quest log, card viewer, scene 0's read-only overview, debrief |
| `ui/pause_menu/` | Resume, Binder, Sound on or off, Full screen on or off, Controller check, Skip to next scene, Restart to title; its hint covers the dashboard's strip at the bottom |
| `world/centre.tscn` | The map: gate, courtyard, admin office, Room 12, staff room, deposit room; the characters; the scene spots. Its tile layers are filled by `tools/build_map.py` |
| `actors/player/` | The player: four-direction movement and walk frames, collision, and a probe for the character in front |
| `actors/npc/` | A character: set **Character** to an id from `content/scenes.json`; it faces down, and turns to the player who talks to it |
| `art/tiles/`, `art/characters/`, `art/portraits/`, `art/ui/` | The drawn art: the map's tile atlas, the sprites, the portraits (neutral, worried, pleased), the frame, icons and title picture |
| `art/ninja_adventure/` | The files used from the Ninja Adventure pack, at their path in the pack: tiles, voices and three music tracks |
| `art/LICENSES.md` | Where every image and sound under `art/` comes from |
| `tools/` | The art generators (Python, run with `uv`), the screenshot capture and its washed-out filter, the licence check |
| `fonts/` | Ark Pixel 10 px and its licence |
| `addons/dialogue_manager/` | [Dialogue Manager](https://github.com/nathanhoad/godot_dialogue_manager) v4.1.0, vendored |
| `tests/` | `story_test.gd` plays the story to each ending, into the news through each meter alone, to a smooth session after a wrong answer in scene 1, and with scene 8 skipped; `flow_test.gd` drives restart, skip and the ending; `route_test.gd` walks the player to each scene's character; `content_test.gd` checks the content files, and compares the votes and debrief with the story script when it can read it; `contrast_test.gd` checks every text colour reaches 7:1; `spacing_test.gd` checks every margin, separation and offset under `ui/` comes from `UiStyle`'s constants; `sound_test.gd` checks the music and the Sound switch; `controls_test.gd` checks every action has a key and a controller button, that the hints follow the device, and the full screen keys; `layout_test.gd` checks the pause menu fits between the strip and its hint, and the organisational chart's boxes and lines |
| `export_presets.cfg` | The `Windows` preset (64-bit, one executable with the game inside) and the `Web` preset (single-threaded) |

## Controls

The keyboard and a PlayStation-style controller work side by side, with no setting to change. The hints on screen show the keys or the controller's buttons, whichever was used last.

| Action | Keys | Controller |
| --- | --- | --- |
| Move | WASD or arrow keys | Left stick or D-pad |
| Talk, show the whole line while it types, advance, turn a card's page, confirm | E, Space or Enter | ✕ |
| Vote | 1, 2, 3, or Up/Down then E (or click the option) | Up/Down to point at an option, then ✕ |
| Gate inspection: admit or stop | 1 admit, 2 stop, or Left/Right then E | D-pad left for Admit, right for Stop, then ✕ |
| Open or close the binder | B | △ to open, ○ to close |
| Pause menu | Escape | Start; ○ backs out |
| Full screen on or off | F11 or Alt+Enter, anywhere | The pause menu's Full screen item |
| Choose in the binder and menus | Up and Down, then E | D-pad, then ✕ |

In menus, the binder, the votes and the gate, one push of the left stick moves one step, like the D-pad; held, it repeats after 0.4 s and then every 0.15 s. A controller never picks a vote with one button per letter: the presenter points at the room's option and confirms it. Votes are never picked for the presenter: the bar fills over 20 seconds and turns red, and waits. Cards and charts stay until the presenter presses E or ✕.

**Controller check**, in the pause menu, shows the name Godot reports for each connected controller and, live, the last button or direction pressed. Run it on the PC the game is played on. If the buttons come out wrong, Steam's "Add a non-Steam game" with Steam Input presents the pad as an Xbox controller; a genuine DualShock 3 on Windows needs the DsHidMini driver either way.

**Full screen**, in the pause menu, or F11 or Alt+Enter at any time, switches the game between full screen and a window. The Windows build always starts full screen; the setting is not saved between runs. On the web it asks the browser for its own full screen, which Escape also leaves.

**Sound**, in the pause menu, switches the music and the characters' voices together; it is on by default. The music plays quietly under speech: a calm loop on the map, a tenser one on exam day, the end theme from the ending on. It fades out while a concept card or the charter is on screen and comes back when it closes; it keeps playing during votes. Each track is one constant at the top of `autoload/music.gd`.

## Running a session

On the title screen, press **E** or **✕**. The story takes about 30 minutes.

Walk to the character with the marker over them and press E; the line at the bottom of the screen says who and where. Only that character answers. The dashboard strip along the top shows all four meters with their real values from the first scene, so every vote shows its effect at once; scene 3 flashes it and explains it on card 4. If the room picks the pass rate there, the strip shows every meter green and full until the ending. In scene 0, after the first card, the binder opens as a read-only overview of the nine cards. After scene 9 the ending starts on its own: M. Jlassi's call, the region's report on the charter's success criteria, the ending, the debrief and the last screen.

The debrief shows each card with the room's choice ("You chose B: ..."), the line for that choice and the best choice ("Best: ..."). Card 5 shows how many gate calls were right instead.

Escape (or Start) opens the pause menu. **Skip to next scene** abandons the current scene with no effect on the meters, and its vote shows as "Not voted" in the debrief, still with its best choice. During the ending (M. Jlassi's call, the report or the ending card) it goes straight to the debrief; closing the debrief shows the last screen. **Restart to title** starts over.

## Changing the story

Story text lives in the `.dialogue` files under `dialogue/`, in Dialogue Manager's syntax, one file per scene. Each starts at `~ start`. A line is `Name: text`, or plain text for narration; options are lines starting with `- `, and the balloon adds the A/B/C letters, so do not type them. Write `\:` for a colon followed by a space in narration or an option, or the text before it becomes a speaker's name.

| In a dialogue file | What it does |
| --- | --- |
| `do GameState.integrity += 10` | Change a meter: `integrity`, `fairness`, `team` (0 to 100) or `budget` (TND, 0 to 2,000) |
| `do GameState.set_flag("raci_clear")` | Set a flag; `if GameState.has_flag("raci_clear")` tests it |
| `do GameState.record_vote(6, "A")` | Record the room's vote in a scene, for the debrief |
| `do Story.show_card(7)` | Show a card full screen until the presenter presses E, and add it to the binder |
| `do Story.show_exhibit("raci")` | Show the charter or a chart from `content/exhibits.json` |
| `Si Hédi: [#worried] We'll see on the day.` | Show the speaker's worried portrait for this line; `[#pleased]` for pleased. A line with no tag is neutral |

A line longer than three lines in the box pages inside it on its own: there is no need to split it.

Card text lives in `content/cards.json`. Each card has a number, title, slide range, one or more `pages` of body text, its vote's `debrief` line for A, B and C, and its `best` choice. Card 5 has no vote: its `debrief_inspection` is the gate inspection's line, where `{right}` and `{total}` become the count of right calls. The debrief's "You chose B:" line takes the option's text from the dialogue file, so an option is only ever written once. The region's report lives in `content/report.json`. Mark a key term as `**term**` to draw it in the accent colour; `\n` starts a new paragraph. If a page is too long, `tests/content_test.gd` fails and names it: split its text into two pages rather than shortening a definition.

## Art

The art is drawn in code and the PNGs are committed; run a generator again after changing it. Each is a standalone script run with [uv](https://docs.astral.sh/uv/), from the project root. Colours come from `ui/palette.gd`.

```sh
uv run tools/build_map.py         # draw the tiles, write art/tiles/centre.png, world/centre_tiles.tres and the map's layers, check the map
uv run tools/build_map.py --check # only check the map, writing nothing
uv run tools/draw_characters.py   # draw the sprites, the last screen's waves (24x16 frames) and the portraits
uv run tools/draw_ui.py           # draw the frame, the meter icons and the glyphs the font lacks
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
godot --headless --path . -s tests/story_test.gd     # play the story to each ending, and into the news through each meter; exits 1 on failure, 2 on timeout
godot --headless --path . -s tests/flow_test.gd      # restart, new game and skip, the report and skipping the ending; exits 1 on failure
godot --headless --path . --fixed-fps 60 -s tests/route_test.gd  # walk to each scene's character with the movement keys; exits 1 if the player stops short
godot --headless --path . -s tests/content_test.gd   # cards, debrief and best lines against the story script, flags, page and title fit, the strip's live values from scene 0, the report's pages, the last screen and its wave frames' clear edges, Am Lassaad's lines; exits 1 on failure
godot --headless --path . -s tests/contrast_test.gd  # every text colour pair at 7:1 or more; exits 1 on failure
godot --headless --path . -s tests/spacing_test.gd   # no number literal for a margin, separation or offset under ui/; exits 1 on failure
godot --headless --path . -s tests/sound_test.gd     # the Sound switch, each scene's track, the fade during a card; exits 1 on failure
godot --headless --path . -s tests/controls_test.gd  # a key and a controller button for every action, hints that follow the device, full screen's keys; exits 1 on failure
godot --headless --path . -s tests/layout_test.gd    # the pause menu and the controller check fit the screen, the org chart is a clean tree; exits 1 on failure
```

Godot exits 0 when a test script fails to compile, so read the output for `SCRIPT ERROR` too; `tools/web_build.sh` does.

Set `STORY_MD` to the story script's path to compare the content with it: `content_test.gd` then checks every vote's options, debrief lines and best line word for word. Without it, the test prints `SKIP` for that comparison and checks the rest.

## Windows build

The presentation runs from a Windows PC. The `Windows` preset makes one 64-bit executable with the game inside it, so it can be copied to the PC and run from anywhere. It needs the Godot 4.7.2 export templates.

```sh
mkdir -p build/windows && touch build/.gdignore
godot --headless --path . --export-release Windows build/windows/ba400-pm-game.exe
```

Copy `build/windows/ba400-pm-game.exe` to the PC. It starts full screen (`window/size/mode.windows` in `project.godot`); F11 or Alt+Enter gives a window. Windows may warn that the file is from an unknown publisher, since it is not signed: choose **More info**, then **Run anyway**.

## Web build

The `Web` export preset is single-threaded, so the build runs from any static file server with no special headers. It needs the Godot 4.7.2 export templates (Editor > Manage Export Templates).

```sh
mkdir -p build/web && touch build/.gdignore      # keep Godot from importing the build
godot --headless --path . --export-release Web build/web/index.html
uv run python -m http.server -d build/web 8000
```

Then open <http://localhost:8000>. `build/` is not committed.

`tools/web_build.sh <godot> <folder>` runs the import, every test and the export in one go, stopping at the first failure; it is what the deploy runs.

## Deploy

Every push to `main` runs `.github/workflows/pages.yml`: it downloads Godot 4.7.2 and its web templates from the official release (checked against the release's SHA-512 sums, then cached), runs `tools/web_build.sh`, and publishes `build/web` to GitHub Pages. A failing test stops the deploy, and a newer push cancels an older run. **Run workflow** on the Actions tab starts it by hand.

Once, before the first deploy: on GitHub, **Settings > Pages**, set **Source** to **GitHub Actions**.

## Credits

- [Ark Pixel Font](https://github.com/TakWolf/ark-pixel-font) by TakWolf, 10 px proportional, Latin build: SIL Open Font License 1.1 ([`fonts/OFL.txt`](fonts/OFL.txt)).
- [Dialogue Manager](https://github.com/nathanhoad/godot_dialogue_manager) by Nathan Hoad: MIT licence ([`addons/dialogue_manager/LICENSE`](addons/dialogue_manager/LICENSE)).
- [Ninja Adventure Asset Pack](https://pixel-boy.itch.io/ninja-adventure-asset-pack) by Pixel-boy and AAA: floors, plants, some furniture, the voices and the music. Creative Commons Zero v1.0 Universal ([`art/ninja_adventure/LICENSE.txt`](art/ninja_adventure/LICENSE.txt)); the files used are listed in [`art/LICENSES.md`](art/LICENSES.md).
- The lycée's walls, doors, furniture, trees, the characters, portraits and UI were drawn for this project, in the pack's palette.
- Every person in the story is fictional. The story draws on the real Bac 2026, but no real statistic appears in it.
