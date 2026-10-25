extends SceneTree
## Drives the Story autoload the way the title screen and the pause menu do, on
## the real map: restarting mid-scene and starting a new game must leave no
## scene behind, so the first skip goes to scene 1; the ending shows the
## region's report, and skipping the ending goes to the debrief, then the last
## screen. Exits non-zero on failure.
##
##   Godot --headless --path . -s tests/flow_test.gd


## A scene in the middle of the story, to restart from.
const MIDDLE_SCENE: int = 3
const ENDING_SCENE: int = 10
const STORY_OVER: int = 11
## Frames to let a scene change or a balloon settle.
const SETTLE_FRAMES: int = 5
const TIMEOUT_SECONDS: float = 30.0

var _game_state: Node
var _story: Node
var _problems: PackedStringArray = []


func _initialize() -> void:
	create_timer(TIMEOUT_SECONDS).timeout.connect(_on_timeout)
	_main.call_deferred()


func _main() -> void:
	# Autoloads are looked up at run time, since this script compiles before they exist.
	_game_state = root.get_node_or_null("GameState")
	_story = root.get_node_or_null("Story")
	if _game_state == null or _story == null:
		_finish(["the GameState or Story autoload is missing"])
		return
	await _check_restart()
	await _check_ending_skip()
	# Close the last screen's scene, then break the cycle the Dialogue Manager
	# makes by storing each dialogue resource in its own line data, so nothing
	# leaks at exit.
	current_scene.queue_free()
	# Stop the music at once, so no track is still held at exit.
	root.get_node("Music").call(&"silence")
	await _settle()
	for scene: Dictionary in _story.get(&"scenes"):
		var resource: DialogueResource = load(scene.dialogue) as DialogueResource
		for line: Dictionary in resource.lines.values():
			line.erase(&"resource")
	_finish(_problems)


# Start a scene, restart to the title, start a new game and skip: the next scene is 1.
func _check_restart() -> void:
	print("== Restart, new game, skip")
	_story.call(&"new_game")
	await _settle()
	_game_state.set(&"scene", MIDDLE_SCENE)
	_story.call(&"start_scene", MIDDLE_SCENE)
	await _settle()
	print("  started scene %d" % MIDDLE_SCENE)
	_story.call(&"restart")
	await _settle()
	print("  restarted to %s" % current_scene.scene_file_path)
	_story.call(&"new_game")
	await _settle()
	_story.call(&"skip_scene")
	await _settle()
	var scene: int = _game_state.get(&"scene")
	print("  after a skip in the new game, the next scene is %d" % scene)
	_expect(scene == 1, "after restart, a new game and a skip, the next scene is %d, expected 1" % scene)
	_expect(not _story.get(&"in_scene"), "a scene is running after the skip")


# The ending's report, then a skip at the ending's title: the title leaves, the debrief opens, then the last screen.
func _check_ending_skip() -> void:
	print("== Skip during the ending")
	_story.call(&"new_game")
	await _settle()
	var stage: Object = _story.get(&"stage")
	var binder: Object = _story.get(&"binder")
	if stage == null or binder == null:
		_problems.append("the map's stage or binder did not register with Story")
		return
	var title: Label = stage.get(&"_backdrop_title")
	var report: Control = stage.get(&"_card_view")
	var last_screen: Control = stage.call(&"last_screen")
	_game_state.set(&"scene", ENDING_SCENE)
	_story.call(&"start_scene", ENDING_SCENE)
	await _settle()
	# M. Jlassi's call, then the report.
	var balloon: Node = _story.get(&"_balloon")
	for i: int in 3:
		balloon.call(&"next", (balloon.get(&"dialogue_line") as DialogueLine).next_id)
		await _settle()
		if report.visible:
			break
	print("  the ending shows the report: %s" % report.visible)
	_expect(report.visible, "the ending does not show the region's report")
	# The presenter pages through the report; the ending's title follows.
	for i: int in 5:
		if not report.visible:
			break
		stage.call(&"_next_page")
		await _settle()
	print("  after the report, the ending shows \"%s\"" % title.text)
	_expect(not title.text.is_empty(), "the ending shows no title after the report")
	_story.call(&"skip_scene")
	await _settle()
	print("  after the skip: report shown %s, title \"%s\", binder open: %s" % [report.visible, title.text, binder.call(&"is_open")])
	_expect(not report.visible and title.text.is_empty(), "the report or the ending's title stays on screen after the skip")
	_expect(binder.call(&"is_open") and binder.get(&"_mode") == "debrief", "the debrief did not open after the skip")
	# The presenter closes the debrief.
	binder.call(&"_close")
	await _settle()
	var scene: int = _game_state.get(&"scene")
	print("  after the debrief: last screen shown %s, next scene %d" % [last_screen.visible, scene])
	_expect(last_screen.visible, "the last screen did not show after the debrief")
	_expect(scene == STORY_OVER, "the story is not over after the last screen: next scene %d" % scene)


func _expect(ok: bool, problem: String) -> void:
	if not ok:
		_problems.append(problem)


func _settle() -> void:
	for i: int in SETTLE_FRAMES:
		await process_frame


func _finish(problems: PackedStringArray) -> void:
	if problems.is_empty():
		print("PASS: story flow")
		quit(0)
		return
	for problem: String in problems:
		printerr("FAIL: " + problem)
	quit(1)


func _on_timeout() -> void:
	printerr("FAIL: timed out after %.0f seconds" % TIMEOUT_SECONDS)
	quit(2)
