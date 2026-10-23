class_name PauseMenu
extends CanvasLayer
## The presenter's menu, on Escape: resume, open the binder, skip to the next
## scene, or restart from the title. The game is paused while it is open.


const OPTIONS: Array[String] = ["Resume", "Binder", "Skip to next scene", "Restart to title"]
const PANEL_COLOR: Color = Color(0.06, 0.07, 0.1, 0.92)
const TEXT: Color = Color("f3efe2")
const FOCUS: Color = Color("ffd75e")
const HINT: String = "Up/Down  choose    E  select    Esc  resume"

@export var binder: Binder

var _selected: int = 0
var _labels: Array[Label] = []


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	hide()


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
	if event.is_action_pressed(&"pause"):
		_resume()
	elif event.is_action_pressed(&"move_up") or event.is_action_pressed(&"ui_up"):
		_select(_selected - 1)
	elif event.is_action_pressed(&"move_down") or event.is_action_pressed(&"ui_down"):
		_select(_selected + 1)
	elif event.is_action_pressed(&"interact"):
		_choose(_selected)


func _open() -> void:
	get_tree().paused = true
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
				binder.open()
		"Skip to next scene":
			_resume()
			Story.skip_scene()
		"Restart to title":
			hide()
			Story.restart()


func _select(index: int) -> void:
	_selected = wrapi(index, 0, OPTIONS.size())
	for i: int in _labels.size():
		_labels[i].text = ("> " if i == _selected else "  ") + OPTIONS[i]
		_labels[i].add_theme_color_override(&"font_color", FOCUS if i == _selected else TEXT)


func _build() -> void:
	var shade: ColorRect = ColorRect.new()
	shade.color = PANEL_COLOR
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var heading: Label = Label.new()
	heading.text = "Paused"
	heading.add_theme_font_size_override(&"font_size", 20)
	heading.add_theme_color_override(&"font_color", FOCUS)
	heading.position = Vector2(110, 30)
	add_child(heading)
	var column: VBoxContainer = VBoxContainer.new()
	column.position = Vector2(110, 64)
	add_child(column)
	for option: String in OPTIONS:
		var label: Label = Label.new()
		column.add_child(label)
		_labels.append(label)
	var hint: Label = Label.new()
	hint.text = HINT
	hint.add_theme_color_override(&"font_color", Color("6f7682"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(0, 160)
	hint.size = Vector2(320, 12)
	add_child(hint)
