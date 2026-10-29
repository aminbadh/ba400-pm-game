extends Node
## The on-screen controls for a phone: a D-pad on the lower left, Talk on the
## lower right, and small Binder and Menu buttons at the top right. Each
## presses the game's own action ([code]move_*[/code], [code]interact[/code],
## [code]binder[/code], [code]pause[/code]) while a finger is on it, so the
## walking and talking code is the same as for the keys.
##
## Nothing is made until the screen is first touched, and the controls show only
## while [Hints] says the last input was a touch, so a keyboard or a controller,
## even on a touchscreen laptop, never sees them. Each screen keeps only the
## buttons it needs: the D-pad and Talk only while the player can walk, none
## over a card, a chart, the gate or a vote, only Menu in the pause menu and on
## the last screen, and only Binder in the binder's list. The rest of a screen takes taps itself: a line, a vote
## card, a card's page, the gate's calls, a binder row, a menu item; see
## [method is_tap].
##
## Touches are read as the window gets them, before any screen can take them,
## so several fingers work at once and a finger can slide across the D-pad.


## The buttons, by name: the action each presses and the word it shows.
const BUTTONS: Dictionary[String, Dictionary] = {
	"up": { "action": &"move_up", "text": "↑" },
	"down": { "action": &"move_down", "text": "↓" },
	"left": { "action": &"move_left", "text": "←" },
	"right": { "action": &"move_right", "text": "→" },
	"talk": { "action": &"interact", "text": "Talk" },
	"binder": { "action": &"binder", "text": "Binder" },
	"menu": { "action": &"pause", "text": "Menu" },
}
const DPAD: Array[String] = ["up", "down", "left", "right"]
## Over the pause menu, the binder and the balloon, under the portrait screen.
const LAYER: int = 130
const SCREEN: Vector2 = Vector2(320, 180)
## One arm of the D-pad; the pad is three across and three down.
const DPAD_CELL: float = 16.0
## The Talk button's side.
const TALK_SIZE: float = 28.0
## The small buttons' height: a line of text on a plate.
const SMALL_HEIGHT: float = 16.0
## A touch this close to the D-pad's centre presses no direction.
const DPAD_DEAD: float = 3.0
## The bottom of the D-pad and Talk: clear of the dashboard's line at the bottom.
const LOW_BOTTOM: float = SCREEN.y - Dashboard.HINT_HEIGHT - UiStyle.EDGE
## The top of Binder and Menu: clear of the dashboard's strip on the map and
## in the pause menu. In the binder, which covers the strip, Binder sits on its
## heading's line, as tall as the line, so it stays clear of the rule under it.
const SMALL_TOP: float = Dashboard.STRIP_HEIGHT + UiStyle.EDGE
const SMALL_TOP_IN_BINDER: float = Binder.HEADING_TOP
const SMALL_HEIGHT_IN_BINDER: float = Binder.RULE_TOP - Binder.HEADING_TOP

## Each button's plate, made on the first touch.
var _plates: Dictionary[String, Panel] = {}
var _layer: CanvasLayer = null
# The button each finger is on, by touch index.
var _held: Dictionary[int, String] = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Every event reaches the window before any screen can mark it handled.
	get_tree().root.window_input.connect(notice)
	Hints.device_changed.connect(_refresh)


## True once the screen has been touched and the controls exist.
func is_made() -> bool:
	return _layer != null


## The names of the buttons on screen now.
func shown() -> Array[String]:
	var names: Array[String] = []
	for button: String in BUTTONS:
		if _plates.has(button) and _plates[button].visible:
			names.append(button)
	return names


## The screen area of button [param button], in base pixels.
func rect(button: String) -> Rect2:
	return _plates[button].get_global_rect() if _plates.has(button) else Rect2()


## True if [param event] is a tap a screen should take as its own: a press of
## the click Godot makes from a touch, anywhere but on one of these buttons.
## A real mouse's click is not one, so a laptop plays as it did.
func is_tap(event: InputEvent) -> bool:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return false
	return click.device == InputEvent.DEVICE_ID_EMULATION and _button_at(click.position).is_empty()


## Take note of a touch: a finger down on a button presses its action, lifted
## lets it go; sliding across the D-pad changes direction.
func notice(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if not touch.pressed:
			_let_go(touch.index)
			return
		# The touch that brings the buttons up does not also press one.
		var before: Array[String] = shown()
		if _layer == null:
			_make()
		_refresh()
		var button: String = _button_at(_to_base(touch.position))
		if button in before:
			_hold(touch.index, button)
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		if _held.has(drag.index) and _held[drag.index] in DPAD:
			_hold(drag.index, _dpad_at(_to_base(drag.position)))


func _process(_delta: float) -> void:
	_refresh()


# Show the buttons this screen needs, and let go of any that went.
func _refresh() -> void:
	if _layer == null:
		return
	var needed: Array[String] = _needed()
	for button: String in _plates:
		_plates[button].visible = button in needed
	var in_binder: bool = _binder_open()
	_plates.binder.position.y = SMALL_TOP_IN_BINDER if in_binder else SMALL_TOP
	_plates.binder.size.y = SMALL_HEIGHT_IN_BINDER if in_binder else SMALL_HEIGHT
	for index: int in _held.keys():
		if not _held[index] in needed:
			_let_go(index)


func _needed() -> Array[String]:
	var needed: Array[String] = []
	if not Hints.is_touch() or Sideways.is_showing() or Story.stage == null:
		return needed
	var binder: Binder = Story.binder
	if binder != null and binder.is_open():
		if binder.is_browsing():
			needed.append("binder")
		return needed
	# Paused, or at the last screen: only the way to the menu, to resume or restart.
	if get_tree().paused or Story.stage.shows_last_screen():
		needed.append("menu")
		return needed
	# Nothing over a card, a chart or the gate, or over the vote's question.
	if Story.stage.covers_screen() or Story.is_voting():
		return needed
	needed.append_array(["binder", "menu"])
	if not Story.in_scene:
		needed.append_array(DPAD)
		needed.append("talk")
	return needed


func _binder_open() -> bool:
	return Story.binder != null and Story.binder.is_open()


# The button under [param point], in base pixels; the D-pad's whole square
# counts, by the direction from its centre.
func _button_at(point: Vector2) -> String:
	if _layer == null:
		return ""
	var dpad: String = _dpad_at(point)
	if not dpad.is_empty():
		return dpad
	for button: String in _plates:
		if not button in DPAD and _plates[button].visible and _plates[button].get_global_rect().has_point(point):
			return button
	return ""


func _dpad_at(point: Vector2) -> String:
	if not _plates.up.visible or not _dpad_rect().has_point(point):
		return ""
	var from_centre: Vector2 = point - _dpad_rect().get_center()
	if from_centre.length() < DPAD_DEAD:
		return ""
	if absf(from_centre.x) > absf(from_centre.y):
		return "right" if from_centre.x > 0.0 else "left"
	return "down" if from_centre.y > 0.0 else "up"


func _dpad_rect() -> Rect2:
	var side: float = 3.0 * DPAD_CELL
	return Rect2(UiStyle.EDGE, LOW_BOTTOM - side, side, side)


# A window position, as the touch reports it, in the game's base pixels.
func _to_base(point: Vector2) -> Vector2:
	return get_tree().root.get_final_transform().affine_inverse() * point


# Put finger [param index] on [param button], letting go of what it was on.
func _hold(index: int, button: String) -> void:
	if _held.get(index, "") == button:
		return
	_let_go(index)
	if button.is_empty():
		return
	_held[index] = button
	_press(button, true)


func _let_go(index: int) -> void:
	if not _held.has(index):
		return
	var button: String = _held[index]
	_held.erase(index)
	_press(button, false)


func _press(button: String, pressed: bool) -> void:
	var press: InputEventAction = InputEventAction.new()
	press.action = BUTTONS[button].action
	press.pressed = pressed
	press.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(press)
	_dress(button, pressed)


func _dress(button: String, pressed: bool) -> void:
	var plate: Panel = _plates[button]
	plate.add_theme_stylebox_override(&"panel", UiStyle.plate(Palette.PANEL_RAISED if pressed else Palette.PANEL))
	(plate.get_child(0) as Label).add_theme_color_override(&"font_color", Palette.FOCUS if pressed else Palette.TEXT)


func _make() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = LAYER
	add_child(_layer)
	var dpad: Rect2 = _dpad_rect()
	var cell: Vector2 = Vector2(DPAD_CELL, DPAD_CELL)
	_add("up", Rect2(dpad.position + Vector2(DPAD_CELL, 0.0), cell))
	_add("left", Rect2(dpad.position + Vector2(0.0, DPAD_CELL), cell))
	_add("right", Rect2(dpad.position + Vector2(2.0 * DPAD_CELL, DPAD_CELL), cell))
	_add("down", Rect2(dpad.position + Vector2(DPAD_CELL, 2.0 * DPAD_CELL), cell))
	_add("talk", Rect2(SCREEN.x - UiStyle.EDGE - TALK_SIZE, LOW_BOTTOM - TALK_SIZE, TALK_SIZE, TALK_SIZE))
	# Menu at the right edge, Binder GAP to its left, each as wide as its word.
	var menu: Panel = _add("menu", Rect2())
	menu.size = Vector2(_width(menu), SMALL_HEIGHT)
	menu.position = Vector2(SCREEN.x - UiStyle.EDGE - menu.size.x, SMALL_TOP)
	var binder: Panel = _add("binder", Rect2())
	binder.size = Vector2(_width(binder), SMALL_HEIGHT)
	binder.position = Vector2(menu.position.x - UiStyle.GAP - binder.size.x, SMALL_TOP)


# A button's plate with its word centred; it stops the click made from a
# touch on it, so nothing under it takes the tap as well.
func _add(button: String, area: Rect2) -> Panel:
	var plate: Panel = Panel.new()
	plate.name = button.capitalize()
	plate.position = area.position
	plate.size = area.size
	plate.mouse_filter = Control.MOUSE_FILTER_STOP
	var word: Label = UiStyle.label(Palette.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	word.text = BUTTONS[button].text
	word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	word.set_anchors_preset(Control.PRESET_FULL_RECT)
	plate.add_child(word)
	_layer.add_child(plate)
	_plates[button] = plate
	_dress(button, false)
	return plate


# A small button's width: its word with PLATE_X and the outline either side.
func _width(plate: Panel) -> float:
	var word: Label = plate.get_child(0) as Label
	return word.get_minimum_size().x + 2.0 * (UiStyle.PLATE_X + UiStyle.PLATE_BORDER)
