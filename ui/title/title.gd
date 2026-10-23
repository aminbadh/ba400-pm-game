extends Control
## The title screen: start the story in Full mode (about 30 minutes) or Short
## mode (about 20). Press 1 or 2, or choose with Up/Down and E.


@onready var _full: Button = %Full
@onready var _short: Button = %Short


func _ready() -> void:
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
