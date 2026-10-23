class_name ExhibitView
extends Control
## Draws the charts the story shows full screen: the organisational chart, the
## RACI chart and the resource histogram, on the same paper as the cards. Their
## content comes from content/exhibits.json.


const LEFT: float = CardView.MARGIN
const WIDTH: float = CardView.BODY_SIZE.x
## Where the title, its rule and the chart start, and the footer's distance
## from the screen's bottom.
const TITLE_TOP: float = 6.0
const RULE_TOP: float = 20.0
const TOP: float = 24.0
const FOOTER_BOTTOM: float = 16.0
const FONT_SIZE: int = 10
const LINE_HEIGHT: float = 13.0

var _kind: String = ""
var _exhibit: Dictionary = {}
var _variant: String = ""
var _footer: String = ""


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Draw exhibit [param kind] ("org_chart", "raci" or "histogram").
func show_exhibit(kind: String, exhibit: Dictionary, variant: String, footer: String) -> void:
	_kind = kind
	_exhibit = exhibit
	_variant = variant
	_footer = footer
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), CardView.PAPER)
	for i: int in CardView.BORDER.size():
		draw_rect(Rect2(i + 0.5, i + 0.5, size.x - 2 * i - 1, size.y - 2 * i - 1), CardView.BORDER[i], false, 1.0)
	var border: int = CardView.BORDER.size()
	draw_rect(Rect2(border, border, CardView.ACCENT_BAR_WIDTH, size.y - 2 * border), CardView.ACCENT)
	_text(Vector2(LEFT, TITLE_TOP), _exhibit.get("title", ""), CardView.ACCENT)
	draw_rect(Rect2(LEFT, RULE_TOP, WIDTH, 1), CardView.ACCENT)
	_text(Vector2(LEFT, size.y - FOOTER_BOTTOM), _footer, CardView.FAINT, WIDTH, HORIZONTAL_ALIGNMENT_RIGHT)
	match _kind:
		"org_chart":
			_draw_org_chart()
		"raci":
			_draw_raci()
		"histogram":
			_draw_histogram()


func _draw_org_chart() -> void:
	# Lay the nodes out level by level, each level spread across the width.
	var nodes: Array = _exhibit.nodes
	var depth_of: Dictionary = {}
	var levels: Array[Array] = []
	for node: Dictionary in nodes:
		var depth: int = 0 if node.parent.is_empty() else int(depth_of[node.parent]) + 1
		depth_of[node.id] = depth
		while levels.size() <= depth:
			levels.append([])
		levels[depth].append(node)

	# A label too wide for its box breaks after its comma.
	var box_height: float = LINE_HEIGHT * 2.0 + 4.0
	var gap: float = (size.y - TOP - 24.0 - box_height * levels.size()) / maxf(levels.size() - 1, 1.0)
	var centres: Dictionary = {}
	for depth: int in levels.size():
		var level: Array = levels[depth]
		var slot: float = WIDTH / level.size()
		var y: float = TOP + 6.0 + depth * (box_height + gap)
		for i: int in level.size():
			var node: Dictionary = level[i]
			var lines: PackedStringArray = [node.label]
			if _width(node.label) > slot - 10.0 and ", " in node.label:
				lines = (node.label as String).split(", ", true, 1)
				lines[0] += ","
			var widest: float = 0.0
			for line: String in lines:
				widest = maxf(widest, _width(line))
			var box_width: float = minf(slot - 4.0, widest + 10.0)
			var height: float = LINE_HEIGHT * lines.size() + 4.0
			var x: float = roundf(LEFT + slot * i + (slot - box_width) / 2.0)
			var box: Rect2 = Rect2(x, roundf(y + (box_height - height) / 2.0), roundf(box_width), height)
			centres[node.id] = box
			draw_rect(box, Palette.WHITE)
			draw_rect(box, CardView.INK, false, 1.0)
			for l: int in lines.size():
				_text(Vector2(x, box.position.y + 1.0 + l * LINE_HEIGHT), lines[l], CardView.INK, box_width, HORIZONTAL_ALIGNMENT_CENTER)
	for node: Dictionary in nodes:
		if node.parent.is_empty():
			continue
		var parent: Rect2 = centres[node.parent]
		var child: Rect2 = centres[node.id]
		var from: Vector2 = Vector2(roundf(parent.get_center().x), parent.end.y)
		var to: Vector2 = Vector2(roundf(child.get_center().x), child.position.y)
		var mid_y: float = roundf((from.y + to.y) / 2.0)
		draw_line(from, Vector2(from.x, mid_y), CardView.ACCENT)
		draw_line(Vector2(from.x, mid_y), Vector2(to.x, mid_y), CardView.ACCENT)
		draw_line(Vector2(to.x, mid_y), to, CardView.ACCENT)


func _draw_raci() -> void:
	var columns: Array = _exhibit.columns
	var rows: Array = _exhibit.rows
	# Each column is as wide as the longest word of its name, which goes on
	# one line per word; the task column takes what is left.
	var widths: Array[float] = []
	var used: float = 0.0
	for header: String in columns:
		var widest: float = 0.0
		for word: String in header.split(" "):
			widest = maxf(widest, _width(word))
		widths.append(widest + 6.0)
		used += widest + 6.0
	var task_width: float = WIDTH - used
	var row_height: float = 18.0
	var y: float = TOP + 4.0
	var x: float = LEFT + task_width
	for i: int in columns.size():
		var words: PackedStringArray = (columns[i] as String).split(" ")
		for w: int in words.size():
			_text(Vector2(x, y + w * LINE_HEIGHT - (words.size() - 1) * 6.0), words[w], CardView.ACCENT, widths[i], HORIZONTAL_ALIGNMENT_CENTER)
		x += widths[i]
	y += row_height + 2.0
	for row: Dictionary in rows:
		draw_rect(Rect2(LEFT, y - 2.0, WIDTH, 1), CardView.FAINT)
		_text(Vector2(LEFT, y + 2.0), row.task, CardView.INK, task_width - 4.0)
		var cells: Array = row.cells
		var cell_x: float = LEFT + task_width
		for i: int in cells.size():
			var cell: String = cells[i]
			var color: Color = CardView.INK
			if cell == "?":
				color = CardView.TERM
				draw_rect(Rect2(roundf(cell_x + widths[i] / 2.0 - 7.0), y, 14.0, 15.0), CardView.TERM, false, 1.0)
			_text(Vector2(cell_x, y + 2.0), cell, color, widths[i], HORIZONTAL_ALIGNMENT_CENTER)
			cell_x += widths[i]
		y += row_height
	draw_rect(Rect2(LEFT, y - 2.0, WIDTH, 1), CardView.FAINT)


func _draw_histogram() -> void:
	var days: Array = _exhibit.days
	var needed: Array = _exhibit.needed.duplicate()
	var available: int = int(_exhibit.available)
	if _variant == "levelled":
		needed[0] = available
	var highest: float = float(available)
	for value: Variant in needed:
		highest = maxf(highest, float(value))
	var top_value: float = highest * 1.1
	var chart_top: float = TOP + 10.0
	var chart_bottom: float = size.y - 40.0
	var chart_height: float = chart_bottom - chart_top
	var left: float = LEFT + 18.0
	var slot: float = (WIDTH - 18.0) / days.size()
	var bar_width: float = slot - 12.0
	var line_y: float = roundf(chart_bottom - chart_height * available / top_value)

	draw_line(Vector2(left, chart_top), Vector2(left, chart_bottom), CardView.INK)
	draw_line(Vector2(left, chart_bottom), Vector2(left + WIDTH - 18.0, chart_bottom), CardView.INK)
	for i: int in days.size():
		var x: float = left + slot * i + 6.0
		var value: int = int(needed[i])
		var height: float = chart_height * value / top_value
		var bar: Rect2 = Rect2(roundf(x), roundf(chart_bottom - height), roundf(bar_width), roundf(height))
		draw_rect(bar, CardView.ACCENT)
		# Values go inside the bars, so none sits on the line for the supervisors we have.
		_text(Vector2(x, bar.position.y + 1.0), str(value), CardView.PAPER, bar_width, HORIZONTAL_ALIGNMENT_CENTER)
		_text(Vector2(x - 4.0, chart_bottom + 2.0), days[i], CardView.INK, bar_width + 8.0, HORIZONTAL_ALIGNMENT_CENTER)

	# The line for the supervisors the centre has.
	for dash: float in range(int(left), int(left + WIDTH - 18.0), 6):
		draw_line(Vector2(dash, line_y), Vector2(dash + 3.0, line_y), CardView.TERM)
	_text(Vector2(left, line_y - 12.0), _exhibit.available_label, CardView.TERM, WIDTH - 18.0, HORIZONTAL_ALIGNMENT_RIGHT)


# Draw [param text] with its top-left at [param at], optionally aligned in [param width].
func _text(at: Vector2, text: String, color: Color, width: float = -1.0, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var font: Font = get_theme_default_font()
	var baseline: Vector2 = Vector2(roundf(at.x), roundf(at.y + font.get_ascent(FONT_SIZE)))
	draw_string(font, baseline, text, align, width, FONT_SIZE, color)


func _width(text: String) -> float:
	return get_theme_default_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
