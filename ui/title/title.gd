extends Control
## The title screen: start the story in Full mode (about 30 minutes) or Short
## mode (about 20). Press 1 or 2, or choose with Up/Down and E. The picture
## behind is drawn by tools/build_map.py.


@onready var _full: Button = %Full
@onready var _short: Button = %Short


func _ready() -> void:
	_style()
	_full.pressed.connect(Story.new_game.bind(false))
	_short.pressed.connect(Story.new_game.bind(true))
	_full.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"choice_1"):
		get_viewport().set_input_as_handled()
		Story.new_game(false)
	elif event.is_action_pressed(&"choice_2"):
		get_viewport().set_input_as_handled()
		Story.new_game(true)
	elif event.is_action_pressed(&"interact"):
		var focused: Control = get_viewport().gui_get_focus_owner()
		if focused is Button:
			get_viewport().set_input_as_handled()
			(focused as Button).pressed.emit()
	elif event.is_action_pressed(&"move_up") or event.is_action_pressed(&"move_down"):
		get_viewport().set_input_as_handled()
		(_short if _full.has_focus() else _full).grab_focus()


# The frame, the spacing and the palette's colours on every part of the screen.
# The keys sit EDGE above the screen's bottom, the panel GAP above them.
func _style() -> void:
	var panel: Control = %Panel
	var keys: Control = %KeysPanel
	panel.add_theme_stylebox_override(&"panel", UiStyle.frame())
	keys.add_theme_stylebox_override(&"panel", UiStyle.frame())
	(%Column as Control).add_theme_constant_override(&"separation", UiStyle.GAP)
	(%Buttons as Control).add_theme_constant_override(&"separation", UiStyle.TIGHT)
	keys.offset_bottom = -UiStyle.EDGE
	panel.offset_bottom = -(UiStyle.EDGE + keys.get_combined_minimum_size().y + UiStyle.GAP)
	(%Heading as Label).add_theme_color_override(&"font_color", Palette.FOCUS)
	(%Subtitle as Label).add_theme_color_override(&"font_color", Palette.TEXT)
	(%Keys as Label).add_theme_color_override(&"font_color", Palette.DIM)
	for button: Button in [_full, _short]:
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
			button.add_theme_stylebox_override(state, normal)
		for state: StringName in [&"focus", &"pressed", &"hover_pressed"]:
			button.add_theme_stylebox_override(state, focus)
		button.add_theme_color_override(&"font_color", Palette.TEXT)
		button.add_theme_color_override(&"font_hover_color", Palette.TEXT)
		button.add_theme_color_override(&"font_focus_color", Palette.FOCUS)
		button.add_theme_color_override(&"font_pressed_color", Palette.FOCUS)
		button.add_theme_color_override(&"font_hover_pressed_color", Palette.FOCUS)
