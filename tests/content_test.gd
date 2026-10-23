extends SceneTree
## Checks the content files against the dialogue: every card and exhibit the
## dialogue shows exists, every vote has its three debrief lines, every flag is
## one the story uses, every scene's dialogue starts at its cue, and every card
## page fits on screen at the base resolution. Exits non-zero on failure.
##
##   Godot --headless --path . -s tests/content_test.gd


const DIALOGUE_DIR: String = "res://dialogue/"
## The flags story.md defines.
const FLAGS: Array[String] = [
	"room12_fixed", "metrics_people", "metrics_exam", "metrics_passrate",
	"raci_clear", "raci_double", "raci_none", "staff_borrowed", "rooms_crowded",
	"staff_thin", "staff_trained", "staff_protected", "bought_tech",
]
## The scenes whose votes story.md writes, each with options A, B and C.
const VOTE_SCENES: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7, 8]
const OPTIONS: Array[String] = ["A", "B", "C"]
const TIMEOUT_SECONDS: float = 20.0

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
		_check_scenes()
		await _check_pages_fit()
		await _check_map()
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
			if not recorded.has("%d%s" % [scene, option]):
				_problems.append("scene %d's dialogue never records option %s" % [scene, option])
		print("scene %d vote: debrief lines for A, B and C on card %d" % [scene, int(card.number)])
	for key: String in recorded:
		var scene: int = int(key.left(-1))
		if scene not in VOTE_SCENES:
			_problems.append("%s records a vote in scene %d, which has none in story.md" % [recorded[key], scene])


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
func _check_map() -> void:
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
	map.queue_free()
	await process_frame


func _card_for_scene(scene: int) -> Dictionary:
	for card: Dictionary in _story.get(&"cards"):
		if int(card.scene) == scene:
			return card
	return {}


func _on_timeout() -> void:
	printerr("FAIL: timed out after %.0f seconds" % TIMEOUT_SECONDS)
	quit(2)
