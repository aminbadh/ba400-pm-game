class_name PauseMenu
extends CanvasLayer
## The presenter's menu, on Escape: resume, open the binder, switch the
## characters' voices on or off, skip to the next scene, or restart from the
## title. The game is paused while it is open.


const OPTIONS: Array[String] = ["Resume", "Binder", "Voices", "Skip to next scene", "Restart to title"]
## How the Voices option reads, with the voices off and on.
const VOICES_TEXT: Array[String] = ["Voices: off", "Voices: on"]
const TEXT: Color = Palette.TEXT
const FOCUS: Color = Palette.FOCUS
const HINT: String = "Up/Down  choose    E  select    Esc  resume"
const PANEL_SIZE: Vector2 = Vector2(176, 124)

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
				hide()
				binder.open()
				await binder.closed
				show()
		"Voices":
			Story.voice_blips = not Story.voice_blips
			_select(index)
		"Skip to next scene":
			_resume()
			Story.skip_scene()
		"Restart to title":
			hide()
			Story.restart()


func _select(index: int) -> void:
	_selected = wrapi(index, 0, OPTIONS.size())
	for i: int in _labels.size():
		var option: String = VOICES_TEXT[int(Story.voice_blips)] if OPTIONS[i] == "Voices" else OPTIONS[i]
		_labels[i].text = ("> " if i == _selected else "  ") + option
		_labels[i].add_theme_color_override(&"font_color", FOCUS if i == _selected else TEXT)
		_labels[i].add_theme_stylebox_override(&"normal", UiStyle.flat(Palette.PANEL_RAISED if i == _selected else Palette.PANEL))


func _build() -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", UiStyle.frame(4))
	panel.custom_minimum_size = PANEL_SIZE
	panel.position = ((Vector2(320, 180) - PANEL_SIZE) / 2.0).round()
	add_child(panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 1)
	panel.add_child(column)
	var heading: Label = UiStyle.label(FOCUS, HORIZONTAL_ALIGNMENT_CENTER)
	heading.text = "Paused"
	heading.add_theme_font_size_override(&"font_size", 20)
	column.add_child(heading)
	for option: String in OPTIONS:
		var label: Label = UiStyle.label()
		column.add_child(label)
		_labels.append(label)
	var hint_panel: PanelContainer = PanelContainer.new()
	hint_panel.add_theme_stylebox_override(&"panel", UiStyle.frame(0))
	hint_panel.anchor_left = 0.5
	hint_panel.anchor_right = 0.5
	hint_panel.anchor_top = 1.0
	hint_panel.anchor_bottom = 1.0
	hint_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint_panel.offset_bottom = -4
	add_child(hint_panel)
	var hint: Label = UiStyle.label(Palette.DIM)
	hint.text = HINT
	hint_panel.add_child(hint)
