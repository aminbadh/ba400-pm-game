class_name CardView
extends Control
## A full-screen page styled like a lecture slide: a number, a title, the slide
## range, and a body of text. Shows the concept cards and the charter.
##
## Body text marks key terms as **term**; they are drawn in the accent colour.
## A card whose text does not fit splits into several pages in cards.json, each
## page no taller than [constant BODY_SIZE].


## The slide's colours, from [Palette]; each passes 7:1 on the paper.
const PAPER: Color = Palette.PAPER
const INK: Color = Palette.INK
const ACCENT: Color = Palette.SLIDE_ACCENT
const TERM: Color = Palette.TERM
const FAINT: Color = Palette.FAINT
## The pixel border around the slide, outside the text margins.
const BORDER: Array[Color] = [Palette.OUTLINE, Palette.SAND, Palette.WALL_CREAM]
## The slide's layout, in base pixels: it has no frame, so its text keeps its
## own margins from the screen's edge.
const SCREEN: Vector2i = Vector2i(320, 180)
## Space between the screen's edge and the slide's text.
const MARGIN: int = 10
## The accent bar down the slide's left side, inside the border.
const ACCENT_BAR_WIDTH: int = 4
## The tops of the card's number, its slide range and its title.
const NUMBER_TOP: int = 1
const SLIDES_TOP: int = 2
const TITLE_TOP: int = 14
## The height of one line of the slide's text.
const LINE_HEIGHT: int = 14
## The rule under the title, this far above the body.
const RULE_ABOVE_BODY: int = 3
## Where the body text starts, below the number, title and rule.
const BODY_TOP: int = 32
## The room the body text has on a page. The content test checks every page fits.
const BODY_SIZE: Vector2i = Vector2i(300, 134)
## Height of the line under the body that says how to go on, and its
## distance from the screen's bottom.
const FOOTER_HEIGHT: int = 12
const FOOTER_BOTTOM: int = 4
## The space between the body's paragraphs, and the body's leading: its
## lines 1 px closer than the font's.
const PARAGRAPH_GAP: int = UiStyle.GAP
const BODY_LEADING: int = -1
## Room left of the title for the card's number.
const NUMBER_WIDTH: int = 18

var _number_label: Label
var _slides_label: Label
var _title_label: Label
var _body_label: RichTextLabel
var _footer_label: Label


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var paper: ColorRect = ColorRect.new()
	paper.color = PAPER
	paper.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(paper)

	add_border(self)

	var accent_bar: ColorRect = ColorRect.new()
	accent_bar.color = ACCENT
	accent_bar.position = Vector2(BORDER.size(), BORDER.size())
	accent_bar.size = Vector2(ACCENT_BAR_WIDTH, SCREEN.y - 2 * BORDER.size())
	add_child(accent_bar)

	_number_label = _make_label(ACCENT)
	_number_label.add_theme_font_size_override(&"font_size", 20)
	_number_label.position = Vector2(MARGIN, NUMBER_TOP)
	add_child(_number_label)

	_slides_label = _make_label(FAINT)
	_slides_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_slides_label.position = Vector2(MARGIN, SLIDES_TOP)
	_slides_label.size = Vector2(BODY_SIZE.x, LINE_HEIGHT)
	add_child(_slides_label)

	_title_label = _make_label(ACCENT)
	_title_label.position = Vector2(MARGIN, TITLE_TOP)
	_title_label.size = Vector2(BODY_SIZE.x, LINE_HEIGHT)
	add_child(_title_label)

	var rule: ColorRect = ColorRect.new()
	rule.color = ACCENT
	rule.position = Vector2(MARGIN, BODY_TOP - RULE_ABOVE_BODY)
	rule.size = Vector2(BODY_SIZE.x, 1)
	add_child(rule)

	_body_label = RichTextLabel.new()
	_body_label.bbcode_enabled = true
	_body_label.scroll_active = false
	_body_label.clip_contents = true
	_body_label.position = Vector2(MARGIN, BODY_TOP)
	_body_label.size = BODY_SIZE
	_body_label.add_theme_color_override(&"default_color", INK)
	_body_label.add_theme_constant_override(&"line_separation", BODY_LEADING)
	_body_label.add_theme_constant_override(&"paragraph_separation", PARAGRAPH_GAP)
	_body_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_body_label)

	_footer_label = _make_label(FAINT)
	_footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_footer_label.position = Vector2(MARGIN, SCREEN.y - FOOTER_HEIGHT - FOOTER_BOTTOM)
	_footer_label.size = Vector2(BODY_SIZE.x, FOOTER_HEIGHT)
	add_child(_footer_label)


## Show one page of a card or of an exhibit with pages, like the charter.
## [param number] may be empty, as may [param slides].
func show_page(number: String, title: String, slides: String, body: String, page: int, pages: int, footer: String) -> void:
	_number_label.text = number
	_number_label.visible = not number.is_empty()
	_slides_label.text = slides
	_title_label.text = title
	var indent: int = 0 if number.is_empty() else NUMBER_WIDTH
	_title_label.position.x = MARGIN + indent
	_title_label.size.x = BODY_SIZE.x - indent
	_body_label.text = to_bbcode(body)
	var page_text: String = "" if pages <= 1 else "%d/%d   " % [page + 1, pages]
	_footer_label.text = page_text + footer


## Ring [param parent], a full-screen control, with the slide's pixel border.
static func add_border(parent: Control) -> void:
	for i: int in BORDER.size():
		var w: int = SCREEN.x
		var h: int = SCREEN.y
		for side: Rect2 in [Rect2(i, i, w - 2 * i, 1), Rect2(i, h - 1 - i, w - 2 * i, 1), Rect2(i, i, 1, h - 2 * i), Rect2(w - 1 - i, i, 1, h - 2 * i)]:
			var line: ColorRect = ColorRect.new()
			line.color = BORDER[i]
			line.position = side.position
			line.size = side.size
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			parent.add_child(line)


## Body text with **terms** turned into the accent colour, and any square
## brackets escaped so they show as typed.
static func to_bbcode(text: String) -> String:
	var escaped: String = text.replace("[", "[lb]")
	var parts: PackedStringArray = escaped.split("**")
	var result: String = ""
	for i: int in parts.size():
		if i % 2 == 1:
			result += "[color=#%s]%s[/color]" % [TERM.to_html(false), parts[i]]
		else:
			result += parts[i]
	return result


## Body text as it is drawn, without the term marks, for measuring.
static func plain_text(text: String) -> String:
	return text.replace("**", "")


## The height the body text of the page shown needs, to check it fits [constant BODY_SIZE].
func body_content_height() -> int:
	return _body_label.get_content_height()


## True if the title shown fits on one line.
func title_fits() -> bool:
	var font: Font = _title_label.get_theme_font(&"font")
	return font.get_string_size(_title_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _title_label.get_theme_font_size(&"font_size")).x <= _title_label.size.x


func _make_label(color: Color) -> Label:
	var label: Label = Label.new()
	label.add_theme_color_override(&"font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
