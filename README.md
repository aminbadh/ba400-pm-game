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
| `ui/title/` | The title screen: Full or Short |
| `ui/balloon/` | The dialogue balloon: A/B/C labels, the 20-second vote bar, "The room chose B" |
| `ui/stage/` | Full-screen moments: cards, charts, the gate inspection, the ending backdrop |
| `ui/card_view/` | A card or the charter drawn as a lecture slide |
| `ui/dashboard/` | The four meters, top-left, and who to talk to next, top-right |
| `ui/binder/` | The planning binder: quest log, card viewer, debrief |
| `ui/pause_menu/` | Resume, Binder, Skip to next scene, Restart to title |
| `world/centre.tscn` | The map: gate, courtyard, admin office, Room 12, staff room, deposit room; the characters; the scene spots |
| `actors/player/` | The player: four-direction movement, collision, and a probe for the character in front |
| `actors/npc/` | A character: set **Character** to an id from `content/scenes.json` |
| `art/placeholder/` | Flat-coloured stand-ins: the tile atlas, the player, one sprite per character |
| `fonts/` | Ark Pixel 10 px and its licence |
| `addons/dialogue_manager/` | [Dialogue Manager](https://github.com/nathanhoad/godot_dialogue_manager) v4.1.0, vendored |
| `tests/` | `story_test.gd` plays the story three times; `content_test.gd` checks the content files |
| `export_presets.cfg` | The `Web` export preset (single-threaded) |

## Controls

| Action | Keys |
| --- | --- |
| Move | WASD or arrow keys |
| Talk, advance a line, turn a card's page | E, Space or Enter |
| Vote A, B or C | 1, 2, 3 (or click the option) |
| Gate inspection: admit or stop | 1 admit, 2 stop |
| Open or close the binder | B |
| Pause menu | Escape |
| Choose in the binder and menus | Up and Down, then E |

Votes are never picked for the presenter: the bar fills over 20 seconds and turns red, and waits. Cards and charts stay until the presenter presses E.

## Running a session

On the title screen, press **1** for **Full** (about 30 minutes) or **2** for **Short** (about 20). Short mode drops the optional votes in scenes 0, 2 and 5 (their cards still show), replaces scene 4's gate inspection with its check vote, keeps only the exam-day beats that a flag sets, and trims the ending to the ending line, three real figures and the debrief.

Walk to the character with the marker over them and press E; the top-right line says who and where. Only that character answers. After scene 9 the ending starts on its own.

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

Card text lives in `content/cards.json`. Each card has a number, title, slide range, one or more `pages` of body text, and its vote's `debrief` line for A, B and C. Mark a key term as `**term**` to draw it in the accent colour; `\n` starts a new paragraph. If a page is too long, `tests/content_test.gd` fails and names it: split its text into two pages rather than shortening a definition.

## Open in the editor

Use Godot 4.7 (the standard build, not .NET). Open the Project Manager, choose **Import**, and pick this folder's `project.godot`. Press F5 to run.

## Checks

Run from the project root. `godot` stands for the Godot binary (on macOS, `/Applications/Godot.app/Contents/MacOS/Godot`).

```sh
godot --headless --path . --import                   # import assets; must print no errors
godot --headless --path . --quit-after 300           # run the title screen briefly
godot --headless --path . -s tests/story_test.gd     # play the story to each ending; exits 1 on failure, 2 on timeout
godot --headless --path . -s tests/flow_test.gd      # restart, new game and skip, and skipping the ending; exits 1 on failure
godot --headless --path . -s tests/content_test.gd   # cards, debrief lines, flags, page and title fit; exits 1 on failure
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
- Placeholder art was drawn for this project.
- Every person in the story is fictional. The 2026 figures in the ending are as reported by the press.
