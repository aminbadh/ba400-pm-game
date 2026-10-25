extends Control
## The title screen: one prompt to start the story, with E or the
## controller's cross button, or a click. The keys below it follow the device
## used last. The picture behind is drawn by tools/build_map.py.


## The prompt and the keys, filled in by [Hints] for the device used last.
const START_HINT: String = "{interact}  Start"
const KEYS_HINT: String = "Move {move}   Talk {interact}   Binder {open_binder}   Menu {menu}"

@onready var _start: Button = %Start


func _ready() -> void:
	_style()
	_refresh_hints()
	Hints.device_changed.connect(_refresh_hints)
	_start.pressed.connect(Story.new_game)
	_start.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"interact"):
		get_viewport().set_input_as_handled()
		Story.new_game()


func _refresh_hints() -> void:
	_start.text = Hints.text(START_HINT)
	(%Keys as Label).text = Hints.text(KEYS_HINT)
	_place()


# The keys sit EDGE above the screen's bottom, the panel GAP above them.
func _place() -> void:
	var panel: Control = %Panel
	var keys: Control = %KeysPanel
	keys.offset_bottom = -UiStyle.EDGE
	panel.offset_bottom = -(UiStyle.EDGE + keys.get_combined_minimum_size().y + UiStyle.GAP)


# The frame, the spacing and the palette's colours on every part of the screen.
func _style() -> void:
	var panel: Control = %Panel
	var keys: Control = %KeysPanel
	panel.add_theme_stylebox_override(&"panel", UiStyle.frame())
	keys.add_theme_stylebox_override(&"panel", UiStyle.frame())
	(%Column as Control).add_theme_constant_override(&"separation", UiStyle.GAP)
	(%Heading as Label).add_theme_color_override(&"font_color", Palette.FOCUS)
	(%Subtitle as Label).add_theme_color_override(&"font_color", Palette.TEXT)
	(%Keys as Label).add_theme_color_override(&"font_color", Palette.DIM)
	var normal: StyleBoxFlat = UiStyle.flat(Palette.PANEL)
	normal.border_color = Palette.DIM
	normal.set_border_width_all(1)
	normal.content_margin_left = UiStyle.INSET
	normal.content_margin_right = UiStyle.INSET
	normal.content_margin_top = UiStyle.TIGHT
	normal.content_margin_bottom = UiStyle.TIGHT
	var focus: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	focus.bg_color = Palette.PANEL_RAISED
	focus.border_color = Palette.FOCUS
	for state: StringName in [&"normal", &"hover", &"disabled"]:
		_start.add_theme_stylebox_override(state, normal)
	for state: StringName in [&"focus", &"pressed", &"hover_pressed"]:
		_start.add_theme_stylebox_override(state, focus)
	_start.add_theme_color_override(&"font_color", Palette.TEXT)
	_start.add_theme_color_override(&"font_hover_color", Palette.TEXT)
	_start.add_theme_color_override(&"font_focus_color", Palette.FOCUS)
	_start.add_theme_color_override(&"font_pressed_color", Palette.FOCUS)
	_start.add_theme_color_override(&"font_hover_pressed_color", Palette.FOCUS)
