class_name PauseMenu
extends CanvasLayer
## The presenter's menu, on Escape or the controller's Start: resume, open the
## binder, switch the sound or full screen on or off, check the controller,
## skip to the next scene, or restart from the title. The game is paused while
## it is open.
##
## The panel sits between the dashboard's strip at the top and the hint, which
## covers the dashboard's strip at the bottom in the same plate.
##
## The controller check shows the name Godot reports for each connected
## controller and, live, the last button or direction pressed, so the mapping
## can be checked on the presenting PC.


const OPTIONS: Array[String] = ["Resume", "Binder", "Sound", "Full screen", "Controller check", "Skip to next scene", "Restart to title"]
## How the Sound and Full screen options read, off and on.
const SOUND_TEXT: Array[String] = ["Sound: Off", "Sound: On"]
const FULL_SCREEN_TEXT: Array[String] = ["Full screen: Off", "Full screen: On"]
const TEXT: Color = Palette.TEXT
const FOCUS: Color = Palette.FOCUS
## The hints, filled in by [Hints] for the device used last.
const HINT: String = "{choose}  choose    {interact}  select    {resume}  resume"
const TOUCH_HINT: String = "{choose} an item    {resume}  resume"
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
## The panel's narrowest width; its height follows what it shows.
const PANEL_WIDTH: float = 176.0
const SCREEN: Vector2 = Vector2(320, 180)

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
var _hint_panel: Panel
var _checking: bool = false


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	hide()
	Hints.device_changed.connect(_refresh_hint)
	Screen.changed.connect(_on_screen_changed)
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
	elif Stick.step(event, &"move_up") or Stick.step(event, &"ui_up"):
		_select(_selected - 1)
	elif Stick.step(event, &"move_down") or Stick.step(event, &"ui_down"):
		_select(_selected + 1)
	elif event.is_action_pressed(&"interact"):
		_choose(_selected)
	elif Touch.is_tap(event):
		var item: int = tapped_item((event as InputEventMouseButton).position)
		if item >= 0:
			_select(item)
			_choose(item)


## The item under [param point], or -1 if none is.
func tapped_item(point: Vector2) -> int:
	for i: int in _labels.size():
		if _labels[i].get_global_rect().has_point(point):
			return i
	return -1


## True while the controller check is on screen.
func is_checking() -> bool:
	return visible and _checking


## What the controller check shows: the controllers' names and the last press.
func check_text() -> String:
	return "%s\n%s" % [_controller_label.text, _pressed_label.text]


## The name of what [param event] presses on a PlayStation-style controller,
## or an empty string for an event that presses nothing.
static func pressed_name(event: InputEvent) -> String:
	# The D-pad presses the stick makes for menus are not the controller's own.
	if event.has_meta(Stick.FROM_STICK):
		return ""
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
		"Full screen":
			Screen.toggle()
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
		_place()
	# Start on the controller is a press to check; Escape, the touch Menu button or a tap goes back.
	if event.is_action_pressed(&"back") or ((event is InputEventKey or event is InputEventAction) and event.is_action_pressed(&"pause")) or Touch.is_tap(event):
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


# F11 or Alt+Enter while the menu is open changes what its item reads.
func _on_screen_changed() -> void:
	_select(_selected)


## How option [param index] reads now.
func option_text(index: int) -> String:
	match OPTIONS[index]:
		"Sound":
			return SOUND_TEXT[int(Story.sound_on)]
		"Full screen":
			return FULL_SCREEN_TEXT[int(Screen.is_full_screen())]
	return OPTIONS[index]


func _select(index: int) -> void:
	_selected = wrapi(index, 0, OPTIONS.size())
	for i: int in _labels.size():
		var option: String = option_text(i)
		_labels[i].text = ("> " if i == _selected else "  ") + option
		_labels[i].add_theme_color_override(&"font_color", FOCUS if i == _selected else TEXT)
		_labels[i].add_theme_stylebox_override(&"normal", UiStyle.flat(Palette.PANEL_RAISED if i == _selected else Palette.PANEL))


func _refresh_hint() -> void:
	_hint.text = Hints.text(CHECK_HINT) if _checking else Hints.text(HINT, TOUCH_HINT)


# The menu's panel, centred across the screen and in the room between the
# strip at the top and the hint at the bottom. The controller check's lines
# widen it up to the screen's width, then wrap.
func _place() -> void:
	var inner_widest: float = SCREEN.x - 2 * (UiStyle.EDGE + UiStyle.FRAME_MARGIN + UiStyle.INSET)
	for label: Label in [_controller_label, _pressed_label]:
		var font: Font = label.get_theme_font(&"font")
		var font_size: int = label.get_theme_font_size(&"font_size")
		var widest: float = 0.0
		for line: String in label.text.split("\n"):
			widest = maxf(widest, ceilf(font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x))
		label.custom_minimum_size.x = minf(widest, inner_widest)
		# A wrapping label's height follows its width, which the panel sets only later.
		label.size.x = label.custom_minimum_size.x
		label.update_minimum_size()
	_panel.reset_size()
	var panel_size: Vector2 = _panel.get_combined_minimum_size()
	var room_top: float = Dashboard.STRIP_HEIGHT + UiStyle.EDGE
	var room_bottom: float = SCREEN.y - Dashboard.HINT_HEIGHT - UiStyle.GAP
	_panel.position = (Vector2(SCREEN.x - panel_size.x, room_top + room_bottom - panel_size.y) / 2.0).floor()


# A label that wraps once [method _place] has made it as wide as it may be.
func _wrapping_label(color: Color) -> Label:
	var made: Label = UiStyle.label(color)
	made.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return made


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override(&"panel", UiStyle.frame())
	_panel.custom_minimum_size.x = PANEL_WIDTH
	add_child(_panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", UiStyle.GAP)
	_panel.add_child(column)
	# The title at the font's base size, as the binder's heading.
	_heading = UiStyle.label(FOCUS, HORIZONTAL_ALIGNMENT_CENTER)
	column.add_child(_heading)
	_items = VBoxContainer.new()
	_items.add_theme_constant_override(&"separation", 0)  # spacing: pending; seven items with TIGHT do not fit between the strip and the hint
	column.add_child(_items)
	for option: String in OPTIONS:
		var label: Label = UiStyle.label()
		_items.add_child(label)
		_labels.append(label)
	_check = VBoxContainer.new()
	_check.add_theme_constant_override(&"separation", UiStyle.GAP)
	_check.hide()
	column.add_child(_check)
	# A long controller name wraps inside the panel rather than widen it.
	_controller_label = _wrapping_label(TEXT)
	_check.add_child(_controller_label)
	_pressed_label = _wrapping_label(FOCUS)
	_check.add_child(_pressed_label)

	# The hint, in a plate over the dashboard's strip at the bottom, as wide
	# as the screen with its line centred, as the dashboard's own.
	_hint_panel = Panel.new()
	_hint_panel.add_theme_stylebox_override(&"panel", UiStyle.plate())
	_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_panel.anchor_left = 0.0
	_hint_panel.anchor_right = 1.0
	_hint_panel.anchor_top = 1.0
	_hint_panel.anchor_bottom = 1.0
	_hint_panel.offset_top = -Dashboard.HINT_HEIGHT
	add_child(_hint_panel)
	_hint = UiStyle.label(Palette.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hint_panel.add_child(_hint)

	# The options' text sets the panel's size.
	_heading.text = "Paused"
	_refresh_hint()
	_select(0)
	_place()
