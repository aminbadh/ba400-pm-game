extends SceneTree
## Checks the content files against the dialogue: every card and exhibit the
## dialogue shows exists, every vote has its three debrief lines, every flag is
## one the story uses, every scene's dialogue starts at its cue, every card
## page fits on screen at the base resolution, every backdrop title fits
## inside the screen's margins and clear of the dashboard and the dialogue box,
## the map's camera keeps the strips at the top and the bottom clear, the strip
## shows the real values from scene 0, the gate inspection shows Am Lassaad
## saying one of his four lines, the region's report fits its pages at its
## longest, and the last screen stays inside the screen, clear of the strip,
## with nothing overlapping. Every vote's options, debrief lines and best line
## are compared with story.md's, when story.md can be read. Exits non-zero on failure.
##
##   Godot --headless --path . -s tests/content_test.gd


const DIALOGUE_DIR: String = "res://dialogue/"
## The flags story.md defines.
const FLAGS: Array[String] = [
	"room12_fixed", "metrics_people", "metrics_exam", "metrics_passrate",
	"raci_clear", "raci_double", "raci_none", "staff_borrowed", "rooms_crowded",
	"staff_thin", "staff_trained", "staff_protected", "bought_tech", "phone_admitted",
]
## The scenes whose votes story.md writes, each with options A, B and C.
const VOTE_SCENES: Array[int] = [0, 1, 2, 3, 5, 6, 7, 8]
## The environment variable that gives the story script's path. The script is
## not in the repo: with the variable unset or the file missing, the
## comparison is skipped and says so.
const STORY_MD_VARIABLE: String = "STORY_MD"
const ENDING_DIALOGUE: String = "res://dialogue/s10_ending.dialogue"
const OPTIONS: Array[String] = ["A", "B", "C"]
const TIMEOUT_SECONDS: float = 20.0
const BALLOON_SCRIPT: String = "res://ui/balloon/balloon.gd"
## How far a backdrop title keeps from the dashboard and the dialogue box, in pixels.
const TITLE_CLEARANCE: float = 4.0
const TILE_SIZE: int = 16
## Am Lassaad's lines at the gate, as story.md writes them; one is drawn each time.
const AM_LASSAAD_LINES: Array = [
	"Ti jibtlou el kaskrout bark!",
	"Ti khallini nodkhol, ena el coach mte3ou!",
	"Ena 3addit el bac 3am 89, khallini n3awnou!",
	"Ya weldi, ken tenja7, el moto mte3ek!",
]
## How many times the check brings Am Lassaad to the gate.
const AM_LASSAAD_DRAWS: int = 12

var _problems: PackedStringArray = []
var _story: Node


func _initialize() -> void:
	create_timer(TIMEOUT_SECONDS).timeout.connect(_on_timeout)
	_main.call_deferred()


func _main() -> void:
	# Autoloads are looked up at run time, since this script compiles before they exist.
	_story = root.get_node_or_null("Story")
	if _story == null:
		_problems.append("the Story autoload is missing")
	else:
		var sources: Dictionary = _read_dialogue()
		_check_calls(sources)
		_check_debriefs(sources)
		_check_story_md()
		_check_scenes()
		await _check_pages_fit()
		await _check_map(sources)
	if _problems.is_empty():
		print("PASS: content checks")
		quit(0)
		return
	for problem: String in _problems:
		printerr("FAIL: " + problem)
	quit(1)


# Every dialogue file's text, by path.
func _read_dialogue() -> Dictionary:
	var sources: Dictionary = {}
	for file: String in DirAccess.get_files_at(DIALOGUE_DIR):
		if file.ends_with(".dialogue"):
			sources[DIALOGUE_DIR + file] = FileAccess.get_file_as_string(DIALOGUE_DIR + file)
	if sources.is_empty():
		_problems.append("no dialogue files in " + DIALOGUE_DIR)
	return sources


func _check_calls(sources: Dictionary) -> void:
	var card_call: RegEx = RegEx.create_from_string("Story\\.show_card\\((\\d+)\\)")
	var exhibit_call: RegEx = RegEx.create_from_string("Story\\.show_exhibit\\(\"(\\w+)\"")
	var flag_call: RegEx = RegEx.create_from_string("GameState\\.(?:set_flag|has_flag)\\(\"(\\w+)\"\\)")
	var exhibits: Dictionary = _story.get(&"exhibits")
	var shown: Array[int] = []
	for path: String in sources:
		var text: String = sources[path]
		for found: RegExMatch in card_call.search_all(text):
			var number: int = int(found.get_string(1))
			shown.append(number)
			if (_story.call(&"card_by_number", number) as Dictionary).is_empty():
				_problems.append("%s shows card %d, which cards.json does not have" % [path.get_file(), number])
		for found: RegExMatch in exhibit_call.search_all(text):
			if not exhibits.has(found.get_string(1)):
				_problems.append("%s shows exhibit %s, which exhibits.json does not have" % [path.get_file(), found.get_string(1)])
		for found: RegExMatch in flag_call.search_all(text):
			if found.get_string(1) not in FLAGS:
				_problems.append("%s uses flag %s, which story.md does not define" % [path.get_file(), found.get_string(1)])
	for card: Dictionary in _story.get(&"cards"):
		if int(card.number) not in shown:
			_problems.append("card %d is never shown by the dialogue" % int(card.number))
	print("cards shown by the dialogue: %s" % [shown])


func _check_debriefs(sources: Dictionary) -> void:
	var vote_call: RegEx = RegEx.create_from_string("GameState\\.record_vote\\((\\d+), \"([ABC])\"\\)")
	var recorded: Dictionary = {}
	for path: String in sources:
		for found: RegExMatch in vote_call.search_all(sources[path]):
			var key: String = "%s%s" % [found.get_string(1), found.get_string(2)]
			recorded[key] = path.get_file()
	for scene: int in VOTE_SCENES:
		var card: Dictionary = _card_for_scene(scene)
		if card.is_empty():
			_problems.append("no card for scene %d's vote" % scene)
			continue
		for option: String in OPTIONS:
			var line: String = card.get("debrief", {}).get(option, "")
			if line.strip_edges().is_empty():
				_problems.append("card %d has no debrief line for option %s" % [int(card.number), option])
			if (_story.call(&"option_text", scene, option) as String).is_empty():
				_problems.append("scene %d's dialogue has no option %s" % [scene, option])
			if not recorded.has("%d%s" % [scene, option]):
				_problems.append("scene %d's dialogue never records option %s" % [scene, option])
		if (card.get("best", "") as String).is_empty():
			_problems.append("card %d has no best line" % int(card.number))
		print("scene %d vote: debrief lines for A, B and C on card %d" % [scene, int(card.number)])
	for key: String in recorded:
		var scene: int = int(key.left(-1))
		if scene not in VOTE_SCENES:
			_problems.append("%s records a vote in scene %d, which has none in story.md" % [recorded[key], scene])


# Every vote's three options in the dialogue, and each card's debrief lines and
# best line, word for word as story.md writes them.
func _check_story_md() -> void:
	var path: String = OS.get_environment(STORY_MD_VARIABLE)
	if path.is_empty() or not FileAccess.file_exists(path):
		print("SKIP: story.md comparison; set %s to the story script's path to run it" % STORY_MD_VARIABLE)
		return
	var text: String = FileAccess.get_file_as_string(path)
	var options: Dictionary = _story_md_options(text)
	var debriefs: Dictionary = _story_md_debriefs(text)
	var compared: int = 0
	for scene: int in VOTE_SCENES:
		var card: Dictionary = _card_for_scene(scene)
		for i: int in OPTIONS.size():
			var letter: String = OPTIONS[i]
			var written: String = options.get(scene, {}).get(letter, "")
			var shown: String = _story.call(&"option_text", scene, letter)
			if shown != written:
				_problems.append("scene %d option %s is \"%s\"; story.md writes \"%s\"" % [scene, letter, shown, written])
			var line: String = debriefs.get(scene, [])[i] if debriefs.has(scene) else ""
			if card.get("debrief", {}).get(letter, "") != line:
				_problems.append("card %d's debrief for %s is \"%s\"; story.md writes \"%s\"" % [int(card.number), letter, card.get("debrief", {}).get(letter, ""), line])
			compared += 2
		var best: String = debriefs.get(scene, ["", "", "", ""])[3]
		if card.get("best", "") != best:
			_problems.append("card %d's best line is \"%s\"; story.md writes \"%s\"" % [int(card.number), card.get("best", ""), best])
		compared += 1
	print("story.md: %d option, debrief and best texts compared" % compared)


# Each scene's vote options in story.md, by scene and letter, without the
# right answer's mark, the effects in backticks or the team's italic notes.
func _story_md_options(text: String) -> Dictionary:
	var heading: RegEx = RegEx.create_from_string("^## Scene (\\d+):")
	var option: RegEx = RegEx.create_from_string("^- ([ABC]): (.*)$")
	var extras: RegEx = RegEx.create_from_string("\\s*(`[^`]*`|\\*\\(.*?\\)\\*|✓)")
	var found: Dictionary = {}
	var scene: int = -1
	var in_vote: bool = false
	for line: String in text.split("\n"):
		var scene_match: RegExMatch = heading.search(line)
		if scene_match != null:
			scene = int(scene_match.get_string(1))
			in_vote = false
		elif line.begins_with("**Vote ("):
			in_vote = true
		elif in_vote:
			var option_match: RegExMatch = option.search(line)
			if option_match != null:
				if not found.has(scene):
					found[scene] = {}
				found[scene][option_match.get_string(1)] = extras.sub(option_match.get_string(2), "", true).strip_edges()
			elif not line.strip_edges().is_empty():
				in_vote = false
	return found


# The debrief table's rows in story.md, by scene: the lines for A, B and C, then the best.
func _story_md_debriefs(text: String) -> Dictionary:
	var found: Dictionary = {}
	var row: RegEx = RegEx.create_from_string("^\\| (\\d+) [^|]*\\|(.*)\\|\\s*$")
	for line: String in text.get_slice("## The debrief", 1).split("\n"):
		var row_match: RegExMatch = row.search(line)
		if row_match == null:
			continue
		var cells: Array[String] = []
		for cell: String in row_match.get_string(2).split("|"):
			cells.append(cell.strip_edges().trim_prefix("\"").trim_suffix("\""))
		found[int(row_match.get_string(1))] = cells
	return found


func _check_scenes() -> void:
	for scene: Dictionary in _story.get(&"scenes"):
		var resource: DialogueResource = load(scene.dialogue) as DialogueResource
		if resource == null:
			_problems.append("scene %d: cannot load %s" % [int(scene.number), scene.dialogue])
		elif not resource.cues.has(_story.get(&"START_CUE")):
			_problems.append("scene %d: %s has no ~ start cue" % [int(scene.number), scene.dialogue])
		var character: String = scene.character
		if not character.is_empty() and not (_story.get(&"characters") as Dictionary).has(character):
			_problems.append("scene %d: unknown character %s" % [int(scene.number), character])


func _check_pages_fit() -> void:
	var view: CardView = CardView.new()
	root.add_child(view)
	var exhibits: Dictionary = _story.get(&"exhibits")
	var pages: Array[Dictionary] = []
	for card: Dictionary in _story.get(&"cards"):
		for i: int in card.pages.size():
			pages.append({ "name": "card %d page %d" % [int(card.number), i + 1], "number": str(int(card.number)), "title": card.title, "slides": card.slides, "body": card.pages[i] })
	for exhibit_name: String in exhibits:
		var exhibit: Dictionary = exhibits[exhibit_name]
		for i: int in exhibit.get("pages", []).size():
			pages.append({ "name": "%s page %d" % [exhibit_name, i + 1], "number": "", "title": exhibit.title, "slides": "", "body": exhibit.pages[i] })
	for page: Dictionary in pages:
		view.show_page(page.number, page.title, page.slides, page.body, 0, 1, "")
		await process_frame
		await process_frame
		var height: int = view.body_content_height()
		print("%s: body %d of %d px" % [page.name, height, CardView.BODY_SIZE.y])
		if height > CardView.BODY_SIZE.y:
			_problems.append("%s does not fit: %d px of %d; split it into two pages" % [page.name, height, CardView.BODY_SIZE.y])
		if not view.title_fits():
			_problems.append("%s: the title does not fit on one line" % page.name)
	view.queue_free()


# The map loads, and the stage and binder register with Story.
func _check_map(sources: Dictionary) -> void:
	var map: Node = (load("res://world/centre.tscn") as PackedScene).instantiate()
	root.add_child(map)
	current_scene = map
	await process_frame
	await process_frame
	if _story.get(&"stage") == null or _story.get(&"binder") == null:
		_problems.append("the map's stage or binder did not register with Story")
	# Characters are found by their property, since the Npc class needs the
	# autoloads to compile and this script compiles before they exist.
	var characters: PackedStringArray = []
	for node: Node in map.get_node("Actors").get_children():
		var character: Variant = node.get(&"character")
		if character is String:
			characters.append(character)
	print("map characters: %s" % ", ".join(characters))
	for scene: Dictionary in _story.get(&"scenes"):
		if not scene.character.is_empty() and scene.character not in characters:
			_problems.append("scene %d's character %s is not on the map" % [int(scene.number), scene.character])
		if not scene.spot.is_empty() and map.get_node_or_null("Spots/" + scene.spot) == null:
			_problems.append("scene %d's spot %s is not on the map" % [int(scene.number), scene.spot])
	_check_hint_strip(map)
	_check_meter_strip(map)
	await _check_strip_from_start(map.get_node("Dashboard"))
	await _check_am_lassaad(_story.get(&"stage"))
	await _check_backdrop_titles(sources, _story.get(&"stage"), map.get_node("Dashboard"))
	await _check_report_fits(_story.get(&"stage"))
	await _check_debrief_pages(_story.get(&"binder"))
	await _check_last_screen(sources, _story.get(&"stage"), map.get_node("Dashboard"))
	map.queue_free()
	await process_frame


# The camera stops past the map's bottom edge by the height of the strip at the
# bottom of the screen, so the strip covers nothing on the map, and the strip
# is that tall.
func _check_hint_strip(map: Node) -> void:
	var dashboard: Node = map.get_node("Dashboard")
	var strip_height: int = dashboard.get(&"HINT_HEIGHT")
	var drawn: float = (dashboard.get(&"_hint_panel") as Control).size.y
	var map_bottom: int = (map.get_node("Floor") as TileMapLayer).get_used_rect().end.y * TILE_SIZE
	var camera_bottom: int = (map.get_node("Actors/Player/Camera2D") as Camera2D).limit_bottom
	print("hint strip: %d px tall, drawn %d px; the camera stops %d px past the map's bottom" % [strip_height, drawn, camera_bottom - map_bottom])
	if camera_bottom - map_bottom != strip_height:
		_problems.append("the camera stops %d px past the map's bottom, but the strip at the bottom is %d px tall" % [camera_bottom - map_bottom, strip_height])
	if drawn != strip_height:
		_problems.append("the strip at the bottom is drawn %d px tall, not %d" % [drawn, strip_height])


# The camera stops before the map's top edge by the height of the meters' strip
# at the top of the screen, so the strip covers nothing on the map: the part of
# the screen the map can ever reach starts below it. The strip is that tall, as
# wide as the screen, and clear of the strip at the bottom.
func _check_meter_strip(map: Node) -> void:
	var dashboard: Node = map.get_node("Dashboard")
	var strip_height: int = dashboard.get(&"STRIP_HEIGHT")
	var strip: Rect2 = dashboard.call(&"strip_rect")
	var hint: Rect2 = dashboard.call(&"hint_rect")
	var screen: Vector2 = map.get_viewport().get_visible_rect().size
	# The map's edges are its outer walls, outside the floor.
	var tiles: Rect2i = (map.get_node("Floor") as TileMapLayer).get_used_rect()
	for layer: Node in map.get_children():
		if layer is TileMapLayer:
			tiles = tiles.merge((layer as TileMapLayer).get_used_rect())
	var map_top: int = tiles.position.y * TILE_SIZE
	var map_bottom: int = tiles.end.y * TILE_SIZE
	var camera: Camera2D = map.get_node("Actors/Player/Camera2D")
	# Where the map can be on screen: from its top edge with the camera at its
	# highest to its bottom edge with the camera at its lowest.
	var map_area: Rect2 = Rect2(0, map_top - camera.limit_top, screen.x, screen.y - (camera.limit_bottom - map_bottom) - (map_top - camera.limit_top))
	print("meter strip: %s, drawn %s; the map can show from y %d to %d; the strip at the bottom %s"
		% [strip_height, strip, map_area.position.y, map_area.end.y, hint])
	if strip.size.y != strip_height:
		_problems.append("the strip at the top is drawn %d px tall, not %d" % [strip.size.y, strip_height])
	if strip.position != Vector2.ZERO or strip.size.x != screen.x:
		_problems.append("the strip at the top is at %s, not along the screen's top edge" % strip)
	if strip.intersects(map_area):
		_problems.append("the strip at the top (%s) covers the map, which can show from y %d" % [strip, map_area.position.y])
	if hint.intersects(map_area):
		_problems.append("the strip at the bottom (%s) covers the map, which can show down to y %d" % [hint, map_area.end.y])
	if strip.intersects(hint):
		_problems.append("the strip at the top (%s) overlaps the strip at the bottom (%s)" % [strip, hint])


# Each time Am Lassaad comes to the gate, the inspection shows one of story.md's
# four lines, word for word, with no translation; which one is not checked.
func _check_am_lassaad(stage: Object) -> void:
	if stage == null:
		return
	var inspection: Dictionary = _story.get(&"inspection")
	var index: int = -1
	for i: int in (inspection.candidates as Array).size():
		if inspection.candidates[i].name == "Am Lassaad":
			index = i
	if index < 0:
		_problems.append("the inspection has no Am Lassaad")
		return
	var candidate: Dictionary = inspection.candidates[index]
	if candidate.get("says", []) != AM_LASSAAD_LINES:
		_problems.append("Am Lassaad's lines in inspection.json are not story.md's four: %s" % [candidate.get("says", [])])
	var shown_label: Label = stage.get(&"_candidate_shows_label")
	for draw: int in AM_LASSAAD_DRAWS:
		# The inspection waits for the presenter; its wait is dropped unanswered.
		stage.call(&"inspect_candidate", index, inspection)
		await process_frame
		var shown: String = shown_label.text
		var said: String = shown.get_slice("\"", 1)
		if said not in AM_LASSAAD_LINES or shown.count("\"") != 2 or "(" in shown:
			_problems.append("the inspection shows Am Lassaad as %s, not one of story.md's four lines" % shown)
	print("am lassaad: the inspection shows one of the four lines in each of %d draws" % AM_LASSAAD_DRAWS)
	stage.call(&"end_inspection")


# Every title the dialogue puts on the backdrop fits inside the screen's
# margins, and its rendered rect stays [constant TITLE_CLEARANCE] px clear of the
# dashboard's strip above and of the dialogue box's name plate below.
func _check_backdrop_titles(sources: Dictionary, stage: Object, dashboard: Object) -> void:
	if stage == null or dashboard == null:
		return
	var dashboard_bottom: float = (dashboard.call(&"strip_rect") as Rect2).end.y
	var box_top: float = (load(BALLOON_SCRIPT) as Script).get_script_constant_map()[&"NAME_PLATE_TOP"]
	var calls: RegEx = RegEx.create_from_string("Story\\.backdrop\\(\"([^\"]+)\"")
	for path: String in sources:
		for found: RegExMatch in calls.search_all(sources[path]):
			var title: String = found.get_string(1)
			stage.call(&"set_backdrop", title)
			await process_frame
			var fits: bool = stage.call(&"backdrop_title_fits")
			var rect: Rect2 = stage.call(&"backdrop_title_rect")
			print("backdrop title \"%s\": %s, y %d to %d, between the dashboard at %d and the box at %d"
				% [title, "fits" if fits else "does not fit", rect.position.y, rect.end.y, dashboard_bottom, box_top])
			if not fits:
				_problems.append("backdrop title \"%s\" does not fit on one line inside the margins" % title)
			if rect.position.y < dashboard_bottom + TITLE_CLEARANCE:
				_problems.append("backdrop title \"%s\" starts at y %d, within %d px of the dashboard's bottom at %d" % [title, rect.position.y, TITLE_CLEARANCE, dashboard_bottom])
			if rect.end.y > box_top - TITLE_CLEARANCE:
				_problems.append("backdrop title \"%s\" ends at y %d, within %d px of the dialogue box's name plate at %d" % [title, rect.end.y, TITLE_CLEARANCE, box_top])
	stage.call(&"set_backdrop", "")


# In scene 0 the room sees the strip with all four meters, each named, with
# its real value in the text colour and its icon undimmed, and a vote's effect
# shows at once.
func _check_strip_from_start(dashboard: Object) -> void:
	var game_state: Node = root.get_node("GameState")
	game_state.call(&"reset")
	await process_frame
	_check_strip_values(dashboard, game_state, "in scene 0")
	# Scene 0's right answer: Team +5, on the strip straight away.
	game_state.set(&"team", int(game_state.get(&"team")) + 5)
	await process_frame
	_check_strip_values(dashboard, game_state, "after scene 0's vote")
	# From scene 3, the pass rate fakes every meter full until the ending.
	game_state.set(&"team", 20)
	game_state.call(&"set_flag", "metrics_passrate")
	await process_frame
	var faked: Dictionary = dashboard.call(&"shown_meters")
	for meter: String in game_state.get(&"METERS"):
		var full: String = "%d TND" % game_state.get(&"BUDGET_START") if meter == "budget" else "100"
		if faked[meter].value != full:
			_problems.append("with metrics_passrate the %s meter shows \"%s\", not %s" % [meter, faked[meter].value, full])
	game_state.call(&"reveal_dashboard")
	await process_frame
	_check_strip_values(dashboard, game_state, "once the ending reveals it")
	game_state.call(&"reset")


func _check_strip_values(dashboard: Object, game_state: Node, when: String) -> void:
	var shown: Dictionary = dashboard.call(&"shown_meters")
	var seen: PackedStringArray = []
	for meter: String in game_state.get(&"METERS"):
		var cell: Dictionary = shown.get(meter, {})
		var expected: String = "%d TND" % game_state.get(&"budget") if meter == "budget" else str(game_state.get(meter))
		seen.append("%s \"%s\" (on screen %s)" % [cell.get("name", ""), cell.get("value", ""), cell.get("on_screen", false)])
		if not cell.get("on_screen", false):
			_problems.append("%s the %s meter is not on screen" % [when, meter])
		if (cell.get("name", "") as String).is_empty():
			_problems.append("%s the %s meter has no name" % [when, meter])
		if cell.get("value", "") != expected:
			_problems.append("%s the %s meter shows \"%s\", not %s" % [when, meter, cell.get("value", ""), expected])
		if cell.get("value_color") != Palette.TEXT or cell.get("name_color") != Palette.TEXT:
			_problems.append("%s the %s meter's text is not in the text colour" % [when, meter])
		if cell.get("icon_tint") != Color.WHITE:
			_problems.append("%s the %s meter's icon is dimmed" % [when, meter])
	print("strip %s: %s" % [when, ", ".join(seen)])


# Every debrief page, rendered with each vote at its longest option, ends
# above the hint at the binder's bottom, and every card is on a page.
func _check_debrief_pages(binder: Object) -> void:
	if binder == null:
		return
	var game_state: Node = root.get_node("GameState")
	game_state.call(&"reset")
	for card: Dictionary in _story.get(&"cards"):
		var scene: int = int(card.scene)
		if scene not in VOTE_SCENES:
			continue
		var longest: String = OPTIONS[0]
		for option: String in OPTIONS:
			var length: int = (_story.call(&"option_text", scene, option) as String).length() + (card.debrief[option] as String).length()
			if length > (_story.call(&"option_text", scene, longest) as String).length() + (card.debrief[longest] as String).length():
				longest = option
		game_state.call(&"record_vote", scene, longest)
	for i: int in (_story.get(&"inspection").candidates as Array).size():
		(game_state.get(&"inspection_calls") as Dictionary)[i] = true
	binder.call(&"open_debrief")
	await process_frame
	var pages: Array = binder.get(&"_debrief_pages")
	var rows: Control = binder.get(&"_rows")
	var hint_top: float = (binder.get(&"_hint") as Control).get_global_rect().position.y
	var placed: Array = []
	for page: int in pages.size():
		binder.set(&"_debrief_page", page)
		binder.call(&"_render")
		await process_frame
		await process_frame
		var bottom: float = (rows.get_child(rows.get_child_count() - 1) as Control).get_global_rect().end.y
		placed.append_array(pages[page])
		print("debrief page %d of %d: cards %s, rows end at y %d, the hint starts at y %d" % [page + 1, pages.size(), pages[page], bottom, hint_top])
		if bottom > hint_top:
			_problems.append("debrief page %d runs to y %d, past the hint at y %d" % [page + 1, bottom, hint_top])
	if placed.size() != (_story.get(&"cards") as Array).size():
		_problems.append("the debrief pages hold cards %s, not all nine" % [placed])
	binder.call(&"cancel")
	game_state.call(&"reset")


# The report at its longest, every reason shown, fits its pages: each page's
# body no taller than the slide's.
func _check_report_fits(stage: Object) -> void:
	if stage == null:
		return
	var entries: Array[Dictionary] = []
	for criterion: Dictionary in (_story.get(&"report_content") as Dictionary).criteria:
		var lines: Array[String] = []
		for reason: Dictionary in criterion.reasons:
			lines.append(reason.text)
		entries.append({ "criterion": criterion.criterion, "met": false, "lines": lines })
	var pages: Array[String] = stage.call(&"report_pages", entries)
	var view: CardView = stage.get(&"_card_view")
	for i: int in pages.size():
		view.show_rich_page("report", pages[i], i, pages.size(), "")
		await process_frame
		await process_frame
		var height: int = view.body_content_height()
		print("report at its longest, page %d of %d: body %d of %d px" % [i + 1, pages.size(), height, CardView.BODY_SIZE.y])
		if height > CardView.BODY_SIZE.y:
			_problems.append("the report's page %d does not fit: %d px of %d" % [i + 1, height, CardView.BODY_SIZE.y])
	view.hide()


# The last screen, with the ending's own text: everything inside the screen and
# its bottom edge margin, below the strip, no two parts overlapping, name plates
# at least GAP apart, each below its own character.
func _check_last_screen(sources: Dictionary, stage: Object, dashboard: Object) -> void:
	if stage == null:
		return
	var last_call: RegEx = RegEx.create_from_string("Story\\.show_last_screen\\(\"([^\"]*)\", \"([^\"]*)\", \"([^\"]*)\", \"([^\"]*)\"\\)")
	var found: RegExMatch = last_call.search(sources.get(ENDING_DIALOGUE, ""))
	if found == null:
		_problems.append("the ending never shows the last screen")
		return
	stage.call(&"show_last_screen", found.get_string(1), found.get_string(2), found.get_string(3), found.get_string(4))
	for i: int in 5:
		await process_frame
	var areas: Dictionary = (stage.call(&"last_screen") as Object).call(&"areas")
	var strip_bottom: float = (dashboard.call(&"strip_rect") as Rect2).end.y
	# The screen, less its edge margin at the bottom; the strip is checked apart.
	var screen: Rect2 = Rect2(Vector2.ZERO, Vector2(320, 180 - UiStyle.EDGE))
	var names: Array = areas.keys()
	for name: String in names:
		var area: Rect2 = areas[name]
		if not screen.encloses(area) or area.position.y < strip_bottom:
			_problems.append("the last screen's %s at %s is not inside the screen below the strip" % [name, area])
	for i: int in names.size():
		for j: int in range(i + 1, names.size()):
			var first: Rect2 = areas[names[i]]
			var second: Rect2 = areas[names[j]]
			if first.intersects(second):
				_problems.append("the last screen's %s and %s overlap" % [names[i], names[j]])
			elif (names[i] as String).begins_with("plate") and (names[j] as String).begins_with("plate") and first.grow(UiStyle.GAP - 0.5).intersects(second):
				_problems.append("the last screen's %s and %s are closer than %d px" % [names[i], names[j], UiStyle.GAP])
	# Each name plate is below its own character.
	for name: String in names:
		if name.begins_with("plate"):
			var plate: Rect2 = areas[name]
			var sprite: Rect2 = areas["sprite" + name.trim_prefix("plate")]
			if plate.position.y < sprite.end.y:
				_problems.append("the last screen's %s is not below its character" % name)
	print("last screen: %d parts, all inside the screen below y %d: heading %s, body %s" % [names.size(), strip_bottom, areas.heading, areas.body])
	(stage.call(&"last_screen") as Control).hide()


func _card_for_scene(scene: int) -> Dictionary:
	for card: Dictionary in _story.get(&"cards"):
		if int(card.scene) == scene:
			return card
	return {}


func _on_timeout() -> void:
	printerr("FAIL: timed out after %.0f seconds" % TIMEOUT_SECONDS)
	quit(2)
