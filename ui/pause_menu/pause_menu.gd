class_name PauseMenu
extends CanvasLayer
## The presenter's menu, on Escape or the controller's Start: resume, open the
## binder, switch the sound on or off, check the controller, skip to the next
## scene, or restart from the title. The game is paused while it is open.
##
## The controller check shows the name Godot reports for each connected
## controller and, live, the last button or direction pressed, so the mapping
## can be checked on the presenting PC.


const OPTIONS: Array[String] = ["Resume", "Binder", "Sound", "Controller check", "Skip to next scene", "Restart to title"]
## How the Sound option reads, with the sound off and on.
const SOUND_TEXT: Array[String] = ["Sound: Off", "Sound: On"]
const TEXT: Color = Palette.TEXT
const FOCUS: Color = Palette.FOCUS
## The hints, filled in by [Hints] for the device used last.
const HINT: String = "{choose}  choose    {interact}  select    {resume}  resume"
const CHECK_HINT: String = "Press any button or direction    {back}  back"
const CHECK_HEADING: String = "Controller check"
const NO_CONTROLLER: String = "No controller connected"
const NOTHING_PRESSED: String = "Pressed: nothing yet"
const PRESSED: String = "Pressed: %s"
## The buttons of a PlayStation-style controller, by Godot's standard joypad
## button index, which SDL's mapping gives every controller.
const BUTTON_NAMES: Dictionary[int, String] = {
	JOY_BUTTON_A: "Cross ✕",
	JOY_BUTTON_B: "Circle ○",
	JOY_BUTTON_X: "Square □",
	JOY_BUTTON_Y: "Triangle △",
	JOY_BUTTON_BACK: "Select",
	JOY_BUTTON_GUIDE: "PS button",
	JOY_BUTTON_START: "Start",
	JOY_BUTTON_LEFT_STICK: "L3",
	JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_LEFT_SHOULDER: "L1",
	JOY_BUTTON_RIGHT_SHOULDER: "R1",
	JOY_BUTTON_DPAD_UP: "D-pad up",
	JOY_BUTTON_DPAD_DOWN: "D-pad down",
	JOY_BUTTON_DPAD_LEFT: "D-pad left",
	JOY_BUTTON_DPAD_RIGHT: "D-pad right",
}
## The sticks and triggers, by Godot's standard joypad axis index.
const AXIS_NAMES: Dictionary[int, Array] = {
	JOY_AXIS_LEFT_X: ["Left stick left", "Left stick right"],
	JOY_AXIS_LEFT_Y: ["Left stick up", "Left stick down"],
	JOY_AXIS_RIGHT_X: ["Right stick left", "Right stick right"],
	JOY_AXIS_RIGHT_Y: ["Right stick up", "Right stick down"],
	JOY_AXIS_TRIGGER_LEFT: ["L2", "L2"],
	JOY_AXIS_TRIGGER_RIGHT: ["R2", "R2"],
}
const PANEL_SIZE: Vector2 = Vector2(176, 124)
const SCREEN: Vector2 = Vector2(320, 180)
const HEADING_SIZE: int = 20

@export var binder: Binder

var _selected: int = 0
var _labels: Array[Label] = []
var _panel: PanelContainer
var _heading: Label
var _items: VBoxContainer
var _check: VBoxContainer
var _controller_label: Label
var _pressed_label: Label
var _hint: Label
var _hint_panel: PanelContainer
var _checking: bool = false


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	hide()
	Hints.device_changed.connect(_refresh_hint)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


func _input(event: InputEvent) -> void:
	if binder != null and binder.is_open():
		return
	if not visible:
		if event.is_action_pressed(&"pause") and not get_tree().paused:
			get_viewport().set_input_as_handled()
			_open()
		return
	if event is InputEventMouseMotion:
		return
	get_viewport().set_input_as_handled()
	if _checking:
		_check_input(event)
	elif event.is_action_pressed(&"pause") or event.is_action_pressed(&"back"):
		_resume()
	elif event.is_action_pressed(&"move_up") or event.is_action_pressed(&"ui_up"):
		_select(_selected - 1)
	elif event.is_action_pressed(&"move_down") or event.is_action_pressed(&"ui_down"):
		_select(_selected + 1)
	elif event.is_action_pressed(&"interact"):
		_choose(_selected)


## True while the controller check is on screen.
func is_checking() -> bool:
	return visible and _checking


## What the controller check shows: the controllers' names and the last press.
func check_text() -> String:
	return "%s\n%s" % [_controller_label.text, _pressed_label.text]


## The name of what [param event] presses on a PlayStation-style controller,
## or an empty string for an event that presses nothing.
static func pressed_name(event: InputEvent) -> String:
	if event is InputEventJoypadButton and event.is_pressed():
		var button: int = (event as InputEventJoypadButton).button_index
		return "%s (button %d)" % [BUTTON_NAMES.get(button, "Button"), button]
	if event is InputEventJoypadMotion:
		var motion: InputEventJoypadMotion = event as InputEventJoypadMotion
		if absf(motion.axis_value) < Hints.STICK_THRESHOLD:
			return ""
		var names: Array = AXIS_NAMES.get(motion.axis, ["Axis", "Axis"])
		return "%s (axis %d)" % [names[int(motion.axis_value > 0.0)], motion.axis]
	return ""


func _open() -> void:
	get_tree().paused = true
	_show_menu()
	_select(0)
	show()


func _resume() -> void:
	hide()
	get_tree().paused = false


func _choose(index: int) -> void:
	match OPTIONS[index]:
		"Resume":
			_resume()
		"Binder":
			if binder != null:
				hide()
				binder.open()
				await binder.closed
				show()
		"Sound":
			Story.sound_on = not Story.sound_on
			_select(index)
		"Controller check":
			_show_check()
		"Skip to next scene":
			_resume()
			Story.skip_scene()
		"Restart to title":
			hide()
			Story.restart()


# In the check, every press shows; the circle or Escape goes back to the menu.
func _check_input(event: InputEvent) -> void:
	var pressed: String = pressed_name(event)
	if not pressed.is_empty():
		_pressed_label.text = PRESSED % pressed
	if event.is_action_pressed(&"back") or (event is InputEventKey and event.is_action_pressed(&"pause")):
		_show_menu()


func _show_check() -> void:
	_checking = true
	_items.hide()
	_heading.text = CHECK_HEADING
	_controller_label.text = _controller_names()
	_pressed_label.text = NOTHING_PRESSED
	_check.show()
	_refresh_hint()
	_place()


func _show_menu() -> void:
	_checking = false
	_check.hide()
	_heading.text = "Paused"
	_items.show()
	_refresh_hint()
	_place()


func _controller_names() -> String:
	var pads: Array[int] = Input.get_connected_joypads()
	if pads.is_empty():
		return NO_CONTROLLER
	var names: PackedStringArray = []
	for device: int in pads:
		names.append("%d: %s" % [device, Input.get_joy_name(device)])
	return "\n".join(names)


func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	if _checking:
		_controller_label.text = _controller_names()
		_place()


func _select(index: int) -> void:
	_selected = wrapi(index, 0, OPTIONS.size())
	for i: int in _labels.size():
		var option: String = SOUND_TEXT[int(Story.sound_on)] if OPTIONS[i] == "Sound" else OPTIONS[i]
		_labels[i].text = ("> " if i == _selected else "  ") + option
		_labels[i].add_theme_color_override(&"font_color", FOCUS if i == _selected else TEXT)
		_labels[i].add_theme_stylebox_override(&"normal", UiStyle.flat(Palette.PANEL_RAISED if i == _selected else Palette.PANEL))


func _refresh_hint() -> void:
	_hint.text = Hints.text(CHECK_HINT if _checking else HINT)


# The menu's panel, centred in the room above the hint bar at the bottom.
func _place() -> void:
	_panel.reset_size()
	_hint_panel.reset_size()
	var panel_size: Vector2 = _panel.get_combined_minimum_size()
	var room_bottom: float = SCREEN.y - UiStyle.EDGE - _hint_panel.get_combined_minimum_size().y - UiStyle.GAP
	_panel.position = (Vector2(SCREEN.x - panel_size.x, UiStyle.EDGE + room_bottom - panel_size.y) / 2.0).floor()


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override(&"panel", UiStyle.frame())
	_panel.custom_minimum_size = PANEL_SIZE
	add_child(_panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", UiStyle.GAP)
	_panel.add_child(column)
	_heading = UiStyle.label(FOCUS, HORIZONTAL_ALIGNMENT_CENTER)
	_heading.add_theme_font_size_override(&"font_size", HEADING_SIZE)
	column.add_child(_heading)
	_items = VBoxContainer.new()
	_items.add_theme_constant_override(&"separation", UiStyle.TIGHT)
	column.add_child(_items)
	for option: String in OPTIONS:
		var label: Label = UiStyle.label()
		_items.add_child(label)
		_labels.append(label)
	_check = VBoxContainer.new()
	_check.add_theme_constant_override(&"separation", UiStyle.GAP)
	_check.hide()
	column.add_child(_check)
	_controller_label = UiStyle.label()
	_check.add_child(_controller_label)
	_pressed_label = UiStyle.label(FOCUS)
	_check.add_child(_pressed_label)

	_hint_panel = PanelContainer.new()
	_hint_panel.add_theme_stylebox_override(&"panel", UiStyle.frame())
	_hint_panel.anchor_left = 0.5
	_hint_panel.anchor_right = 0.5
	_hint_panel.anchor_top = 1.0
	_hint_panel.anchor_bottom = 1.0
	_hint_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint_panel.offset_bottom = -UiStyle.EDGE
	add_child(_hint_panel)
	_hint = UiStyle.label(Palette.DIM)
	_hint_panel.add_child(_hint)

	# The options' text sets the panel's size.
	_heading.text = "Paused"
	_refresh_hint()
	_select(0)
	_place()
