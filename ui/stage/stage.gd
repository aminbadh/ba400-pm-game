class_name Stage
extends Node
## The full-screen moments of the story: concept cards, exhibits (the charter
## and the charts), scene 4's gate inspection, and the backdrop behind the
## ending. Each waits for the presenter before the dialogue goes on.
##
## The dialogue reaches it through the Story autoload, where it registers itself.


## Ignore presses for this long after a page opens, so a double press on the
## line before it cannot skip a card the room has not seen.
const INPUT_GUARD_MSEC: int = 300
## What the footer says while a page waits for the presenter.
const NEXT_HINT: String = "E  next"
## Draw order: the backdrop sits under the dashboard, the rest over everything
## but the dialogue balloon's vote.
const BACKDROP_LAYER: int = 15
const FRONT_LAYER: int = 60
## The backdrop is a bright slide, like the cards.
const BACKDROP_COLOR: Color = Palette.PAPER
## Backdrop titles keep this far from the screen's sides, clear of its 3 px
## border, and stay on one line: two lines at this size (56 px) do not fit
## between the dashboard and the dialogue box.
const BACKDROP_MARGIN: int = 6
const BACKDROP_TITLE_LINES: int = 1
## The band a backdrop title sits in, [constant UiStyle.GAP] clear of the
## dashboard above (its panel's bottom at 64) and of the speaker's name plate
## below (its top at [constant Balloon.NAME_PLATE_TOP], 110).
const BACKDROP_TITLE_TOP: int = 68
const BACKDROP_TITLE_HEIGHT: int = int(Balloon.NAME_PLATE_TOP) - UiStyle.GAP - BACKDROP_TITLE_TOP
## The body of the last screen, below the dashboard, and the room it keeps
## from the slide's sides and bottom.
const BACKDROP_BODY_TOP: int = 64
const BACKDROP_BODY_SIDE: int = 20
const BACKDROP_BODY_BOTTOM: int = 12
## The backdrop title's size, and its leading: lines 4 px closer than the font's.
const BACKDROP_TITLE_SIZE: int = 20
const BACKDROP_TITLE_LEADING: int = -4
## The gate inspection's layout on its slide: the checklist on the left, the
## candidate on the right of a divider.
const INSPECTION_HEADING_TOP: int = 6
const CHECKLIST_TOP: int = 22
const CHECKLIST_SIZE: Vector2 = Vector2(172, 150)
const DIVIDER_RECT: Rect2 = Rect2(186, 8, 1, 164)
const CANDIDATE_RECT: Rect2 = Rect2(192, 6, 122, 140)
const PROMPT_LEFT: int = 196
const PROMPT_WIDTH: int = 118
## Wrapped text on a slide: lines 2 px closer than the font's.
const WRAPPED_LEADING: int = -2
const RIGHT_CALL_COLOR: Color = Palette.RIGHT_CALL
const MISS_COLOR: Color = Palette.MISS


## A single wait for the presenter. Each page gets its own, so a cancelled
## page's wait is simply dropped and the dialogue that awaited it never resumes.
class Waiter:
	extends RefCounted
	signal done(value: Variant)


var _front: CanvasLayer
var _backdrop: CanvasLayer
var _card_view: CardView
var _exhibit_view: ExhibitView
var _inspection_view: Control
var _backdrop_title: Label
var _backdrop_body: Label

var _waiter: Waiter = null
## What the current wait accepts: "next", or "admit_or_stop".
var _wait_kind: String = ""
var _opened_at: int = 0
var _card: Dictionary = {}
var _page: int = 0

var _checklist_labels: Array[Label] = []
var _flashes: Array[Tween] = []
var _candidate_count_label: Label
var _candidate_name_label: Label
var _candidate_shows_label: Label
var _result_label: Label
var _after_label: Label
var _prompt_label: Label


func _ready() -> void:
	_build()
	Story.stage = self


func _exit_tree() -> void:
	if Story.stage == self:
		Story.stage = null


func _input(event: InputEvent) -> void:
	if _waiter == null or get_tree().paused:
		return
	if Time.get_ticks_msec() - _opened_at < INPUT_GUARD_MSEC:
		if event.is_action_pressed(&"interact") or event.is_action_pressed(&"choice_1") or event.is_action_pressed(&"choice_2"):
			get_viewport().set_input_as_handled()
		return
	match _wait_kind:
		"next":
			if event.is_action_pressed(&"interact"):
				get_viewport().set_input_as_handled()
				_next_page()
		"admit_or_stop":
			if event.is_action_pressed(&"choice_1") or event.is_action_pressed(&"choice_2"):
				get_viewport().set_input_as_handled()
				_resolve(event.is_action_pressed(&"choice_1"))


#region Calls from Story


## Show a concept card page by page until the presenter has read the last one.
func present_card(card: Dictionary) -> void:
	_card = card
	_page = 0
	_show_card_page()
	_card_view.show()
	await _wait("next")
	_card_view.hide()


## Show an exhibit: one with pages (the charter) like a card, a chart drawn.
func present_exhibit(exhibit_name: String, exhibit: Dictionary, variant: String) -> void:
	if exhibit.has("pages"):
		_card = { "number": "", "title": exhibit.title, "slides": "", "pages": exhibit.pages }
		_page = 0
		_show_card_page()
		_card_view.show()
		await _wait("next")
		_card_view.hide()
		return
	_exhibit_view.show_exhibit(exhibit_name, exhibit, variant, NEXT_HINT)
	_exhibit_view.show()
	_card = {}
	await _wait("next")
	_exhibit_view.hide()


## Show candidate [param index] at the gate; returns true when the presenter
## presses 1 to admit, false for 2 to stop.
func inspect_candidate(index: int, inspection: Dictionary) -> bool:
	var candidates: Array = inspection.candidates
	var candidate: Dictionary = candidates[index]
	if _checklist_labels.is_empty():
		_fill_checklist(inspection)
	for flash: Tween in _flashes:
		flash.kill()
	_flashes.clear()
	for label: Label in _checklist_labels:
		label.add_theme_color_override(&"font_color", CardView.INK)
	_candidate_count_label.text = "%d of %d" % [index + 1, candidates.size()]
	_candidate_name_label.text = candidate.name
	_candidate_shows_label.text = candidate.shows
	_result_label.text = ""
	_after_label.text = ""
	_prompt_label.text = "1  Admit    2  Stop"
	_inspection_view.show()
	var admit: Variant = await _wait("admit_or_stop")
	return admit as bool


## Say whether the call was right, with its effect, and flash the checklist
## lines that cover it when it was missed.
func show_inspection_result(index: int, inspection: Dictionary, right: bool) -> void:
	var candidate: Dictionary = inspection.candidates[index]
	var effects: Dictionary = inspection.correct if right else inspection.miss
	var effect_texts: PackedStringArray = []
	for meter: String in effects:
		effect_texts.append("%s %+d" % [meter.capitalize(), int(effects[meter])])
	_result_label.text = ", ".join(effect_texts)
	_result_label.add_theme_color_override(&"font_color", RIGHT_CALL_COLOR if right else MISS_COLOR)
	var after: String = candidate.get("after", "")
	if candidate.has("after_if_room12_fixed") and GameState.has_flag("room12_fixed"):
		after = (after + " " + candidate.after_if_room12_fixed).strip_edges()
	_after_label.text = after
	_prompt_label.text = NEXT_HINT
	if not right:
		for line: Variant in candidate.lines:
			_flash(_checklist_labels[int(line)])
	await _wait("next")


func end_inspection() -> void:
	_inspection_view.hide()


## Show the backdrop with a title and body; both empty hides it.
func set_backdrop(title: String, body: String) -> void:
	_backdrop_title.text = title
	_backdrop_body.text = body
	_backdrop.visible = not (title.is_empty() and body.is_empty())


## True if the backdrop's title fits inside its margins on at most
## [constant BACKDROP_TITLE_LINES] lines. For the content check.
func backdrop_title_fits() -> bool:
	return _backdrop_title.get_line_count() <= BACKDROP_TITLE_LINES


## The screen area the backdrop's title takes, grown to its text. For the content check.
func backdrop_title_rect() -> Rect2:
	return _backdrop_title.get_global_rect()


## Close whatever is showing and drop its wait, for a skipped scene.
func cancel() -> void:
	_waiter = null
	_wait_kind = ""
	_card_view.hide()
	_exhibit_view.hide()
	_inspection_view.hide()


#endregion


func _wait(kind: String) -> Variant:
	var waiter: Waiter = Waiter.new()
	_waiter = waiter
	_wait_kind = kind
	_opened_at = Time.get_ticks_msec()
	return await waiter.done


func _resolve(value: Variant) -> void:
	var waiter: Waiter = _waiter
	_waiter = null
	_wait_kind = ""
	waiter.done.emit(value)


func _next_page() -> void:
	var pages: Array = _card.get("pages", [])
	if _page < pages.size() - 1:
		_page += 1
		_opened_at = Time.get_ticks_msec()
		_show_card_page()
		return
	_resolve(null)


func _show_card_page() -> void:
	var pages: Array = _card.pages
	# Card numbers come from JSON as floats; exhibits with pages have none.
	var number: String = "" if typeof(_card.number) == TYPE_STRING else str(int(_card.number))
	_card_view.show_page(number, _card.title, _card.slides, pages[_page], _page, pages.size(), NEXT_HINT)


func _flash(label: Label) -> void:
	var tween: Tween = create_tween()
	_flashes.append(tween)
	for i: int in 3:
		tween.tween_property(label, "theme_override_colors/font_color", MISS_COLOR, 0.15)
		tween.tween_property(label, "theme_override_colors/font_color", CardView.INK, 0.15)
	tween.tween_property(label, "theme_override_colors/font_color", MISS_COLOR, 0.15)


#region Building the screens


func _build() -> void:
	_backdrop = CanvasLayer.new()
	_backdrop.layer = BACKDROP_LAYER
	_backdrop.visible = false
	add_child(_backdrop)
	var backdrop_root: Control = Control.new()
	backdrop_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.add_child(backdrop_root)
	var shade: ColorRect = ColorRect.new()
	shade.color = BACKDROP_COLOR
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop_root.add_child(shade)
	CardView.add_border(backdrop_root)
	_backdrop_title = _label(CardView.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	_backdrop_title.add_theme_font_size_override(&"font_size", BACKDROP_TITLE_SIZE)
	_backdrop_title.add_theme_constant_override(&"line_spacing", BACKDROP_TITLE_LEADING)
	_backdrop_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_backdrop_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_backdrop_title.position = Vector2(BACKDROP_MARGIN, BACKDROP_TITLE_TOP)
	_backdrop_title.size = Vector2(CardView.SCREEN.x - 2 * BACKDROP_MARGIN, BACKDROP_TITLE_HEIGHT)
	_backdrop.add_child(_backdrop_title)
	_backdrop_body = _label(CardView.INK, HORIZONTAL_ALIGNMENT_CENTER)
	_backdrop_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_backdrop_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_backdrop_body.position = Vector2(BACKDROP_BODY_SIDE, BACKDROP_BODY_TOP)
	_backdrop_body.size = Vector2(CardView.SCREEN.x - 2 * BACKDROP_BODY_SIDE, CardView.SCREEN.y - BACKDROP_BODY_TOP - BACKDROP_BODY_BOTTOM)
	_backdrop.add_child(_backdrop_body)

	_front = CanvasLayer.new()
	_front.layer = FRONT_LAYER
	add_child(_front)
	_card_view = CardView.new()
	_card_view.hide()
	_front.add_child(_card_view)
	_exhibit_view = ExhibitView.new()
	_exhibit_view.hide()
	_front.add_child(_exhibit_view)
	_build_inspection()


func _build_inspection() -> void:
	_inspection_view = Control.new()
	_inspection_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_inspection_view.hide()
	_front.add_child(_inspection_view)
	var paper: ColorRect = ColorRect.new()
	paper.color = CardView.PAPER
	paper.set_anchors_preset(Control.PRESET_FULL_RECT)
	_inspection_view.add_child(paper)
	CardView.add_border(_inspection_view)
	var bar: ColorRect = ColorRect.new()
	bar.color = CardView.ACCENT
	bar.position = Vector2.ONE * CardView.BORDER.size()
	bar.size = Vector2(CardView.ACCENT_BAR_WIDTH, CardView.SCREEN.y - 2 * CardView.BORDER.size())
	_inspection_view.add_child(bar)

	var checklist: VBoxContainer = VBoxContainer.new()
	checklist.name = "Checklist"
	checklist.position = Vector2(CardView.MARGIN, CHECKLIST_TOP)
	checklist.size = CHECKLIST_SIZE
	checklist.add_theme_constant_override(&"separation", UiStyle.TIGHT)
	_inspection_view.add_child(checklist)
	var heading: Label = _label(CardView.ACCENT)
	heading.name = "Heading"
	heading.position = Vector2(CardView.MARGIN, INSPECTION_HEADING_TOP)
	_inspection_view.add_child(heading)

	var divider: ColorRect = ColorRect.new()
	divider.color = CardView.FAINT
	divider.position = DIVIDER_RECT.position
	divider.size = DIVIDER_RECT.size
	_inspection_view.add_child(divider)

	var right: VBoxContainer = VBoxContainer.new()
	right.position = CANDIDATE_RECT.position
	right.size = CANDIDATE_RECT.size
	right.add_theme_constant_override(&"separation", UiStyle.GAP)
	_inspection_view.add_child(right)
	_candidate_count_label = _label(CardView.FAINT)
	right.add_child(_candidate_count_label)
	_candidate_name_label = _label(CardView.ACCENT)
	right.add_child(_candidate_name_label)
	_candidate_shows_label = _wrapping_label(CardView.INK, CANDIDATE_RECT.size.x)
	right.add_child(_candidate_shows_label)
	_result_label = _label(RIGHT_CALL_COLOR)
	right.add_child(_result_label)
	_after_label = _wrapping_label(CardView.INK, CANDIDATE_RECT.size.x)
	right.add_child(_after_label)

	_prompt_label = _label(CardView.ACCENT, HORIZONTAL_ALIGNMENT_RIGHT)
	_prompt_label.position = Vector2(PROMPT_LEFT, CardView.SCREEN.y - CardView.FOOTER_HEIGHT - CardView.FOOTER_BOTTOM)
	_prompt_label.size = Vector2(PROMPT_WIDTH, CardView.FOOTER_HEIGHT)
	_inspection_view.add_child(_prompt_label)


func _fill_checklist(inspection: Dictionary) -> void:
	(_inspection_view.get_node("Heading") as Label).text = inspection.title
	var checklist: Node = _inspection_view.get_node("Checklist")
	for line: String in inspection.checklist:
		var label: Label = _wrapping_label(CardView.INK, CHECKLIST_SIZE.x)
		label.text = "- " + line
		checklist.add_child(label)
		_checklist_labels.append(label)


func _label(color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label: Label = Label.new()
	label.add_theme_color_override(&"font_color", color)
	label.horizontal_alignment = align
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _wrapping_label(color: Color, width: float) -> Label:
	var label: Label = _label(color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(width, 0)
	label.add_theme_constant_override(&"line_spacing", WRAPPED_LEADING)
	return label


#endregion
