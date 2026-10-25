class_name Binder
extends CanvasLayer
## The planning binder: the nine concept cards in order, which is also the quest
## log. Collected cards can be opened. Opened with B (the triangle on a
## controller) or from the pause menu, and by the story itself: in scene 0 as a
## read-only overview, card 1 ticked and the rest still to come, and as the
## debrief at the ending, where each card shows the room's choice, the line for
## it and the best choice.
##
## While it is open the game is paused.


## Emitted when the binder closes, unless a skipped scene cancelled it.
signal closed

## The height the debrief rows have on one page.
const DEBRIEF_PAGE_HEIGHT: int = 128
const ROW_WIDTH: int = 290
const SCREEN: Vector2i = Vector2i(320, 180)
## Where the text starts: INSET inside the frame, which sits EDGE from the
## screen's side.
const LEFT: int = UiStyle.EDGE + UiStyle.FRAME_MARGIN + UiStyle.INSET
## The tops of the heading, its rule, the rows and the hint. The nine rows do
## not fit INSET below the frame's top with TIGHT between them, so for now
## they keep these places and touch one another.
const HEADING_TOP: int = 9
const RULE_TOP: int = 23
const ROWS_TOP: int = 26
const HINT_TOP: int = 157
const HINT_HEIGHT: int = 12
const TEXT: Color = Palette.TEXT
const DIM: Color = Palette.DIM
const FOCUS: Color = Palette.FOCUS
const BEST: Color = Palette.NARRATION
const HEADING: String = "Planning binder"
const OVERVIEW_HEADING: String = "Planning binder: %d of %d"
const DEBRIEF_HEADING: String = "Debrief"
## The overview's mark for a card collected; the others are greyed, still to come.
const COLLECTED_MARK: String = Glyphs.TICK
## The hints, filled in by [Hints] for the device used last.
const LIST_HINT: String = "{choose}  choose    {interact}  open    {close_binder}  close"
const CARD_HINT: String = "{interact}  back"
const OVERVIEW_HINT: String = "{interact}  continue"
const DEBRIEF_HINT: String = "{interact}  next"

var _mode: String = ""
# The story's wait while it shows the quest log or the debrief; dropped, never
# resolved, when a skipped scene cancels it, so that scene's dialogue stays stopped.
var _story_waiter: Stage.Waiter = null
var _selected: int = 0
var _debrief_page: int = 0
# The debrief's pages, each a list of card indices that fit on it.
var _debrief_pages: Array[Array] = []
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
	# Above the dialogue balloon, which stays on screen while the game is paused.
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	hide()
	Story.binder = self
	Hints.device_changed.connect(_on_device_changed)


func _exit_tree() -> void:
	if Story.binder == self:
		Story.binder = null


## True while the binder is on screen.
func is_open() -> bool:
	return visible


## Open the list of cards for browsing.
func open() -> void:
	_open("browse")


## Open the binder as a read-only overview and wait until the presenter goes on.
func open_overview() -> void:
	await _open_for_story("overview")


## Open the debrief and wait until the presenter has paged through it.
func open_debrief() -> void:
	await _open_for_story("debrief")


## Close without waiting for the presenter, for a skipped scene.
func cancel() -> void:
	_story_waiter = null
	if visible:
		hide()
		_card_view.hide()
		get_tree().paused = _was_paused


func _open_for_story(mode: String) -> void:
	var waiter: Stage.Waiter = Stage.Waiter.new()
	_story_waiter = waiter
	_open(mode)
	await waiter.done


func _open(mode: String) -> void:
	_mode = mode
	_selected = 0
	_debrief_page = 0
	_card = {}
	if mode == "debrief":
		_debrief_pages = _paginate_debrief()
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
	if _story_waiter != null:
		var waiter: Stage.Waiter = _story_waiter
		_story_waiter = null
		waiter.done.emit(null)


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
			if _debrief_page >= _debrief_pages.size():
				_close()
			else:
				_render()
	elif _mode == "overview":
		if event.is_action_pressed(&"interact"):
			_close()
	else:
		_handle_list_input(event)


func _handle_list_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"binder") or event.is_action_pressed(&"pause") or event.is_action_pressed(&"back"):
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
	elif not (event.is_action_pressed(&"binder") or event.is_action_pressed(&"pause") or event.is_action_pressed(&"back")):
		return
	_card = {}
	_card_view.hide()
	_render()


func _show_card() -> void:
	var pages: Array = _card.pages
	_card_view.show_page(str(int(_card.number)), _card.title, _card.slides, pages[_card_page], _card_page, pages.size(), Hints.text(CARD_HINT if _card_page == pages.size() - 1 else Stage.NEXT_HINT))
	_card_view.show()


func _on_device_changed() -> void:
	if not visible:
		return
	if not _card.is_empty():
		_show_card()
	else:
		_render()


func _render() -> void:
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	# The nine rows of the list touch; the debrief's cards stand apart.
	_rows.add_theme_constant_override(&"separation", UiStyle.GAP if _mode == "debrief" else 0)  # spacing: pending; nine rows with TIGHT do not fit
	if _mode == "debrief":
		_render_debrief()
	elif _mode == "overview":
		_render_overview()
	else:
		_render_list()


# The nine cards, read-only: those collected ticked, the rest greyed as still to come.
func _render_overview() -> void:
	_heading.text = OVERVIEW_HEADING % [GameState.cards.size(), Story.cards.size()]
	_hint.text = Hints.text(OVERVIEW_HINT)
	for card: Dictionary in Story.cards:
		var collected: bool = int(card.number) in GameState.cards
		var label: Label = Label.new()
		label.text = "%s %d  %s" % [COLLECTED_MARK if collected else " ", int(card.number), card.title]
		label.add_theme_color_override(&"font_color", TEXT if collected else DIM)
		_rows.add_child(label)


func _render_list() -> void:
	_heading.text = HEADING
	_hint.text = Hints.text(LIST_HINT)
	for i: int in Story.cards.size():
		var card: Dictionary = Story.cards[i]
		var collected: bool = int(card.number) in GameState.cards
		var label: Label = Label.new()
		label.text = "%s %d  %s" % [">" if i == _selected else " ", int(card.number), card.title]
		var color: Color = TEXT if collected else DIM
		if i == _selected:
			color = FOCUS if collected else TEXT
			label.add_theme_stylebox_override(&"normal", UiStyle.flat(Palette.PANEL_RAISED))
		label.add_theme_color_override(&"font_color", color)
		_rows.add_child(label)


func _render_debrief() -> void:
	_heading.text = "%s  %d/%d" % [DEBRIEF_HEADING, _debrief_page + 1, _debrief_pages.size()]
	_hint.text = Hints.text(DEBRIEF_HINT)
	for i: int in _debrief_pages[_debrief_page]:
		var card_rows: VBoxContainer = VBoxContainer.new()
		card_rows.add_theme_constant_override(&"separation", 0)  # spacing: not spacing; the lines of one card's entry
		for row: Dictionary in debrief_rows(Story.cards[i]):
			var label: Label = _row_label(row.color)
			label.text = row.text
			card_rows.add_child(label)
		_rows.add_child(card_rows)


## The debrief's rows for [param card], each a [code]text[/code] and its
## [code]color[/code]: the card's title, then the room's choice, the line for
## it and the best choice from [method Story.debrief_rows], where they apply.
func debrief_rows(card: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = [{ "text": "%d  %s" % [int(card.number), card.title], "color": FOCUS }]
	var lines: Dictionary = Story.debrief_rows(card)
	for key: String in ["chose", "line", "best"]:
		if not (lines[key] as String).is_empty():
			rows.append({ "text": lines[key], "color": BEST if key == "best" else TEXT })
	return rows


## The height [param card]'s debrief rows take at the row width.
func debrief_height(card: Dictionary) -> float:
	var font: Font = _heading.get_theme_font(&"font")
	var font_size: int = _heading.get_theme_font_size(&"font_size")
	var height: float = 0.0
	for row: Dictionary in debrief_rows(card):
		height += font.get_multiline_string_size(row.text, HORIZONTAL_ALIGNMENT_LEFT, ROW_WIDTH, font_size).y
	return height


# Fill each page with as many cards' debrief rows as fit, a gap between cards.
func _paginate_debrief() -> Array[Array]:
	var pages: Array[Array] = [[]]
	var used: float = 0.0
	for i: int in Story.cards.size():
		var height: float = debrief_height(Story.cards[i])
		var needed: float = height if pages[-1].is_empty() else height + UiStyle.GAP
		if used + needed > DEBRIEF_PAGE_HEIGHT and not pages[-1].is_empty():
			pages.append([])
			used = 0.0
			needed = height
		pages[-1].append(i)
		used += needed
	return pages


func _row_label(color: Color) -> Label:
	var label: Label = Label.new()
	label.add_theme_color_override(&"font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(ROW_WIDTH, 0)
	return label


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var panel: Panel = Panel.new()
	panel.add_theme_stylebox_override(&"panel", UiStyle.frame())
	panel.position = Vector2(UiStyle.EDGE, UiStyle.EDGE)
	panel.size = Vector2(SCREEN.x - 2 * UiStyle.EDGE, SCREEN.y - 2 * UiStyle.EDGE)
	_root.add_child(panel)
	_heading = UiStyle.label(FOCUS)
	_heading.position = Vector2(LEFT, HEADING_TOP)
	_root.add_child(_heading)
	var rule: ColorRect = ColorRect.new()
	rule.color = FOCUS
	rule.position = Vector2(LEFT, RULE_TOP)
	rule.size = Vector2(ROW_WIDTH, 1)
	_root.add_child(rule)
	_rows = VBoxContainer.new()
	_rows.position = Vector2(LEFT, ROWS_TOP)
	_rows.size = Vector2(ROW_WIDTH, DEBRIEF_PAGE_HEIGHT)
	_rows.add_theme_constant_override(&"separation", 0)  # spacing: pending; nine rows with TIGHT do not fit
	_root.add_child(_rows)
	_hint = UiStyle.label(DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	_hint.position = Vector2(LEFT, HINT_TOP)
	_hint.size = Vector2(ROW_WIDTH, HINT_HEIGHT)
	_root.add_child(_hint)
	_card_view = CardView.new()
	_card_view.hide()
	add_child(_card_view)
