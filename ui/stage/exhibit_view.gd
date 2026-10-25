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
	var layout: Dictionary = org_chart_layout()
	for line: Rect2 in layout.lines:
		draw_rect(line, CardView.ACCENT)
	var font_height: float = get_theme_default_font().get_height(FONT_SIZE)
	for id: String in layout.boxes:
		var box: Rect2 = layout.boxes[id]
		var lines: PackedStringArray = layout.text[id]
		# An outline one pixel wide inside the box's edge, then the plate.
		draw_rect(box, CardView.INK)
		draw_rect(box.grow(-UiStyle.PLATE_BORDER), Palette.WHITE)
		var text_top: float = box.position.y + roundf((box.size.y - font_height * lines.size()) / 2.0)
		for l: int in lines.size():
			_text(Vector2(box.position.x, text_top + l * font_height), lines[l], CardView.INK, box.size.x, HORIZONTAL_ALIGNMENT_CENTER)


## The organisational chart laid out as a tree, in whole pixels: each level's
## boxes as wide and as tall as each other, a node with one child straight above
## it and the children of a node with more spread evenly across the width.
## Returns "boxes" and "text" by node id, the box's Rect2 and its lines, and
## "lines", the connecting lines as Rect2s one pixel wide: a vertical line from
## the bottom edge of a parent to the top edge of an only child, or from the
## parent down to a horizontal line across its children, with a drop from it
## into the top edge of each.
func org_chart_layout() -> Dictionary:
	var nodes: Array = _exhibit.nodes
	var depth_of: Dictionary[String, int] = {}
	var levels: Array[Array] = []
	var children: Dictionary[String, Array] = {}
	for node: Dictionary in nodes:
		var depth: int = 0 if node.parent.is_empty() else depth_of[node.parent] + 1
		depth_of[node.id] = depth
		while levels.size() <= depth:
			levels.append([])
		levels[depth].append(node)
		if not node.parent.is_empty():
			if not children.has(node.parent):
				children[node.parent] = []
			children[node.parent].append(node)

	# Each level: one line per label where they all fit their share of the
	# width, otherwise every label breaks after its comma, so the level's boxes
	# keep one width and one height.
	var padding: Vector2 = 2.0 * Vector2(UiStyle.PLATE_BORDER + UiStyle.PLATE_X, UiStyle.PLATE_BORDER + UiStyle.PLATE_Y)
	var font_height: float = get_theme_default_font().get_height(FONT_SIZE)
	var text: Dictionary[String, PackedStringArray] = {}
	var box_sizes: Array[Vector2] = []
	for level: Array in levels:
		var room: float = (WIDTH - UiStyle.GAP * (level.size() - 1)) / level.size()
		var widest: float = 0.0
		for node: Dictionary in level:
			widest = maxf(widest, _width(node.label))
		var line_count: int = 1 if widest + padding.x <= room else 2
		widest = 0.0
		for node: Dictionary in level:
			var label_lines: PackedStringArray = [node.label]
			if line_count == 2:
				label_lines = _break_label(node.label)
			text[node.id] = label_lines
			for line: String in label_lines:
				widest = maxf(widest, _width(line))
		# An odd width puts a pixel column at the centre for the lines.
		var box_width: int = int(ceilf(widest + padding.x))
		box_width += 1 - box_width % 2
		box_sizes.append(Vector2(box_width, font_height * line_count + padding.y))

	# The levels evenly down the room between the rule and the footer.
	var chart_top: float = TOP + UiStyle.GAP
	var chart_bottom: float = size.y - FOOTER_BOTTOM - UiStyle.GAP
	var used: float = 0.0
	for box_size: Vector2 in box_sizes:
		used += box_size.y
	var level_gap: float = floorf((chart_bottom - chart_top - used) / maxf(levels.size() - 1, 1.0))
	var boxes: Dictionary[String, Rect2] = {}
	var y: float = chart_top
	for depth: int in levels.size():
		var level: Array = levels[depth]
		var box_size: Vector2 = box_sizes[depth]
		for node: Dictionary in level:
			var centre: float = LEFT + WIDTH / 2.0
			if not node.parent.is_empty():
				var siblings: Array = children[node.parent]
				var parent: Rect2 = boxes[node.parent]
				centre = parent.position.x + floorf(parent.size.x / 2.0) + 0.5
				if siblings.size() > 1:
					var slot: float = WIDTH / siblings.size()
					centre = LEFT + slot * (siblings.find(node) + 0.5)
			boxes[node.id] = Rect2(floorf(centre - box_size.x / 2.0), y, box_size.x, box_size.y)
		y += box_size.y + level_gap

	var lines: Array[Rect2] = []
	for parent_id: String in children:
		var parent: Rect2 = boxes[parent_id]
		var from_x: float = parent.position.x + floorf(parent.size.x / 2.0)
		var kids: Array = children[parent_id]
		var child_top: float = boxes[kids[0].id].position.y
		if kids.size() == 1:
			lines.append(Rect2(from_x, parent.end.y, 1, child_top - parent.end.y))
			continue
		var bus_y: float = parent.end.y + floorf((child_top - parent.end.y) / 2.0)
		lines.append(Rect2(from_x, parent.end.y, 1, bus_y - parent.end.y))
		var first: Rect2 = boxes[kids[0].id]
		var last: Rect2 = boxes[kids[-1].id]
		var left_x: float = first.position.x + floorf(first.size.x / 2.0)
		var right_x: float = last.position.x + floorf(last.size.x / 2.0)
		lines.append(Rect2(left_x, bus_y, right_x - left_x + 1, 1))
		for kid: Dictionary in kids:
			var child: Rect2 = boxes[kid.id]
			var x: float = child.position.x + floorf(child.size.x / 2.0)
			lines.append(Rect2(x, bus_y + 1, 1, child.position.y - bus_y - 1))
	return { "boxes": boxes, "text": text, "lines": lines }


# A label on two lines: broken after its comma, or else at its middle space.
func _break_label(label: String) -> PackedStringArray:
	if ", " in label:
		var parts: PackedStringArray = label.split(", ", true, 1)
		parts[0] += ","
		return parts
	var words: PackedStringArray = label.split(" ")
	if words.size() < 2:
		return [label]
	var half: int = floori(words.size() / 2.0)
	return [" ".join(words.slice(0, half)), " ".join(words.slice(half))]


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
