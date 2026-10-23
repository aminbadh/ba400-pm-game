class_name Binder
extends CanvasLayer
## The planning binder: the nine concept cards in order, which is also the quest
## log. Collected cards can be opened. Opened with B or from the pause menu,
## and by the story itself: as the quest log in scene 0 and as the debrief at
## the ending, where each card shows the line for the room's vote.
##
## While it is open the game is paused.


## Emitted when the binder closes.
signal closed

const DEBRIEF_PER_PAGE: int = 3
const PANEL_COLOR: Color = Color("1b2230")
const TEXT: Color = Color("f3efe2")
const DIM: Color = Color("6f7682")
const FOCUS: Color = Color("ffd75e")
const HEADING: String = "Planning binder"
const DEBRIEF_HEADING: String = "Debrief"
const LIST_HINT: String = "Up/Down  choose    E  open    B  close"
const CARD_HINT: String = "E  back"
const DEBRIEF_HINT: String = "E  next"

var _mode: String = ""
var _selected: int = 0
var _debrief_page: int = 0
var _was_paused: bool = false
var _opened_at: int = 0

var _root: Control
var _heading: Label
var _rows: VBoxContainer
var _hint: Label
var _card_view: CardView
var _card: Dictionary = {}
var _card_page: int = 0


func _ready() -> void:
	layer = 70
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	hide()
	Story.binder = self


func _exit_tree() -> void:
	if Story.binder == self:
		Story.binder = null


## True while the binder is on screen.
func is_open() -> bool:
	return visible


## Open the list of cards for browsing.
func open() -> void:
	_open("browse")


## Open the binder as the quest log and wait until the presenter closes it.
func open_quest_log() -> void:
	_open("browse")
	await closed


## Open the debrief and wait until the presenter has paged through it.
func open_debrief() -> void:
	_open("debrief")
	await closed


## Close without waiting for the presenter, for a skipped scene.
func cancel() -> void:
	if visible:
		_close()


func _open(mode: String) -> void:
	_mode = mode
	_selected = 0
	_debrief_page = 0
	_card = {}
	_opened_at = Time.get_ticks_msec()
	_was_paused = get_tree().paused
	get_tree().paused = true
	show()
	_render()


func _close() -> void:
	hide()
	_card_view.hide()
	get_tree().paused = _was_paused
	closed.emit()


func _input(event: InputEvent) -> void:
	if not visible:
		if event.is_action_pressed(&"binder") and not get_tree().paused and get_tree().current_scene != null:
			get_viewport().set_input_as_handled()
			open()
		return
	if event is InputEventMouseMotion:
		return
	get_viewport().set_input_as_handled()
	if Time.get_ticks_msec() - _opened_at < Stage.INPUT_GUARD_MSEC:
		return
	if not _card.is_empty():
		_handle_card_input(event)
	elif _mode == "debrief":
		if event.is_action_pressed(&"interact"):
			_debrief_page += 1
			if _debrief_page * DEBRIEF_PER_PAGE >= Story.cards.size():
				_close()
			else:
				_render()
	else:
		_handle_list_input(event)


func _handle_list_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"binder") or event.is_action_pressed(&"pause"):
		_close()
	elif event.is_action_pressed(&"move_up") or event.is_action_pressed(&"ui_up"):
		_selected = wrapi(_selected - 1, 0, Story.cards.size())
		_render()
	elif event.is_action_pressed(&"move_down") or event.is_action_pressed(&"ui_down"):
		_selected = wrapi(_selected + 1, 0, Story.cards.size())
		_render()
	elif event.is_action_pressed(&"interact"):
		var card: Dictionary = Story.cards[_selected]
		if int(card.number) in GameState.cards:
			_card = card
			_card_page = 0
			_show_card()


func _handle_card_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"interact"):
		if _card_page < (_card.pages as Array).size() - 1:
			_card_page += 1
			_show_card()
			return
	elif not (event.is_action_pressed(&"binder") or event.is_action_pressed(&"pause")):
		return
	_card = {}
	_card_view.hide()
	_render()


func _show_card() -> void:
	var pages: Array = _card.pages
	_card_view.show_page(str(int(_card.number)), _card.title, _card.slides, pages[_card_page], _card_page, pages.size(), CARD_HINT if _card_page == pages.size() - 1 else Stage.NEXT_HINT)
	_card_view.show()


func _render() -> void:
	for child: Node in _rows.get_children():
		child.queue_free()
	if _mode == "debrief":
		_render_debrief()
	else:
		_render_list()


func _render_list() -> void:
	_heading.text = HEADING
	_hint.text = LIST_HINT
	for i: int in Story.cards.size():
		var card: Dictionary = Story.cards[i]
		var collected: bool = int(card.number) in GameState.cards
		var label: Label = Label.new()
		label.text = "%s %d  %s" % [">" if i == _selected else " ", int(card.number), card.title]
		var color: Color = TEXT if collected else DIM
		if i == _selected:
			color = FOCUS if collected else DIM.lightened(0.3)
		label.add_theme_color_override(&"font_color", color)
		_rows.add_child(label)


func _render_debrief() -> void:
	var pages: int = ceili(Story.cards.size() / float(DEBRIEF_PER_PAGE))
	_heading.text = "%s  %d/%d" % [DEBRIEF_HEADING, _debrief_page + 1, pages]
	_hint.text = DEBRIEF_HINT
	var first: int = _debrief_page * DEBRIEF_PER_PAGE
	for i: int in range(first, mini(first + DEBRIEF_PER_PAGE, Story.cards.size())):
		var card: Dictionary = Story.cards[i]
		var title: Label = Label.new()
		title.text = "%d  %s" % [int(card.number), card.title]
		title.add_theme_color_override(&"font_color", FOCUS)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.custom_minimum_size = Vector2(296, 0)
		_rows.add_child(title)
		var line: Label = Label.new()
		var vote: String = GameState.votes.get(int(card.scene), "")
		line.text = ("%s: " % vote if not vote.is_empty() else "") + Story.debrief_line(card)
		line.add_theme_color_override(&"font_color", TEXT)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size = Vector2(296, 0)
		_rows.add_child(line)


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var panel: ColorRect = ColorRect.new()
	panel.color = PANEL_COLOR
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(panel)
	_heading = Label.new()
	_heading.add_theme_color_override(&"font_color", FOCUS)
	_heading.position = Vector2(12, 5)
	_root.add_child(_heading)
	var rule: ColorRect = ColorRect.new()
	rule.color = FOCUS
	rule.position = Vector2(12, 19)
	rule.size = Vector2(296, 1)
	_root.add_child(rule)
	_rows = VBoxContainer.new()
	_rows.position = Vector2(12, 23)
	_rows.size = Vector2(296, 140)
	_rows.add_theme_constant_override(&"separation", 1)
	_root.add_child(_rows)
	_hint = Label.new()
	_hint.add_theme_color_override(&"font_color", DIM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.position = Vector2(12, 180 - 14)
	_hint.size = Vector2(296, 12)
	_root.add_child(_hint)
	_card_view = CardView.new()
	_card_view.hide()
	add_child(_card_view)
