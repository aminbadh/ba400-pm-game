extends SceneTree
## Checks the controls: every action the game adds to the input map (Godot's
## own ui_ actions aside) has a key and a joypad
## event, except the presenter's number keys, which pick a vote's letter or a
## gate call directly and so must have none (a controller points and confirms,
## never one button per letter); the hints switch to the controller's buttons
## after a controller press and back to the keys after a key press, on the title
## screen too; the controller check names what a press is; and one push of the
## left stick, a stream of motion events, moves the binder and the pause menu
## one row, with a held push repeating after 0.4 s and every 0.15 s; F11 and
## Alt+Enter switch full screen, anywhere and in the pause menu, without Enter
## also confirming the menu's item, and so does the menu's Full screen item.
## Exits non-zero on failure.
##
##   Godot --headless --path . -s tests/controls_test.gd


## The keyboard's direct picks: a vote's A, B and C, the gate's admit and stop;
## and full screen, which a controller reaches through the pause menu only.
const KEYBOARD_ONLY: Array[String] = ["choice_1", "choice_2", "choice_3", "full_screen"]
## The keys that switch full screen: F11 and Alt+Enter, as [physical key, Alt].
const FULL_SCREEN_KEYS: Array[Array] = [[KEY_F11, false], [KEY_ENTER, true]]
const TITLE_SCENE: String = "res://ui/title/title.tscn"
## Scripts that need the autoloads, loaded once they exist.
const STAGE_SCRIPT: String = "res://ui/stage/stage.gd"
const PAUSE_SCRIPT: String = "res://ui/pause_menu/pause_menu.gd"
const SETTLE_FRAMES: int = 5
const TIMEOUT_SECONDS: float = 20.0

var _hints: Node
var _problems: PackedStringArray = []


func _initialize() -> void:
	create_timer(TIMEOUT_SECONDS).timeout.connect(_on_timeout)
	_main.call_deferred()


func _main() -> void:
	# Autoloads are looked up at run time, since this script compiles before they exist.
	_hints = root.get_node_or_null("Hints")
	if _hints == null:
		_finish(["the Hints autoload is missing"])
		return
	_check_input_map()
	change_scene_to_file(TITLE_SCENE)
	await _settle()
	# Success must be explicit: a coroutine that dies on a runtime error hands its caller nothing.
	if await _check_hints() != true:
		_problems.append("the hints check stopped on a script error")
	_check_controller_names()
	if await _check_stick() != true:
		_problems.append("the stick check stopped on a script error")
	if await _check_full_screen() != true:
		_problems.append("the full screen check stopped on a script error")
	# Close the map, stop the music at once, so nothing is held at exit.
	root.get_node("Story").call(&"restart")
	root.get_node("Music").call(&"silence")
	# The audio server lets the track go on its next mix.
	await create_timer(0.2, true).timeout
	_finish(_problems)


func _check_input_map() -> void:
	print("== Input map")
	for property: Dictionary in ProjectSettings.get_property_list():
		var setting: String = property.name
		if not setting.begins_with("input/"):
			continue
		var action: String = setting.trim_prefix("input/")
		if action.begins_with("ui_"):
			continue
		var keys: int = 0
		var pads: int = 0
		for event: InputEvent in (ProjectSettings.get_setting(setting) as Dictionary).events:
			if event is InputEventKey:
				keys += 1
			elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
				pads += 1
		print("  %s: %d key, %d joypad" % [action, keys, pads])
		if keys == 0:
			_problems.append("%s has no key" % action)
		if action in KEYBOARD_ONLY:
			if pads > 0:
				_problems.append("%s picks one letter directly, so it must have no joypad event" % action)
		elif pads == 0:
			_problems.append("%s has no joypad event" % action)
	var full_screen_keys: Array[Array] = []
	for event: InputEvent in InputMap.action_get_events(&"full_screen"):
		if event is InputEventKey:
			full_screen_keys.append([(event as InputEventKey).physical_keycode, (event as InputEventKey).alt_pressed])
	print("  full_screen keys: %s" % [full_screen_keys])
	_expect(full_screen_keys == FULL_SCREEN_KEYS, "full_screen has the keys %s, not %s" % [full_screen_keys, FULL_SCREEN_KEYS])


# A controller press switches every hint to its buttons; a key press switches
# back. The presses do nothing else: none of them starts the game from the title.
func _check_hints() -> bool:
	print("== Hints")
	var start: Button = current_scene.get_node("%Start")
	var keys: Label = current_scene.get_node("%Keys")
	var cross: String = Glyphs.CROSS_BUTTON
	var steps: Array[Dictionary] = [
		{ "event": _joypad_button(JOY_BUTTON_X), "joypad": true, "start": cross + "  Start", "prompt": "← Admit    → Stop" },
		{ "event": _key(KEY_Q), "joypad": false, "start": "E  Start", "prompt": "1 Admit    2 Stop" },
		{ "event": _joypad_motion(JOY_AXIS_LEFT_X, 0.9), "joypad": true, "start": cross + "  Start", "prompt": "← Admit    → Stop" },
	]
	for step: Dictionary in steps:
		Input.parse_input_event(step.event)
		await _settle()
		var prompt: String = (load(STAGE_SCRIPT) as Script).call(&"inspection_prompt", -1)
		print("  after %s: joypad %s, title \"%s\", keys \"%s\", gate \"%s\"" % [step.event.as_text(), _hints.get(&"joypad"), start.text, keys.text, prompt])
		_expect(_hints.get(&"joypad") == step.joypad, "after %s the last device is %s" % [step.event.as_text(), "the controller" if _hints.get(&"joypad") else "the keyboard"])
		_expect(start.text == step.start, "after %s the title's prompt reads \"%s\", not \"%s\"" % [step.event.as_text(), start.text, step.start])
		_expect(prompt == step.prompt, "after %s the gate's prompt reads \"%s\", not \"%s\"" % [step.event.as_text(), prompt, step.prompt])
	# A stick resting near the middle is drift, not a press.
	Input.parse_input_event(_key(KEY_Q))
	Input.parse_input_event(_joypad_motion(JOY_AXIS_LEFT_X, 0.1))
	await _settle()
	_expect(not _hints.get(&"joypad"), "a stick drifting at 0.1 switched the hints to the controller")
	return true


func _check_controller_names() -> void:
	print("== Controller check")
	var cases: Array[Array] = [
		[_joypad_button(JOY_BUTTON_A), "Cross ✕ (button 0)"],
		[_joypad_button(JOY_BUTTON_START), "Start (button 6)"],
		[_joypad_button(JOY_BUTTON_DPAD_LEFT), "D-pad left (button 13)"],
		[_joypad_motion(JOY_AXIS_LEFT_Y, -0.9), "Left stick up (axis 1)"],
	]
	for case: Array in cases:
		var shown: String = (load(PAUSE_SCRIPT) as Script).call(&"pressed_name", case[0])
		print("  %s: %s" % [(case[0] as InputEvent).as_text(), shown])
		_expect(shown == case[1], "the controller check names %s \"%s\", not \"%s\"" % [(case[0] as InputEvent).as_text(), shown, case[1]])


# One push of the stick moves one row; a held push repeats; raw stick motion is
# not Godot's own arrows, which would move a vote's focus once per event.
func _check_stick() -> bool:
	print("== Stick")
	for action: StringName in [&"ui_up", &"ui_down"]:
		if InputMap.event_is_action(_joypad_motion(JOY_AXIS_LEFT_Y, 1.0), action):
			_problems.append("stick motion still counts as %s, so a vote's focus moves once per event" % action)
	root.get_node("Story").call(&"new_game")
	await _settle()
	var binder: Node = current_scene.get_node("Binder")
	binder.call(&"open")
	# The binder ignores presses for a moment after it opens.
	await create_timer(0.4, true).timeout
	await _expect_rows(binder, "the binder")
	binder.call(&"cancel")
	await _settle()
	var pause: Node = current_scene.get_node("PauseMenu")
	pause.call(&"_open")
	await _settle()
	await _expect_rows(pause, "the pause menu")
	pause.call(&"_resume")
	await _settle()
	return true


# F11 and Alt+Enter switch the window between full screen and windowed, on the
# map and in the pause menu, where Alt+Enter's Enter must not also confirm the
# selected item (here Full screen itself, which would switch it back); the
# menu's item switches it too and reads the new state.
func _check_full_screen() -> bool:
	print("== Full screen")
	var screen: Node = root.get_node("Screen")
	screen.call(&"set_full_screen", false)
	var alt_enter: InputEventKey = _key(KEY_ENTER)
	alt_enter.alt_pressed = true
	var pause: Node = current_scene.get_node("PauseMenu")
	var item: int = (pause.get(&"OPTIONS") as Array).find("Full screen")
	var steps: Array[Dictionary] = [
		{ "name": "F11 on the map", "event": _key(KEY_F11), "on": true, "paused": false },
		{ "name": "Alt+Enter on the map", "event": alt_enter, "on": false, "paused": false },
		{ "name": "F11 in the pause menu", "event": _key(KEY_F11), "on": true, "paused": true },
		{ "name": "Alt+Enter in the pause menu", "event": alt_enter.duplicate(), "on": false, "paused": true },
	]
	for step: Dictionary in steps:
		if step.paused and not pause.get(&"visible"):
			pause.call(&"_open")
			pause.call(&"_select", item)
			await _settle()
		Input.parse_input_event(step.event)
		await _settle()
		var on: bool = screen.call(&"is_full_screen")
		print("  after %s: full screen %s, window mode %d" % [step.name, on, root.mode])
		_expect(on == step.on, "after %s full screen is %s, expected %s" % [step.name, on, step.on])
		# Headless, there is no window to switch; with one, its mode must follow.
		if DisplayServer.get_name() != "headless":
			_expect((DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN) == step.on, "after %s the window mode is %d" % [step.name, DisplayServer.window_get_mode()])
		if step.paused:
			var text: String = pause.call(&"option_text", item)
			_expect(text == ("Full screen: On" if step.on else "Full screen: Off"), "after %s the menu reads \"%s\"" % [step.name, text])
	_expect(pause.get(&"visible") and paused, "Alt+Enter in the pause menu confirmed an item")
	pause.call(&"_choose", item)
	print("  after the menu's item: full screen %s, \"%s\"" % [screen.call(&"is_full_screen"), pause.call(&"option_text", item)])
	_expect(screen.call(&"is_full_screen") and pause.call(&"option_text", item) == "Full screen: On", "the menu's Full screen item did not switch full screen on")
	pause.call(&"_choose", item)
	_expect(not screen.call(&"is_full_screen"), "the menu's Full screen item did not switch full screen off")
	pause.call(&"_resume")
	await _settle()
	return true


# In [param screen], one push down moves its selection one row; a push held
# for 0.65 s moves it three: at once, after 0.4 s and after 0.55 s.
func _expect_rows(screen: Node, screen_name: String) -> void:
	var start: int = screen.get(&"_selected")
	for value: float in [0.1, 0.3, 0.5, 0.7, 0.9, 1.0, 1.0, 0.95, 1.0]:
		Input.parse_input_event(_joypad_motion(JOY_AXIS_LEFT_Y, value))
		await process_frame
	for value: float in [0.6, 0.2, 0.0]:
		Input.parse_input_event(_joypad_motion(JOY_AXIS_LEFT_Y, value))
		await process_frame
	await _settle()
	var one_push: int = int(screen.get(&"_selected")) - start
	Input.parse_input_event(_joypad_motion(JOY_AXIS_LEFT_Y, 1.0))
	await create_timer(0.65, true).timeout
	Input.parse_input_event(_joypad_motion(JOY_AXIS_LEFT_Y, 0.0))
	await _settle()
	var held: int = int(screen.get(&"_selected")) - start - one_push
	print("  %s: one push moved %d row, a 0.65 s hold moved %d" % [screen_name, one_push, held])
	_expect(one_push == 1, "one push of the stick moved %s %d rows, not 1" % [screen_name, one_push])
	_expect(held == 3, "holding the stick for 0.65 s moved %s %d rows, not 3" % [screen_name, held])


func _joypad_button(button: JoyButton) -> InputEventJoypadButton:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	return event


func _joypad_motion(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event: InputEventJoypadMotion = InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	return event


func _key(key: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	return event


func _expect(ok: bool, problem: String) -> void:
	if not ok:
		_problems.append(problem)


func _settle() -> void:
	for i: int in SETTLE_FRAMES:
		await process_frame


func _finish(problems: PackedStringArray) -> void:
	if problems.is_empty():
		print("PASS: controls and hints")
		quit(0)
		return
	for problem: String in problems:
		printerr("FAIL: " + problem)
	quit(1)


func _on_timeout() -> void:
	printerr("FAIL: timed out after %.0f seconds" % TIMEOUT_SECONDS)
	quit(2)
