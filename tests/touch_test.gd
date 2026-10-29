extends SceneTree
## Checks the touch controls: no touch control exists before the screen is
## touched; a touch makes them and switches the hints to taps, and a key or a
## controller button hides them again; each screen shows only the buttons it
## needs; the D-pad, Talk, Binder and Menu press their actions while held, a
## finger slides across the D-pad, and two fingers work at once; a tap turns a
## card, picks a binder row, a pause menu item and the gate's Admit or Stop,
## but a tap on a button is the button's alone; and a window taller than wide
## is a phone held upright. Exits non-zero on failure.
##
##   Godot --headless --path . -s tests/touch_test.gd


const TITLE_SCENE: String = "res://ui/title/title.tscn"
## Scripts that need the autoloads, loaded once they exist.
const STAGE_SCRIPT: String = "res://ui/stage/stage.gd"
const KEYBOARD_HINTS: Dictionary[String, String] = { "start": "E  Start", "keys": "Move WASD   Talk E   Binder B   Menu Esc" }
const TOUCH_HINTS: Dictionary[String, String] = { "start": "Tap  Start", "keys": "Walk with the D-pad   Tap Talk, Binder or Menu", "gate": "Tap Admit    Tap Stop" }
const WALKING: Array[String] = ["up", "down", "left", "right", "talk", "binder", "menu"]
## Somewhere on the map no button covers.
const OPEN_GROUND: Vector2 = Vector2(160, 80)
## The binder and the stage ignore presses this long after they open.
const GUARD_SECONDS: float = 0.4
const SETTLE_FRAMES: int = 5
const TIMEOUT_SECONDS: float = 30.0

var _touch: Node
var _hints: Node
var _story: Node
var _problems: PackedStringArray = []


func _initialize() -> void:
	create_timer(TIMEOUT_SECONDS).timeout.connect(_on_timeout)
	_main.call_deferred()


func _main() -> void:
	# Autoloads are looked up at run time, since this script compiles before they exist.
	_touch = root.get_node_or_null("Touch")
	_hints = root.get_node_or_null("Hints")
	_story = root.get_node_or_null("Story")
	if _touch == null:
		_finish(["the Touch autoload is missing"])
		return
	change_scene_to_file(TITLE_SCENE)
	await _settle()
	# Success must be explicit: a coroutine that dies on a runtime error hands its caller nothing.
	if await _check_first_touch() != true:
		_problems.append("the first touch check stopped on a script error")
	if await _check_buttons() != true:
		_problems.append("the buttons check stopped on a script error")
	if await _check_taps() != true:
		_problems.append("the taps check stopped on a script error")
	_check_upright()
	_story.call(&"restart")
	root.get_node("Music").call(&"silence")
	await create_timer(0.2, true).timeout
	_finish(_problems)


# Before a touch nothing is made and the title reads as for the keyboard; the
# first touch makes the controls, shows none on the title, and the title reads
# in taps; a key brings the keyboard's hints back.
func _check_first_touch() -> bool:
	print("== First touch")
	var start: Button = current_scene.get_node("%Start")
	var keys: Label = current_scene.get_node("%Keys")
	print("  before a touch: made %s, %d children, title \"%s\", keys \"%s\"" % [_touch.call(&"is_made"), _touch.get_child_count(), start.text, keys.text])
	_expect(not _touch.call(&"is_made") and _touch.get_child_count() == 0, "a touch control exists before the screen was touched")
	_expect(start.text == KEYBOARD_HINTS.start and keys.text == KEYBOARD_HINTS.keys, "before a touch the title reads \"%s\" and \"%s\"" % [start.text, keys.text])
	# A corner of the title, clear of Start, so the touch does not start the game.
	await _tap(Vector2(UiStyle.EDGE, UiStyle.EDGE))
	print("  after a touch: made %s, shown %s, title \"%s\", keys \"%s\"" % [_touch.call(&"is_made"), _touch.call(&"shown"), start.text, keys.text])
	_expect(_touch.call(&"is_made"), "a touch did not make the touch controls")
	_expect(_hints.call(&"is_touch"), "a touch did not switch the hints to touch")
	_expect((_touch.call(&"shown") as Array).is_empty(), "the title shows the buttons %s; Start is tapped itself" % [_touch.call(&"shown")])
	_expect(start.text == TOUCH_HINTS.start, "after a touch the title's prompt reads \"%s\", not \"%s\"" % [start.text, TOUCH_HINTS.start])
	_expect(keys.text == TOUCH_HINTS.keys, "after a touch the title's keys read \"%s\", not \"%s\"" % [keys.text, TOUCH_HINTS.keys])
	var prompt: String = (load(STAGE_SCRIPT) as Script).call(&"inspection_prompt", -1)
	_expect(prompt == TOUCH_HINTS.gate, "after a touch the gate's prompt reads \"%s\", not \"%s\"" % [prompt, TOUCH_HINTS.gate])
	_expect(current_scene.scene_file_path == TITLE_SCENE, "a touch beside Start started the game")
	Input.parse_input_event(_key(KEY_Q))
	await _settle()
	_expect(start.text == KEYBOARD_HINTS.start and keys.text == KEYBOARD_HINTS.keys, "after a key the title reads \"%s\" and \"%s\"" % [start.text, keys.text])
	return true


# On the map each button presses its action while held, and only then.
func _check_buttons() -> bool:
	print("== Buttons")
	_story.call(&"new_game")
	await _settle()
	await _tap(OPEN_GROUND)
	print("  on the map: %s" % [_touch.call(&"shown")])
	_expect(_touch.call(&"shown") == WALKING, "walking shows %s, not %s" % [_touch.call(&"shown"), WALKING])
	for button: String in ["up", "down", "left", "right", "talk"]:
		var action: StringName = (_touch.get(&"BUTTONS") as Dictionary)[button].action
		_touch_at(0, _centre(button), true)
		await _settle()
		var held: bool = Input.is_action_pressed(action)
		_touch_at(0, _centre(button), false)
		await _settle()
		print("  %s: %s held %s, released %s" % [button, action, held, Input.is_action_pressed(action)])
		_expect(held and not Input.is_action_pressed(action), "%s does not press %s only while held" % [button, action])
	# A finger slides from right to up; a second finger on Talk works at once.
	_touch_at(0, _centre("right"), true)
	await _settle()
	_drag(0, _centre("up"))
	_touch_at(1, _centre("talk"), true)
	await _settle()
	var slid: bool = Input.is_action_pressed(&"move_up") and not Input.is_action_pressed(&"move_right")
	var both: bool = Input.is_action_pressed(&"interact")
	_touch_at(0, _centre("up"), false)
	_touch_at(1, _centre("talk"), false)
	await _settle()
	print("  slid right to up: %s; Talk with a second finger: %s" % [slid, both])
	_expect(slid, "sliding a finger from right to up on the D-pad did not walk up")
	_expect(both, "a second finger on Talk did not press interact while the first held the D-pad")

	# Binder opens the binder, where only Binder shows, and closes it.
	var binder: Node = _story.get(&"binder")
	await _tap(_centre("binder"))
	await create_timer(GUARD_SECONDS, true).timeout
	print("  binder: open %s, shown %s" % [binder.call(&"is_open"), _touch.call(&"shown")])
	_expect(binder.call(&"is_open"), "Binder did not open the binder")
	_expect(_touch.call(&"shown") == ["binder"], "the binder's list shows %s, not Binder alone" % [_touch.call(&"shown")])
	await _tap(_centre("binder"))
	_expect(not binder.call(&"is_open"), "Binder did not close the binder")

	# Menu opens the pause menu, where only Menu shows, and resumes.
	var pause: Node = current_scene.get_node("PauseMenu")
	await _tap(_centre("menu"))
	print("  pause menu: open %s, shown %s" % [pause.get(&"visible"), _touch.call(&"shown")])
	_expect(pause.get(&"visible") and paused, "Menu did not open the pause menu")
	_expect(_touch.call(&"shown") == ["menu"], "the pause menu shows %s, not Menu alone" % [_touch.call(&"shown")])
	await _tap(_centre("menu"))
	_expect(not pause.get(&"visible") and not paused, "Menu did not resume the game")

	# A key or a controller button hides every button; a touch brings them back.
	for event: InputEvent in [_key(KEY_Q), _joypad_button(JOY_BUTTON_X)]:
		Input.parse_input_event(event)
		await _settle()
		print("  after %s: shown %s" % [event.as_text(), _touch.call(&"shown")])
		_expect((_touch.call(&"shown") as Array).is_empty(), "after %s the buttons %s still show" % [event.as_text(), _touch.call(&"shown")])
		await _tap(OPEN_GROUND)
		_expect(_touch.call(&"shown") == WALKING, "a touch after %s did not bring the buttons back" % event.as_text())

	# In a scene the player stands still: no D-pad or Talk over the balloon.
	# What the buttons read of a scene running, without its dialogue.
	_story.set(&"in_scene", true)
	await _settle()
	print("  in a scene: %s" % [_touch.call(&"shown")])
	_expect(_touch.call(&"shown") == ["binder", "menu"], "a scene shows %s, not Binder and Menu" % [_touch.call(&"shown")])
	_story.set(&"in_scene", false)
	_story.call(&"restart")
	await _settle()
	return true


# Taps on the screens that take them, and none taken from under a button.
func _check_taps() -> bool:
	print("== Taps")
	_story.call(&"new_game")
	await _settle()
	await _tap(OPEN_GROUND)
	var on_button: InputEventMouseButton = _click(_centre("talk"), InputEvent.DEVICE_ID_EMULATION)
	var on_ground: InputEventMouseButton = _click(OPEN_GROUND, InputEvent.DEVICE_ID_EMULATION)
	var mouse: InputEventMouseButton = _click(OPEN_GROUND, 0)
	_expect(not _touch.call(&"is_tap", on_button), "a tap on Talk counts as a tap for the screen under it")
	_expect(_touch.call(&"is_tap", on_ground), "a tap on open ground is not a tap")
	_expect(not _touch.call(&"is_tap", mouse), "a real mouse's click counts as a tap")

	# A card fills the screen, shows no button, and a tap turns it.
	var stage: Node = _story.get(&"stage")
	var card: Dictionary = (_story.get(&"cards") as Array)[0]
	stage.call(&"present_card", card)
	await create_timer(GUARD_SECONDS, true).timeout
	print("  a card: covers %s, shown %s" % [stage.call(&"covers_screen"), _touch.call(&"shown")])
	_expect((_touch.call(&"shown") as Array).is_empty(), "a card shows the buttons %s" % [_touch.call(&"shown")])
	for page: int in (card.pages as Array).size():
		await _tap(OPEN_GROUND)
		await create_timer(GUARD_SECONDS, true).timeout
	_expect(not stage.call(&"covers_screen"), "tapping each of the card's %d pages did not close it" % (card.pages as Array).size())

	# The last screen keeps only Menu, to restart from.
	stage.call(&"show_last_screen", "Thank you!", "", "", "")
	await _settle()
	print("  the last screen: %s" % [_touch.call(&"shown")])
	_expect(_touch.call(&"shown") == ["menu"], "the last screen shows %s, not Menu alone" % [_touch.call(&"shown")])
	stage.call(&"cancel")
	await _settle()

	# The gate: the corner under the candidate, Admit on its left, Stop on its right.
	var calls: Array[Array] = [[Vector2(230, 165), 0], [Vector2(300, 165), 1], [OPEN_GROUND, -1]]
	for case: Array in calls:
		var call: int = stage.call(&"tapped_call", case[0])
		print("  the gate at %s: %d" % [case[0], call])
		_expect(call == case[1], "a tap at %s at the gate calls %d, not %d" % [case[0], call, case[1]])

	# The binder's rows and the pause menu's items take taps.
	var binder: Node = _story.get(&"binder")
	binder.call(&"open")
	await _settle()
	var row_rect: Rect2 = (binder.get(&"_rows") as Control).get_child(2).get_global_rect()
	print("  binder row 2 at %s: %d" % [row_rect.get_center(), binder.call(&"tapped_row", row_rect.get_center())])
	_expect(binder.call(&"tapped_row", row_rect.get_center()) == 2, "a tap on the binder's third row is not that row")
	binder.call(&"cancel")
	await _settle()
	var pause: Node = current_scene.get_node("PauseMenu")
	pause.call(&"_open")
	await _settle()
	var labels: Array = pause.get(&"_labels")
	var resume: Vector2 = (labels[0] as Control).get_global_rect().get_center()
	var skip: Vector2 = (labels[(pause.get(&"OPTIONS") as Array).find("Skip to next scene")] as Control).get_global_rect().get_center()
	_expect(pause.call(&"tapped_item", skip) == (pause.get(&"OPTIONS") as Array).find("Skip to next scene"), "a tap on Skip to next scene is not that item")
	await _tap(resume)
	print("  tapped Resume: pause menu open %s" % pause.get(&"visible"))
	_expect(not pause.get(&"visible") and not paused, "a tap on Resume did not resume")
	_story.call(&"restart")
	await _settle()
	return true


func _check_upright() -> void:
	print("== Upright")
	var sideways: Node = root.get_node("Sideways")
	for case: Array in [[Vector2i(390, 844), true], [Vector2i(844, 390), false], [Vector2i(1280, 720), false]]:
		var upright: bool = sideways.call(&"is_upright", case[0])
		print("  %s: upright %s" % [case[0], upright])
		_expect(upright == case[1], "a %s window is %s" % [case[0], "upright" if upright else "sideways"])


func _centre(button: String) -> Vector2:
	return (_touch.call(&"rect", button) as Rect2).get_center()


# A touch and its lift at [param point] in base pixels.
func _tap(point: Vector2) -> void:
	_touch_at(0, point, true)
	await _settle()
	_touch_at(0, point, false)
	await _settle()


# Touch with finger [param index] at [param point], given in base pixels, as
# the window would report it.
func _touch_at(index: int, point: Vector2, pressed: bool) -> void:
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.index = index
	touch.position = root.get_final_transform() * point
	touch.pressed = pressed
	Input.parse_input_event(touch)


func _drag(index: int, point: Vector2) -> void:
	var drag: InputEventScreenDrag = InputEventScreenDrag.new()
	drag.index = index
	drag.position = root.get_final_transform() * point
	Input.parse_input_event(drag)


func _click(point: Vector2, device: int) -> InputEventMouseButton:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = point
	click.device = device
	return click


func _joypad_button(button: JoyButton) -> InputEventJoypadButton:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
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
		print("PASS: touch controls")
		quit(0)
		return
	for problem: String in problems:
		printerr("FAIL: " + problem)
	quit(1)


func _on_timeout() -> void:
	printerr("FAIL: timed out after %.0f seconds" % TIMEOUT_SECONDS)
	quit(2)
