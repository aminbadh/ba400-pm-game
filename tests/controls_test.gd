extends SceneTree
## Checks the controls: every action the game adds to the input map (Godot's
## own ui_ actions aside) has a key and a joypad
## event, except the presenter's number keys, which pick a vote's letter or a
## gate call directly and so must have none (a controller points and confirms,
## never one button per letter); the hints switch to the controller's buttons
## after a controller press and back to the keys after a key press, on the title
## screen too; and the controller check names what a press is. Exits non-zero on failure.
##
##   Godot --headless --path . -s tests/controls_test.gd


## The keyboard's direct picks: a vote's A, B and C, the gate's admit and stop.
const KEYBOARD_ONLY: Array[String] = ["choice_1", "choice_2", "choice_3"]
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
