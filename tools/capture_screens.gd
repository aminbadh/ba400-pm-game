extends SceneTree
## Captures one screenshot of each kind of screen, for the projector check:
## the title, the map in scene 0 with the strip greyed out, a line with a
## portrait, a long line paging, a vote as it appears and after an arrow key,
## a card, the same card with the controller's hints, a chart, the gate
## inspection and Am Lassaad's longest line there, the dashboard, the binder,
## the pause menu and its controller check, M. Jlassi's call, the region's
## report, the ending, the debrief and the last screen. Each is saved at 1920x1080, the game's 320x180 scaled x6 as on a
## 1920x1080 projector, to build/screens/. Needs a window, not --headless:
##
##   Godot --path . -s tools/capture_screens.gd
##
## Then `uv run tools/washout.py` makes a washed-out copy of each.


const OUT_DIR: String = "res://build/screens/"
const SCALE: int = 6
const KEY_INTERACT: Key = KEY_E

var _story: Node
var _game_state: Node
var _count: int = 0


func _initialize() -> void:
	_main.call_deferred()


func _main() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_story = root.get_node("Story")
	_game_state = root.get_node("GameState")

	change_scene_to_file("res://ui/title/title.tscn")
	await _frames(10)
	await _capture("title")

	_story.call(&"new_game")
	await _frames(10)
	var map: Node = current_scene
	var player: Node2D = map.get_node("Actors/Player")
	player.position = Vector2(200, 200)
	await _frames(10)
	await _capture("map_scene0_strip")
	# At the bottom of the map, by the gate, the camera's lowest.
	player.position = Vector2(200, 296)
	await _frames(10)
	await _capture("map_gate")

	# Scene 0's second line is the longest: it pages, three lines at a time.
	player.position = Vector2(56, 88)
	await _frames(10)
	_story.call(&"start_scene", 0)
	await _seconds(2.5)
	await _press()
	await _seconds(4.0)
	await _capture("dialogue_long_line_page_1")
	await _press()
	await _seconds(3.0)
	await _capture("dialogue_long_line_page_2")
	_story.call(&"skip_scene")
	await _frames(10)

	# Scene 1 in Room 12: Mme Kchaou's first line, then on to the card and the vote.
	_game_state.set(&"scene", 1)
	_story.emit_signal(&"scene_changed")
	player.position = Vector2(280, 88)
	await _frames(10)
	_story.call(&"start_scene", 1)
	await _seconds(3.0)
	await _capture("dialogue_portrait")
	var card_taken: bool = false
	for i: int in 40:
		await _press()
		await _seconds(1.2)
		var stage: Node = _story.get(&"stage")
		if not card_taken and (stage.get(&"_card_view") as Control).visible:
			await _capture("card")
			# The same card's hint after a controller press: the cross button.
			Input.parse_input_event(_joypad_button(JOY_BUTTON_X))
			await _frames(5)
			await _capture("card_controller_hint")
			await _key(KEY_Q)
			await _frames(5)
			card_taken = true
		if _vote_showing():
			break
	await _seconds(1.0)
	await _capture("vote")
	# The first arrow key shows the focus, and moves it.
	await _key(KEY_DOWN)
	await _seconds(0.3)
	await _capture("vote_after_arrow")
	await _seconds(19.2)
	await _capture("vote_time_up")
	await _key(KEY_2)
	await _seconds(0.5)
	await _capture("vote_chosen")
	_story.call(&"skip_scene")
	await _frames(10)

	var stage: Node = _story.get(&"stage")
	var exhibits: Dictionary = _story.get(&"exhibits")
	stage.call(&"present_exhibit", "histogram", exhibits.histogram, "")
	await _frames(5)
	await _capture("chart_histogram")
	stage.call(&"cancel")
	stage.call(&"present_exhibit", "raci", exhibits.raci, "")
	await _frames(5)
	await _capture("chart_raci")
	stage.call(&"cancel")
	stage.call(&"present_exhibit", "org_chart", exhibits.org_chart, "")
	await _frames(5)
	await _capture("chart_org")
	stage.call(&"cancel")
	stage.call(&"inspect_candidate", 2, _story.get(&"inspection"))
	await _frames(5)
	await _capture("inspection")
	stage.call(&"cancel")
	# Am Lassaad at the gate, saying his longest line, to check it fits.
	var inspection: Dictionary = _story.get(&"inspection")
	var lassaad: int = (inspection.candidates as Array).find_custom(func(c: Dictionary) -> bool: return c.name == "Am Lassaad")
	var longest: String = ""
	for line: String in inspection.candidates[lassaad].says:
		if line.length() > longest.length():
			longest = line
	for draw: int in 40:
		stage.call(&"inspect_candidate", lassaad, inspection)
		if longest in (stage.get(&"_candidate_shows_label") as Label).text:
			break
		stage.call(&"cancel")
	await _frames(5)
	await _capture("inspection_am_lassaad")
	stage.call(&"cancel")

	# The dashboard, lit, with the meters at different levels, on the map.
	_game_state.set(&"scene", 6)
	_game_state.set(&"integrity", 75)
	_game_state.set(&"fairness", 45)
	_game_state.set(&"team", 20)
	(_game_state.get(&"lit_meters") as Array).assign(["integrity", "fairness", "team", "budget"])
	_game_state.emit_signal(&"changed")
	_story.emit_signal(&"scene_changed")
	player.position = Vector2(200, 232)
	await _frames(10)
	await _capture("dashboard")
	# At the top of the map, the camera's highest: the strip clears the top wall.
	player.position = Vector2(200, 40)
	await _frames(10)
	await _capture("dashboard_map_top")
	player.position = Vector2(200, 232)
	await _frames(10)

	var binder: Node = map.get_node("Binder")
	binder.call(&"open")
	await _frames(5)
	await _capture("binder")
	binder.call(&"cancel")
	await _frames(5)

	var pause: Node = map.get_node("PauseMenu")
	pause.call(&"_open")
	await _frames(5)
	await _capture("pause")
	pause.call(&"_show_check")
	Input.parse_input_event(_joypad_button(JOY_BUTTON_DPAD_LEFT))
	await _frames(5)
	await _capture("pause_controller_check")
	await _key(KEY_Q)
	pause.call(&"_resume")
	await _frames(5)

	# The ending: M. Jlassi's call, the region's report, the ending's title
	# with its line, the debrief, then the last screen.
	_game_state.set(&"scene", 10)
	_story.call(&"start_scene", 10)
	await _seconds(3.0)
	await _capture("ending_call")
	await _press()
	await _seconds(1.0)
	await _capture("report")
	var card_view: Control = stage.get(&"_card_view")
	for i: int in 5:
		if not card_view.visible:
			break
		await _press()
		await _seconds(0.6)
		if card_view.visible:
			await _capture("report_page_%d" % (i + 2))
	await _seconds(3.0)
	await _capture("ending")
	_story.call(&"skip_scene")
	await _seconds(1.0)
	await _capture("debrief")
	await _press()
	await _seconds(0.5)
	await _capture("debrief_page_2")
	_story.call(&"skip_scene")
	await _seconds(1.0)
	await _capture("last_screen")

	print("captured %d screens in %s" % [_count, ProjectSettings.globalize_path(OUT_DIR)])
	quit(0)


func _vote_showing() -> bool:
	var balloon: Node = _story.get(&"_balloon")
	return is_instance_valid(balloon) and (balloon.get(&"responses_menu") as Control).visible


func _capture(screen_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	image.resize(image.get_width() * SCALE, image.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	_count += 1
	var path: String = OUT_DIR + "%02d_%s.png" % [_count, screen_name]
	image.save_png(path)
	print("saved " + path)


func _joypad_button(button: JoyButton) -> InputEventJoypadButton:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	return event


func _press() -> void:
	await _key(KEY_INTERACT)


func _key(key: Key) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame


func _frames(count: int) -> void:
	for i: int in count:
		await process_frame


func _seconds(seconds: float) -> void:
	await create_timer(seconds).timeout
