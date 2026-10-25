class_name Stage
extends Node
## The full-screen moments of the story: concept cards, exhibits (the charter
## and the charts), scene 4's gate inspection, the region's report, the
## backdrop behind the ending and the last screen. Each waits for the presenter
## before the dialogue goes on, except the last screen, which stays.
##
## The dialogue reaches it through the Story autoload, where it registers itself.


## Ignore presses for this long after a page opens, so a double press on the
## line before it cannot skip a card the room has not seen.
const INPUT_GUARD_MSEC: int = 300
## What the footer says while a page waits for the presenter; see [Hints].
const NEXT_HINT: String = "{interact}  next"
## Draw order: the backdrop and the last screen sit under the dashboard, the
## rest over everything but the dialogue balloon's vote.
const BACKDROP_LAYER: int = 15
const FRONT_LAYER: int = 60
## The backdrop is a bright slide, like the cards.
const BACKDROP_COLOR: Color = Palette.PAPER
## Backdrop titles keep this far from the screen's sides, clear of its 3 px
## border, and stay on one line.
const BACKDROP_MARGIN: int = 6
const BACKDROP_TITLE_LINES: int = 1
## The band a backdrop title sits in, [constant UiStyle.GAP] clear of the
## dashboard's strip above (its bottom at [constant Dashboard.STRIP_HEIGHT], 20)
## and of the speaker's name plate below (its top at
## [constant Balloon.NAME_PLATE_TOP], 110).
const BACKDROP_TITLE_TOP: int = Dashboard.STRIP_HEIGHT + UiStyle.GAP
const BACKDROP_TITLE_HEIGHT: int = int(Balloon.NAME_PLATE_TOP) - UiStyle.GAP - BACKDROP_TITLE_TOP
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
## The inspection's two calls, picked with 1 and 2, or pointed at with left
## and right and confirmed; the one pointed at is marked.
const ADMIT_TEXT: String = "Admit"
const STOP_TEXT: String = "Stop"
const POINTED_MARK: String = ">"
const CONFIRM_HINT: String = "{interact}"
## Wrapped text on a slide: lines 2 px closer than the font's.
const WRAPPED_LEADING: int = -2
const RIGHT_CALL_COLOR: Color = Palette.RIGHT_CALL
const MISS_COLOR: Color = Palette.MISS


## A single wait for the presenter. Each page gets its own, so a cancelled
## page's wait is simply dropped and the dialogue that awaited it never resumes.
class Waiter:
	extends RefCounted
	signal done(value: Variant)


## Draws a candidate's line when the content gives several.
var says_rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _front: CanvasLayer
var _backdrop: CanvasLayer
var _card_view: CardView
var _exhibit_view: ExhibitView
var _inspection_view: Control
var _backdrop_title: Label
var _last_screen: LastScreen

var _waiter: Waiter = null
## What the current wait accepts: "next", or "admit_or_stop".
var _wait_kind: String = ""
var _opened_at: int = 0
var _card: Dictionary = {}
var _page: int = 0
# The exhibit on screen, to redraw its hint.
var _exhibit_name: String = ""
var _exhibit: Dictionary = {}
var _exhibit_variant: String = ""

var _checklist_labels: Array[Label] = []
var _flashes: Array[Tween] = []
var _candidate_count_label: Label
var _candidate_name_label: Label
var _candidate_shows_label: Label
var _result_label: Label
var _after_label: Label
var _prompt_label: Label
# The call pointed at during the inspection: 0 admit, 1 stop, -1 none yet.
var _pointed: int = -1


func _ready() -> void:
	_build()
	Story.stage = self
	Hints.device_changed.connect(_redraw_hints)


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
			_handle_inspection_input(event)


func _handle_inspection_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"choice_1") or event.is_action_pressed(&"choice_2"):
		get_viewport().set_input_as_handled()
		_resolve(event.is_action_pressed(&"choice_1"))
	elif Stick.step(event, &"move_left") or Stick.step(event, &"ui_left"):
		get_viewport().set_input_as_handled()
		_point(0)
	elif Stick.step(event, &"move_right") or Stick.step(event, &"ui_right"):
		get_viewport().set_input_as_handled()
		_point(1)
	elif event.is_action_pressed(&"interact") and _pointed >= 0:
		get_viewport().set_input_as_handled()
		_resolve(_pointed == 0)


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
	_exhibit_name = exhibit_name
	_exhibit = exhibit
	_exhibit_variant = variant
	_exhibit_view.show_exhibit(exhibit_name, exhibit, variant, Hints.text(NEXT_HINT))
	_exhibit_view.show()
	_card = {}
	await _wait("next")
	_exhibit_view.hide()


## Show the region's report, styled like the charter: each success criterion
## from [method Story.report] with a tick or a cross and its reasons, over as
## many pages as it needs.
func present_report(title: String, entries: Array[Dictionary]) -> void:
	_card = { "number": "", "title": title, "slides": "", "pages": [], "rich_pages": report_pages(entries) }
	_page = 0
	_show_card_page()
	_card_view.show()
	await _wait("next")
	_card_view.hide()


## The report's entries as pages of the slide's rich text, each filled with as
## many whole entries as fit [constant CardView.BODY_SIZE].
func report_pages(entries: Array[Dictionary]) -> Array[String]:
	var pages: Array[String] = []
	var page: Array[String] = []
	for entry: Dictionary in entries:
		var paragraph: String = CardView.report_paragraph(entry)
		var with_it: Array[String] = page.duplicate()
		with_it.append(paragraph)
		if not page.is_empty() and _card_view.rich_height(with_it) > CardView.BODY_SIZE.y:
			pages.append("\n".join(page))
			page = []
		page.append(paragraph)
	if not page.is_empty():
		pages.append("\n".join(page))
	return pages


## Show candidate [param index] at the gate; returns true when the presenter
## admits them, false to stop them: 1 or 2, or left or right and then interact.
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
	_candidate_shows_label.text = candidate_shows(candidate, says_rng)
	_result_label.text = ""
	_after_label.text = ""
	_pointed = -1
	_prompt_label.text = inspection_prompt(_pointed)
	_inspection_view.show()
	var admit: Variant = await _wait("admit_or_stop")
	return admit as bool


## What a candidate shows at the gate: its [code]shows[/code] text, with
## [code]{says}[/code] replaced by one of its [code]says[/code] lines, drawn
## afresh each time the candidate appears.
static func candidate_shows(candidate: Dictionary, rng: RandomNumberGenerator) -> String:
	var says: Array = candidate.get("says", [])
	if says.is_empty():
		return candidate.shows
	return (candidate.shows as String).format({ "says": says[rng.randi_range(0, says.size() - 1)] })


## The inspection's prompt: the two calls with their keys or buttons, the one
## pointed at marked, and how to confirm it once one is.
static func inspection_prompt(pointed: int) -> String:
	var admit: String = "%s %s" % [POINTED_MARK if pointed == 0 else Hints.text("{admit}"), ADMIT_TEXT]
	var stop: String = "%s %s" % [POINTED_MARK if pointed == 1 else Hints.text("{stop}"), STOP_TEXT]
	var prompt: String = "%s    %s" % [admit, stop]
	if pointed >= 0:
		prompt += "    " + Hints.text(CONFIRM_HINT)
	return prompt


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
	if not right:
		for line: Variant in candidate.lines:
			_flash(_checklist_labels[int(line)])
	_prompt_label.text = Hints.text(NEXT_HINT)
	await _wait("next")


func end_inspection() -> void:
	_inspection_view.hide()


## Show the backdrop with a title; an empty title hides it.
func set_backdrop(title: String) -> void:
	_backdrop_title.text = title
	_backdrop.visible = not title.is_empty()


## Show the last screen, which stays until a restart.
func show_last_screen(title: String, subtitle: String, body: String, closing: String) -> void:
	_last_screen.present(title, subtitle, body, closing)


## The last screen, for the tests.
func last_screen() -> LastScreen:
	return _last_screen


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
	_last_screen.hide()


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


func _point(choice: int) -> void:
	_pointed = choice
	_redraw_hints()


func _next_page() -> void:
	if _page < _page_count() - 1:
		_page += 1
		_opened_at = Time.get_ticks_msec()
		_show_card_page()
		return
	_resolve(null)


func _page_count() -> int:
	return (_card.get("rich_pages", _card.get("pages", [])) as Array).size()


func _show_card_page() -> void:
	# Card numbers come from JSON as floats; exhibits with pages have none.
	var number: String = "" if typeof(_card.number) == TYPE_STRING else str(int(_card.number))
	var footer: String = Hints.text(NEXT_HINT)
	if _card.has("rich_pages"):
		_card_view.show_rich_page(_card.title, _card.rich_pages[_page], _page, _page_count(), footer)
	else:
		_card_view.show_page(number, _card.title, _card.slides, _card.pages[_page], _page, _page_count(), footer)


# Redraw every hint on screen for the device used last.
func _redraw_hints() -> void:
	if _card_view.visible and not _card.is_empty():
		_show_card_page()
	if _exhibit_view.visible:
		_exhibit_view.show_exhibit(_exhibit_name, _exhibit, _exhibit_variant, Hints.text(NEXT_HINT))
	if _inspection_view.visible:
		_prompt_label.text = inspection_prompt(_pointed) if _wait_kind == "admit_or_stop" else Hints.text(NEXT_HINT)


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

	# The last screen, on its own layer at the backdrop's depth, under the dashboard.
	var last_layer: CanvasLayer = CanvasLayer.new()
	last_layer.layer = BACKDROP_LAYER
	add_child(last_layer)
	_last_screen = LastScreen.new()
	_last_screen.hide()
	last_layer.add_child(_last_screen)

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
