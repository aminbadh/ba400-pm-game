class_name Balloon
extends CanvasLayer
## The game's dialogue balloon, based on the Dialogue Manager example balloon.
##
## A line shows in a pixel-framed box at the bottom: the speaker's portrait on
## the left in the expression the line's tag asks for ([#worried], [#pleased];
## neutral otherwise), a name plate in the speaker's colour on the frame, and
## the text typed out at most [constant LINES_PER_PAGE] lines at a time. A press
## while typing shows the whole page; the next press goes on to the next page or
## line. Lines with no speaker are narration: no portrait, no plate. With
## [member Story.voice_blips] on, the speaker's voice plays while a line types.
##
## A vote shows the question at the top and the options as the room's cards
## below it, A blue, B orange, C green, with the 20-second bar under them; it is
## not typed. The bar turns red at the end and never picks for the presenter.
## Once an option is picked, "The room chose B" shows for
## [constant CHOSEN_SECONDS] before the story goes on.


## Letters shown in front of the response options, in order.
const CHOICE_LETTERS: PackedStringArray = ["A", "B", "C", "D", "E", "F"]
## Input actions that pick the first, second and third response directly.
const CHOICE_ACTIONS: Array[StringName] = [&"choice_1", &"choice_2", &"choice_3"]
## How long the vote bar takes to fill.
const VOTE_SECONDS: float = 20.0
## Picks made sooner than this after the options appear are ignored, so the
## press that finished the line before cannot cast a vote by accident.
const VOTE_GUARD_SECONDS: float = 0.5
## How long "The room chose B" stays before the consequence.
const CHOSEN_SECONDS: float = 1.5
const CHOSEN_TEXT: String = "The room chose %s"
## The most lines a box shows at once; longer lines page.
const LINES_PER_PAGE: int = 3
## Each character's voice, from the Ninja Adventure pack.
const VOICES: Dictionary[String, String] = {
	"jlassi": "res://art/ninja_adventure/Audio/Sounds/Voice/Voice1.wav",
	"kchaou": "res://art/ninja_adventure/Audio/Sounds/Voice/Voice2.wav",
	"salma": "res://art/ninja_adventure/Audio/Sounds/Voice/Voice3.wav",
	"hedi": "res://art/ninja_adventure/Audio/Sounds/Voice/Voice4.wav",
	"aziz": "res://art/ninja_adventure/Audio/Sounds/Voice/Voice5.wav",
	"fethi": "res://art/ninja_adventure/Audio/Sounds/Voice/Voice6.wav",
	"nour": "res://art/ninja_adventure/Audio/Sounds/Voice/Voice7.wav",
	"lassaad": "res://art/ninja_adventure/Audio/Sounds/Voice/Voice8.wav",
}
const RESPONSES_MENU_SCRIPT: Script = preload("res://addons/dialogue_manager/nodes/responses_menu/dialogue_responses_menu.gd")
## The layout, in base pixels. Spacing comes from [UiStyle].
const SCREEN: Vector2 = Vector2(320, 180)
const BOX_HEIGHT: float = 58.0
## The portrait drawn in the box, inside its 1 px outline.
const PORTRAIT_SHOWN: float = 46.0
## The height of a line of text in the game's font.
const LINE_HEIGHT: float = 14.0
## The speaker's name plate: a line of text with [constant UiStyle.PLATE_Y] above and below.
const NAME_PLATE_HEIGHT: float = LINE_HEIGHT + 2.0 * UiStyle.PLATE_Y
## The triangle in the box's corner that says the page waits for a press.
const PROGRESS_SIZE: Vector2 = Vector2(6, 3)
## A vote card: its coloured border, its height on one line of text, and the
## letter tile at its left end.
const CARD_BORDER: int = VoteLetter.BORDER
const CARD_HEIGHT: float = 26.0
const CARD_LETTER_WIDTH: float = VoteLetter.WIDTH
const BAR_HEIGHT: float = 5.0
## The top of the speaker's name plate, centred on the box's top edge.
const NAME_PLATE_TOP: float = SCREEN.y - UiStyle.EDGE - BOX_HEIGHT - NAME_PLATE_HEIGHT / 2.0

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
## True when the current page is fully shown and waits for the player.
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

# The current line's pages, and the one shown.
var _pages: PackedStringArray = []
var _page: int = 0
# Seconds the current vote has been on screen.
var _vote_elapsed: float = 0.0
## Whether the presenter has pointed at a card yet. Until then the focus the
## menu puts on the first card is not drawn, so no option looks chosen.
var _vote_pointed: bool = false
# Holds "The room chose B" on screen; a child, so it dies with the balloon.
var _chosen_timer: Timer = Timer.new()
var _chosen_response: DialogueResponse = null

var _box: PanelContainer
var _portrait_back: PanelContainer
var _portrait: TextureRect
var _name_plate: Label
var _progress: Polygon2D
var _vote: VBoxContainer
var _question_name: Label
var _question: Label
var _vote_track: ColorRect
var _vote_fill: ColorRect
var _chosen_label: Label
var _voice: AudioStreamPlayer

@onready var balloon: Control = %Balloon
var dialogue_label: PagedLabel
var responses_menu: DialogueResponsesMenu


func _ready() -> void:
	_build()
	balloon.hide()
	DialogueManager.mutated.connect(_on_mutated)
	responses_menu.next_action = next_action

	mutation_cooldown.timeout.connect(_on_mutation_cooldown_timeout)
	add_child(mutation_cooldown)

	_chosen_timer.one_shot = true
	_chosen_timer.timeout.connect(_on_chosen_timer_timeout)
	add_child(_chosen_timer)

	if auto_start:
		assert(is_instance_valid(dialogue_resource), DMConstants.get_error_message(DMConstants.ERR_MISSING_RESOURCE_FOR_AUTOSTART))
		start()


func _process(delta: float) -> void:
	_progress.visible = is_waiting_for_input and _box.visible
	if responses_menu.visible:
		_vote_elapsed += delta
		var share: float = minf(_vote_elapsed / VOTE_SECONDS, 1.0)
		_vote_fill.size = Vector2(roundf(_vote_track.size.x * share), _vote_track.size.y)
		_vote_fill.color = Palette.VOTE_OVER if share >= 1.0 else Palette.VOTE_BAR


# Before the cards take it: the first arrow key, or E on the undrawn focus,
# only shows the focus. The arrow keys go on to move it as usual.
func _input(event: InputEvent) -> void:
	if not responses_menu.visible or _vote_pointed:
		return
	for action: StringName in [&"ui_up", &"ui_down", &"ui_left", &"ui_right", &"move_up", &"move_down"]:
		if event.is_action_pressed(action):
			_show_vote_focus()
			return
	if event.is_action_pressed(next_action) or event.is_action_pressed(&"ui_accept"):
		get_viewport().set_input_as_handled()
		_show_vote_focus()


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


## Show a new [DialogueLine]: a vote if it has responses, otherwise its first page.
func apply_dialogue_line() -> void:
	mutation_cooldown.stop()
	is_waiting_for_input = false
	balloon.focus_mode = Control.FOCUS_ALL
	balloon.grab_focus()
	balloon.show()
	will_hide_balloon = false

	responses_menu.hide()
	if dialogue_line.responses.size() > 0:
		_show_vote()
		return

	_vote.hide()
	_show_speaker()
	_pages = dialogue_line_pages()
	_page = 0
	dialogue_label.page_text = _pages[0]
	dialogue_label.dialogue_line = dialogue_line
	if dialogue_line.text.is_empty():
		_box.hide()
		is_waiting_for_input = true
	else:
		_box.show()
		await _type_page()

	if dialogue_line.time != "":
		var time: float = dialogue_line.text.length() * 0.02 if dialogue_line.time == "auto" else dialogue_line.time.to_float()
		await get_tree().create_timer(time).timeout
		next(dialogue_line.next_id)


## The current line split into the pages the box shows.
func dialogue_line_pages() -> PackedStringArray:
	return dialogue_label.paginate(dialogue_line.text, dialogue_label.custom_minimum_size.x - 1.0, LINES_PER_PAGE)


## Go to the next line.
func next(next_id: String) -> void:
	dialogue_line = await dialogue_resource.get_next_dialogue_line(next_id, temporary_game_states)


# Type the current page, then wait for a press.
func _type_page() -> void:
	is_waiting_for_input = false
	dialogue_label.page_text = _pages[_page]
	dialogue_label.type_out()
	await dialogue_label.finished_typing
	_voice.stop()
	is_waiting_for_input = true
	balloon.focus_mode = Control.FOCUS_ALL
	balloon.grab_focus()


# The portrait, the name plate and the text's width for the line's speaker.
# The text sits [constant UiStyle.INSET] inside the frame, or [constant
# UiStyle.GAP] after the portrait when there is one.
func _show_speaker() -> void:
	var speaker: String = dialogue_line.character
	var character: String = Story.character_id(speaker)
	var portrait: Texture2D = Story.portrait(character, dialogue_line.tags)
	_portrait_back.visible = portrait != null
	_portrait.texture = portrait
	var text_left: float = UiStyle.EDGE + UiStyle.FRAME_MARGIN + UiStyle.INSET + (PORTRAIT_SHOWN + UiStyle.GAP if portrait != null else 0.0)
	dialogue_label.custom_minimum_size.x = SCREEN.x - UiStyle.EDGE - UiStyle.FRAME_MARGIN - UiStyle.INSET - text_left
	dialogue_label.add_theme_color_override(&"default_color", Palette.TEXT if not speaker.is_empty() else Palette.NARRATION)
	_set_name_plate(_name_plate, speaker, character)
	_name_plate.position = Vector2(text_left, NAME_PLATE_TOP)
	_voice.stream = load(VOICES[character]) as AudioStream if VOICES.has(character) else null


func _set_name_plate(plate: Label, speaker: String, character: String) -> void:
	plate.visible = not speaker.is_empty()
	if not plate.visible:
		return
	var colors: Dictionary = Palette.name_plate(Story.character_color(character)) if not character.is_empty() else { "plate": Palette.PANEL_RAISED, "text": Palette.TEXT }
	plate.text = tr(speaker, "dialogue")
	plate.add_theme_stylebox_override(&"normal", UiStyle.plate(colors.plate))
	plate.add_theme_color_override(&"font_color", colors.text)
	plate.size = plate.get_minimum_size()


func _show_vote() -> void:
	_box.hide()
	_name_plate.hide()
	var character: String = Story.character_id(dialogue_line.character)
	_set_name_plate(_question_name, dialogue_line.character, character)
	_question.text = dialogue_line.text
	_question.add_theme_color_override(&"font_color", Palette.TEXT if not dialogue_line.character.is_empty() else Palette.NARRATION)
	responses_menu.responses = dialogue_line.responses
	_dress_responses()
	balloon.focus_mode = Control.FOCUS_NONE
	_vote_elapsed = 0.0
	_vote_pointed = false
	_vote.show()
	responses_menu.show()


# The response buttons, in the order shown, without the hidden template.
func _response_items() -> Array[Button]:
	var items: Array[Button] = []
	for child: Node in responses_menu.get_children():
		if child != responses_menu.response_template:
			items.append(child as Button)
	return items


# Turn each response into one of the room's cards: its letter on a tile in the
# card's colour, the option's text beside it.
func _dress_responses() -> void:
	var items: Array[Button] = _response_items()
	for i: int in items.size():
		var card: Dictionary = Palette.VOTE_CARDS[i % Palette.VOTE_CARDS.size()]
		var letter: String = CHOICE_LETTERS[i] if i < CHOICE_LETTERS.size() else ""
		items[i].add_theme_stylebox_override(&"normal", _card_style(card.card, Palette.PANEL))
		items[i].add_theme_stylebox_override(&"hover", _card_style(card.card, Palette.PANEL))
		items[i].add_theme_stylebox_override(&"pressed", _card_style(Palette.FOCUS, Palette.PANEL_RAISED))
		# Drawn like the others until the presenter points at a card.
		items[i].add_theme_stylebox_override(&"focus", _card_style(card.card, Palette.PANEL))
		items[i].add_theme_color_override(&"font_focus_color", Palette.TEXT)
		items[i].add_theme_stylebox_override(&"disabled", _card_style(card.card, Palette.PANEL))
		items[i].mouse_entered.connect(_show_vote_focus)
		var tile: VoteLetter = VoteLetter.new()
		tile.letter = letter
		tile.card = card
		items[i].add_child(tile)


# Draw the focused card as focused, now that the presenter has pointed at one.
func _show_vote_focus() -> void:
	_vote_pointed = true
	for item: Button in _response_items():
		item.add_theme_stylebox_override(&"focus", _card_style(Palette.FOCUS, Palette.PANEL_RAISED))
		item.add_theme_color_override(&"font_focus_color", Palette.FOCUS)


func _card_style(border: Color, background: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(CARD_BORDER)
	style.content_margin_left = CARD_BORDER + CARD_LETTER_WIDTH + UiStyle.GAP
	style.content_margin_right = CARD_BORDER + UiStyle.GAP
	style.content_margin_top = CARD_BORDER + UiStyle.TIGHT
	style.content_margin_bottom = CARD_BORDER + UiStyle.TIGHT
	return style


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


#region Building


func _build() -> void:
	balloon.theme = Theme.new()
	balloon.theme.default_font_size = Story.FONT_SIZE

	# The line's box. Three lines of text (42 px) and the portrait (46 px) do
	# not fit [constant UiStyle.INSET] above and below in its 48 px inside, so
	# for now they keep only the frame's border there, centred in the 48 px.
	_box = PanelContainer.new()
	var frame: StyleBoxTexture = UiStyle.frame()
	frame.content_margin_top = UiStyle.FRAME_MARGIN  # spacing: pending; INSET does not fit three lines
	frame.content_margin_bottom = UiStyle.FRAME_MARGIN  # spacing: pending; INSET does not fit three lines
	_box.add_theme_stylebox_override(&"panel", frame)
	_box.position = Vector2(UiStyle.EDGE, SCREEN.y - UiStyle.EDGE - BOX_HEIGHT)
	_box.size = Vector2(SCREEN.x - 2.0 * UiStyle.EDGE, BOX_HEIGHT)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	balloon.add_child(_box)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", UiStyle.GAP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(row)
	_portrait_back = PanelContainer.new()
	var back: StyleBoxFlat = UiStyle.plate(Palette.SKY_LIGHT)
	back.set_content_margin_all(0)  # spacing: not spacing; the picture fills its plate under the outline
	_portrait_back.add_theme_stylebox_override(&"panel", back)
	_portrait_back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_portrait_back)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(PORTRAIT_SHOWN, PORTRAIT_SHOWN)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_portrait.clip_contents = true
	_portrait_back.add_child(_portrait)

	dialogue_label = PagedLabel.new()
	dialogue_label.skip_action = skip_action
	dialogue_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(dialogue_label)
	dialogue_label.custom_minimum_size = Vector2(200.0, dialogue_label.lines_height(LINES_PER_PAGE))
	dialogue_label.spoke.connect(_on_spoke)

	_name_plate = UiStyle.label()
	balloon.add_child(_name_plate)

	_progress = Polygon2D.new()
	_progress.color = Palette.FOCUS
	_progress.polygon = PackedVector2Array([Vector2.ZERO, Vector2(PROGRESS_SIZE.x, 0), Vector2(PROGRESS_SIZE.x / 2.0, PROGRESS_SIZE.y)])
	# In the box's bottom-right corner, INSET from the frame's side and, like
	# the text, on the frame's bottom border.
	_progress.position = SCREEN - Vector2(UiStyle.EDGE + UiStyle.FRAME_MARGIN + UiStyle.INSET, UiStyle.EDGE + UiStyle.FRAME_MARGIN) - PROGRESS_SIZE
	balloon.add_child(_progress)

	_build_vote()

	_chosen_label = UiStyle.label(Palette.FOCUS, HORIZONTAL_ALIGNMENT_CENTER)
	_chosen_label.add_theme_font_size_override(&"font_size", Story.FONT_SIZE * 2)
	_chosen_label.add_theme_stylebox_override(&"normal", UiStyle.frame())
	_chosen_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_chosen_label.anchor_left = 0.5
	_chosen_label.anchor_right = 0.5
	_chosen_label.anchor_top = 0.5
	_chosen_label.anchor_bottom = 0.5
	_chosen_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_chosen_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_chosen_label.hide()
	balloon.add_child(_chosen_label)

	_voice = AudioStreamPlayer.new()
	add_child(_voice)

	balloon.gui_input.connect(_on_balloon_gui_input)


func _build_vote() -> void:
	var centre: CenterContainer = CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	balloon.add_child(centre)
	_vote = VBoxContainer.new()
	_vote.custom_minimum_size.x = SCREEN.x - 2.0 * UiStyle.EDGE
	_vote.add_theme_constant_override(&"separation", UiStyle.GAP)
	_vote.hide()
	centre.add_child(_vote)

	var question_panel: PanelContainer = PanelContainer.new()
	question_panel.add_theme_stylebox_override(&"panel", UiStyle.frame())
	_vote.add_child(question_panel)
	var question_column: VBoxContainer = VBoxContainer.new()
	question_column.add_theme_constant_override(&"separation", UiStyle.TIGHT)
	question_panel.add_child(question_column)
	_question_name = UiStyle.label()
	_question_name.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	question_column.add_child(_question_name)
	_question = UiStyle.label()
	_question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	question_column.add_child(_question)

	# The menu's script extends Container; on a VBoxContainer it lays its cards out in a column.
	var column: VBoxContainer = VBoxContainer.new()
	column.set_script(RESPONSES_MENU_SCRIPT)
	responses_menu = column as Object as DialogueResponsesMenu
	responses_menu.add_theme_constant_override(&"separation", UiStyle.GAP)
	var template: Button = Button.new()
	template.alignment = HORIZONTAL_ALIGNMENT_LEFT
	template.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	template.custom_minimum_size = Vector2(SCREEN.x - 2.0 * UiStyle.EDGE, CARD_HEIGHT)
	template.add_theme_color_override(&"font_color", Palette.TEXT)
	template.add_theme_color_override(&"font_hover_color", Palette.TEXT)
	template.add_theme_color_override(&"font_focus_color", Palette.FOCUS)
	template.add_theme_color_override(&"font_pressed_color", Palette.FOCUS)
	template.add_theme_color_override(&"font_hover_pressed_color", Palette.FOCUS)
	responses_menu.add_child(template)
	responses_menu.response_template = template
	responses_menu.response_selected.connect(_on_responses_menu_response_selected)
	_vote.add_child(responses_menu)

	_vote_track = ColorRect.new()
	_vote_track.color = Palette.METER_TRACK
	_vote_track.custom_minimum_size = Vector2(0, BAR_HEIGHT)
	_vote_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vote.add_child(_vote_track)
	_vote_fill = ColorRect.new()
	_vote_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vote_track.add_child(_vote_fill)


#endregion

#region Signals


func _on_spoke(letter: String, _letter_index: int, _speed: float) -> void:
	if Story.voice_blips and _voice.stream != null and not _voice.playing and letter != " ":
		_voice.pitch_scale = randf_range(0.95, 1.08)
		_voice.play()


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
	# A press while typing shows the whole page.
	if dialogue_label.is_typing:
		var mouse_was_clicked: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed()
		if mouse_was_clicked or event.is_action_pressed(skip_action):
			get_viewport().set_input_as_handled()
			dialogue_label.skip_typing()
			return

	if not is_waiting_for_input: return
	if dialogue_line.responses.size() > 0: return

	var pressed: bool = (event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event.is_action_pressed(next_action) and get_viewport().gui_get_focus_owner() == balloon)
	if not pressed:
		return
	# When there are no response options the balloon itself is the clickable thing.
	get_viewport().set_input_as_handled()
	if _page < _pages.size() - 1:
		_page += 1
		_type_page()
	else:
		next(dialogue_line.next_id)


func _on_responses_menu_response_selected(response: Variant) -> void:
	if _vote_elapsed < VOTE_GUARD_SECONDS:
		return
	# Hide the cards first, so a second quick press cannot pick a response again
	# before the next line arrives.
	responses_menu.hide()
	_vote.hide()
	var index: int = dialogue_line.responses.find(response)
	_chosen_label.text = CHOSEN_TEXT % CHOICE_LETTERS[maxi(index, 0)]
	_chosen_label.show()
	_chosen_response = response as DialogueResponse
	_chosen_timer.start(CHOSEN_SECONDS)


func _on_chosen_timer_timeout() -> void:
	_chosen_label.hide()
	next(_chosen_response.next_id)


#endregion
