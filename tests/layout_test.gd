extends SceneTree
## Checks the layout of two screens. The pause menu: seven items at the font's
## base size, its panel and title inside the screen, below the dashboard's
## strip and at least UiStyle.EDGE from every edge, clear of the hint, and the
## hint centred along the bottom, on screen; the same for the controller
## check. The organisational chart: every label on its box, the boxes inside
## the chart's room and clear of each other, each level's boxes one size, every
## line one whole pixel wide and crossing no box, every vertical line meeting
## the centre of a box's edge and every horizontal line ending on drops, and
## Room supervisors joined straight below Mme Salma. Exits non-zero on failure.
##
##   Godot --headless --path . -s tests/layout_test.gd


const TITLE_SCENE: String = "res://ui/title/title.tscn"
## Scripts that need the autoloads, loaded once they exist.
const DASHBOARD_SCRIPT: String = "res://ui/dashboard/dashboard.gd"
const EXHIBIT_SCRIPT: String = "res://ui/stage/exhibit_view.gd"
const SCREEN: Rect2 = Rect2(0, 0, 320, 180)
const MENU_ITEMS: int = 7
const SETTLE_FRAMES: int = 5
const TIMEOUT_SECONDS: float = 20.0

var _problems: PackedStringArray = []


func _initialize() -> void:
	create_timer(TIMEOUT_SECONDS).timeout.connect(_on_timeout)
	_main.call_deferred()


func _main() -> void:
	change_scene_to_file(TITLE_SCENE)
	await _settle()
	var story: Node = root.get_node("Story")
	story.call(&"new_game")
	await _settle()
	# Success must be explicit: a coroutine that dies on a runtime error hands its caller nothing.
	if await _check_pause_menu() != true:
		_problems.append("the pause menu check stopped on a script error")
	if await _check_org_chart() != true:
		_problems.append("the org chart check stopped on a script error")
	# Close the map, stop the music at once, so nothing is held at exit.
	story.call(&"restart")
	root.get_node("Music").call(&"silence")
	await create_timer(0.2, true).timeout
	_finish(_problems)


func _check_pause_menu() -> bool:
	print("== Pause menu")
	var pause: Node = current_scene.get_node("PauseMenu")
	var labels: Array = pause.get(&"_labels")
	_expect(labels.size() == MENU_ITEMS, "the pause menu has %d items, not %d" % [labels.size(), MENU_ITEMS])
	var base_size: int = ThemeDB.get_default_theme().default_font_size
	for label: Label in labels:
		var font_size: int = label.get_theme_font_size(&"font_size")
		_expect(font_size >= base_size, "the item \"%s\" is at size %d, under the font's base size %d" % [label.text.strip_edges(), font_size, base_size])
	pause.call(&"_open")
	await _settle()
	_check_pause_view(pause, "the menu")
	pause.call(&"_show_check")
	await _settle()
	_check_pause_view(pause, "the controller check")
	pause.call(&"_resume")
	await _settle()
	return true


func _check_pause_view(pause: Node, view: String) -> void:
	var panel: Rect2 = (pause.get(&"_panel") as Control).get_global_rect()
	var heading: Rect2 = (pause.get(&"_heading") as Control).get_global_rect()
	var hint: Rect2 = (pause.get(&"_hint_panel") as Control).get_global_rect()
	print("  %s: panel %s, title %s, hint %s" % [view, panel, heading, hint])
	var room: Rect2 = SCREEN.grow(-UiStyle.EDGE)
	room.position.y = int(_constant(DASHBOARD_SCRIPT, "STRIP_HEIGHT")) + UiStyle.EDGE
	room.end.y = hint.position.y
	_expect(room.encloses(panel), "in %s the panel %s is not inside %s, below the strip and above the hint" % [view, panel, room])
	_expect(panel.encloses(heading), "in %s the title %s is not inside the panel %s" % [view, heading, panel])
	_expect(SCREEN.encloses(hint), "in %s the hint %s is not on screen" % [view, hint])
	_expect(hint.end.y == SCREEN.end.y, "in %s the hint %s is not at the bottom" % [view, hint])
	_expect(hint.get_center().x == SCREEN.get_center().x, "in %s the hint %s is not centred" % [view, hint])


func _check_org_chart() -> bool:
	print("== Organisational chart")
	var exhibit: Dictionary = (root.get_node("Story").get(&"exhibits") as Dictionary).org_chart
	var view: Control = (load(EXHIBIT_SCRIPT) as GDScript).new()
	root.add_child(view)
	view.set_deferred(&"size", SCREEN.size)
	view.call(&"show_exhibit", "org_chart", exhibit, "", "")
	await _settle()
	var layout: Dictionary = view.call(&"org_chart_layout")
	var boxes: Dictionary = layout.boxes
	var lines: Array = layout.lines
	var chart_top: float = _constant(EXHIBIT_SCRIPT, "TOP")
	var room: Rect2 = Rect2(_constant(EXHIBIT_SCRIPT, "LEFT"), chart_top, _constant(EXHIBIT_SCRIPT, "WIDTH"), SCREEN.size.y - float(_constant(EXHIBIT_SCRIPT, "FOOTER_BOTTOM")) - chart_top)

	var by_depth: Dictionary[int, Array] = {}
	var depth_of: Dictionary[String, int] = {}
	for node: Dictionary in exhibit.nodes:
		var depth: int = 0 if node.parent.is_empty() else depth_of[node.parent] + 1
		depth_of[node.id] = depth
		if not by_depth.has(depth):
			by_depth[depth] = []
		by_depth[depth].append(node.id)
		var box: Rect2 = boxes[node.id]
		var text: String = " ".join(layout.text[node.id])
		print("  %s: %s %s" % [node.id, box, layout.text[node.id]])
		_expect(text == node.label, "the box for %s reads \"%s\", not \"%s\"" % [node.id, text, node.label])
		_expect(room.encloses(box), "the box for %s %s is not inside the chart's room %s" % [node.id, box, room])
		_expect(_whole(box), "the box for %s %s is not on whole pixels" % [node.id, box])
	for depth: int in by_depth:
		var first: Rect2 = boxes[by_depth[depth][0]]
		for id: String in by_depth[depth]:
			_expect((boxes[id] as Rect2).size == first.size, "level %d's boxes differ in size: %s is %s, not %s" % [depth, id, (boxes[id] as Rect2).size, first.size])
	var ids: Array = boxes.keys()
	for i: int in ids.size():
		for j: int in range(i + 1, ids.size()):
			_expect(not (boxes[ids[i]] as Rect2).intersects(boxes[ids[j]]), "the boxes for %s and %s overlap" % [ids[i], ids[j]])

	var verticals: Array[Rect2] = []
	var horizontals: Array[Rect2] = []
	for line: Rect2 in lines:
		_expect(_whole(line) and (line.size.x == 1 or line.size.y == 1), "the line %s is not one whole pixel wide" % line)
		if line.size.x == 1:
			verticals.append(line)
		else:
			horizontals.append(line)
		for id: String in boxes:
			_expect(not line.intersects(boxes[id]), "the line %s crosses the box for %s" % [line, id])
	for line: Rect2 in verticals:
		var top: String = _box_above(line, boxes)
		var bottom: String = _box_below(line, boxes)
		var on_bus: bool = false
		for bus: Rect2 in horizontals:
			on_bus = on_bus or Rect2(line.position.x, line.position.y - 1, 1, line.size.y + 2).intersects(bus)
		_expect(not top.is_empty() or not bottom.is_empty(), "the line %s meets no box's edge" % line)
		_expect((not top.is_empty() and not bottom.is_empty()) or on_bus, "the line %s ends in the air" % line)
	for bus: Rect2 in horizontals:
		var ends: int = 0
		for line: Rect2 in verticals:
			if line.position.x == bus.position.x or line.position.x == bus.end.x - 1:
				ends += int(Rect2(line.position.x, line.position.y - 1, 1, line.size.y + 2).intersects(bus))
		_expect(ends >= 2, "the line %s does not end on a drop at each end" % bus)

	# Room supervisors report to Mme Salma: one straight line from her box's bottom centre.
	var salma: Rect2 = boxes.salma
	var supervisors: Rect2 = boxes.supervisors
	var straight: Rect2 = Rect2(_centre_x(salma), salma.end.y, 1, supervisors.position.y - salma.end.y)
	_expect(straight in verticals, "Room supervisors are not joined straight below Mme Salma by %s" % straight)
	_expect(_centre_x(salma) == _centre_x(supervisors), "Room supervisors are not centred below Mme Salma")
	view.queue_free()
	return true


# The box whose bottom edge [param line] starts on, at its centre, or "".
func _box_above(line: Rect2, boxes: Dictionary) -> String:
	for id: String in boxes:
		var box: Rect2 = boxes[id]
		if line.position.y == box.end.y and line.position.x == _centre_x(box):
			return id
	return ""


# The box whose top edge [param line] ends on, at its centre, or "".
func _box_below(line: Rect2, boxes: Dictionary) -> String:
	for id: String in boxes:
		var box: Rect2 = boxes[id]
		if line.end.y == box.position.y and line.position.x == _centre_x(box):
			return id
	return ""


func _constant(path: String, constant: String) -> Variant:
	return (load(path) as Script).get_script_constant_map()[constant]


func _centre_x(box: Rect2) -> float:
	return box.position.x + floorf(box.size.x / 2.0)


func _whole(rect: Rect2) -> bool:
	return rect.position == rect.position.floor() and rect.size == rect.size.floor()


func _expect(ok: bool, problem: String) -> void:
	if not ok:
		_problems.append(problem)


func _settle() -> void:
	for i: int in SETTLE_FRAMES:
		await process_frame


func _finish(problems: PackedStringArray) -> void:
	if problems.is_empty():
		print("PASS: the pause menu and the organisational chart")
		quit(0)
		return
	for problem: String in problems:
		printerr("FAIL: " + problem)
	quit(1)


func _on_timeout() -> void:
	printerr("FAIL: timed out after %.0f seconds" % TIMEOUT_SECONDS)
	quit(2)
