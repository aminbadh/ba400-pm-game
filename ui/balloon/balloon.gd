class_name Balloon
extends CanvasLayer
## The game's dialogue balloon, based on the Dialogue Manager example balloon.
## It labels the response options A, B, C so the audience can vote with cards;
## dialogue writers never type the letters themselves.


## Letters shown in front of the response options, in order.
const CHOICE_LETTERS: PackedStringArray = ["A", "B", "C", "D", "E", "F"]
## Input actions that pick the first, second and third response directly.
const CHOICE_ACTIONS: Array[StringName] = [&"choice_1", &"choice_2", &"choice_3"]

## The dialogue resource to show.
@export var dialogue_resource: DialogueResource
## The cue to start from when the balloon starts itself.
@export var start_from_cue: String = ""
## Start on [method Node._ready] instead of waiting for [method start].
@export var auto_start: bool = false
## Swallow all other input while the balloon is open.
@export var will_block_other_input: bool = true
## The action that advances to the next line or picks the focused response.
@export var next_action: StringName = &"interact"
## The action that finishes the typing animation at once.
@export var skip_action: StringName = &"interact"

## Extra objects the dialogue can read state from, besides the autoloads.
var temporary_game_states: Array = []
## True when the current line is fully shown and waits for the player.
var is_waiting_for_input: bool = false
## True while a long mutation runs and the balloon should hide.
var will_hide_balloon: bool = false

## The line currently shown. Setting it to null closes the balloon.
var dialogue_line: DialogueLine:
	set(value):
		if value:
			dialogue_line = value
			apply_dialogue_line()
		else:
			# The dialogue has finished, so close the balloon.
			if owner == null:
				queue_free()
			else:
				hide()
	get:
		return dialogue_line

## Delays hiding the balloon during a mutation, so quick mutations do not flicker.
var mutation_cooldown: Timer = Timer.new()

@onready var balloon: Control = %Balloon
@onready var character_label: RichTextLabel = %CharacterLabel
@onready var dialogue_label: DialogueLabel = %DialogueLabel
@onready var responses_menu: DialogueResponsesMenu = %ResponsesMenu
@onready var progress: Polygon2D = %Progress


func _ready() -> void:
	balloon.hide()
	DialogueManager.mutated.connect(_on_mutated)

	if responses_menu.next_action.is_empty():
		responses_menu.next_action = next_action

	mutation_cooldown.timeout.connect(_on_mutation_cooldown_timeout)
	add_child(mutation_cooldown)

	if auto_start:
		assert(is_instance_valid(dialogue_resource), DMConstants.get_error_message(DMConstants.ERR_MISSING_RESOURCE_FOR_AUTOSTART))
		start()


func _process(_delta: float) -> void:
	if is_instance_valid(dialogue_line):
		progress.visible = not dialogue_label.is_typing and dialogue_line.responses.size() == 0


func _unhandled_input(event: InputEvent) -> void:
	if responses_menu.visible:
		_handle_response_shortcuts(event)

	# Only the balloon is allowed to handle input while it is showing.
	if will_block_other_input:
		get_viewport().set_input_as_handled()


## Start some dialogue.
func start(with_dialogue_resource: DialogueResource = null, cue: String = "", extra_game_states: Array = []) -> void:
	temporary_game_states = [self] + extra_game_states
	is_waiting_for_input = false
	if is_instance_valid(with_dialogue_resource):
		dialogue_resource = with_dialogue_resource
	if not cue.is_empty():
		start_from_cue = cue
	dialogue_line = await dialogue_resource.get_next_dialogue_line(start_from_cue, temporary_game_states)
	show()


## Show a new [DialogueLine].
func apply_dialogue_line() -> void:
	mutation_cooldown.stop()

	progress.hide()
	is_waiting_for_input = false
	balloon.focus_mode = Control.FOCUS_ALL
	balloon.grab_focus()

	character_label.visible = not dialogue_line.character.is_empty()
	character_label.text = tr(dialogue_line.character, "dialogue")

	dialogue_label.hide()
	dialogue_label.dialogue_line = dialogue_line

	responses_menu.hide()
	responses_menu.responses = dialogue_line.responses
	_label_responses()

	balloon.show()
	will_hide_balloon = false

	dialogue_label.show()
	if not dialogue_line.text.is_empty():
		dialogue_label.type_out()
		await dialogue_label.finished_typing

	if dialogue_line.responses.size() > 0:
		balloon.focus_mode = Control.FOCUS_NONE
		responses_menu.show()
	elif dialogue_line.time != "":
		var time: float = dialogue_line.text.length() * 0.02 if dialogue_line.time == "auto" else dialogue_line.time.to_float()
		await get_tree().create_timer(time).timeout
		next(dialogue_line.next_id)
	else:
		is_waiting_for_input = true
		balloon.focus_mode = Control.FOCUS_ALL
		balloon.grab_focus()


## Go to the next line.
func next(next_id: String) -> void:
	dialogue_line = await dialogue_resource.get_next_dialogue_line(next_id, temporary_game_states)


# The response buttons, in the order shown, without the hidden template.
func _response_items() -> Array[Button]:
	var items: Array[Button] = []
	for child: Node in responses_menu.get_children():
		if child != responses_menu.response_template:
			items.append(child as Button)
	return items


# Put A, B, C... in front of each response option.
func _label_responses() -> void:
	var items: Array[Button] = _response_items()
	for i: int in mini(items.size(), CHOICE_LETTERS.size()):
		items[i].text = "%s   %s" % [CHOICE_LETTERS[i], items[i].text]


# Number keys pick a response directly; up and down on WASD move the focus,
# since the arrow keys already do that through the buttons' own focus handling.
func _handle_response_shortcuts(event: InputEvent) -> void:
	var items: Array[Button] = _response_items()
	for i: int in mini(items.size(), CHOICE_ACTIONS.size()):
		if event.is_action_pressed(CHOICE_ACTIONS[i]) and not items[i].disabled:
			_on_responses_menu_response_selected(items[i].get_meta("response") as DialogueResponse)
			return

	var step: int = 0
	if event.is_action_pressed(&"move_up"):
		step = -1
	elif event.is_action_pressed(&"move_down"):
		step = 1
	if step == 0:
		return

	var enabled: Array[Button] = []
	for item: Button in items:
		if not item.disabled:
			enabled.append(item)
	if enabled.is_empty():
		return
	var focused: int = enabled.find(get_viewport().gui_get_focus_owner())
	enabled[clampi(focused + step, 0, enabled.size() - 1)].grab_focus()


#region Signals


func _on_mutation_cooldown_timeout() -> void:
	if will_hide_balloon:
		will_hide_balloon = false
		balloon.hide()


func _on_mutated(mutation: Dictionary) -> void:
	if not mutation.is_inline:
		is_waiting_for_input = false
		will_hide_balloon = true
		mutation_cooldown.start(0.1)


func _on_balloon_gui_input(event: InputEvent) -> void:
	# Skip the typing animation.
	if dialogue_label.is_typing:
		var mouse_was_clicked: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed()
		if mouse_was_clicked or event.is_action_pressed(skip_action):
			get_viewport().set_input_as_handled()
			dialogue_label.skip_typing()
			return

	if not is_waiting_for_input: return
	if dialogue_line.responses.size() > 0: return

	# When there are no response options the balloon itself is the clickable thing.
	get_viewport().set_input_as_handled()

	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		next(dialogue_line.next_id)
	elif event.is_action_pressed(next_action) and get_viewport().gui_get_focus_owner() == balloon:
		next(dialogue_line.next_id)


func _on_responses_menu_response_selected(response: DialogueResponse) -> void:
	next(response.next_id)


#endregion
