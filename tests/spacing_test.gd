extends SceneTree
## Checks that every screen takes its spacing from the rule in UiStyle: no
## script or scene under ui/ sets a content margin, a separation or a margin
## offset to a number literal. A value written with UiStyle's constants (INSET,
## GAP, TIGHT, EDGE, PLATE_X, PLATE_Y, FRAME_MARGIN), or with a named art size,
## passes. Line spacing inside a block of text (line_separation, line_spacing)
## is the font's leading, not spacing between things, and is not checked.
##
## A line that must keep a number says why in a trailing "# spacing:" comment;
## each one is printed on every run. Exits 1 if any line breaks the rule.
##
##   Godot --headless --path . -s tests/spacing_test.gd


const UI_DIR: String = "res://ui/"
const EXEMPT_MARK: String = "# spacing:"

# What a line sets, and the value it sets it to, in a script.
const SCRIPT_PATTERNS: Array[String] = [
	"content_margin_(?:left|right|top|bottom)\\s*=\\s*(?<value>.+)$",
	"set_content_margin(?:_all)?\\((?<value>.+)\\)",
	"add_theme_constant_override\\(&?\"(?!line_)\\w*separation\",\\s*(?<value>.+)\\)",
	"offset_(?:left|right|top|bottom)\\s*=\\s*(?<value>.+)$",
]
# The same, in a scene file, where every value is written as a number.
const SCENE_PATTERNS: Array[String] = [
	"^content_margin_(?:left|right|top|bottom)\\s*=\\s*(?<value>.+)$",
	"^theme_override_constants/(?!line_)\\w*separation\\s*=\\s*(?<value>.+)$",
	"^offset_(?:left|right|top|bottom)\\s*=\\s*(?<value>.+)$",
]

var _failures: int = 0
var _checked: int = 0


func _initialize() -> void:
	var number: RegEx = RegEx.create_from_string("(?<![\\w.])\\d+(?:\\.\\d+)?")
	var script_patterns: Array[RegEx] = _compile(SCRIPT_PATTERNS)
	var scene_patterns: Array[RegEx] = _compile(SCENE_PATTERNS)
	for path: String in _files(UI_DIR):
		if path.ends_with(".gd"):
			_check_file(path, script_patterns, number)
		elif path.ends_with(".tscn"):
			_check_file(path, scene_patterns, number)
	if _failures > 0:
		printerr("FAIL: %d of %d spacing values under ui/ are number literals, not UiStyle constants" % [_failures, _checked])
		quit(1)
		return
	print("PASS: all %d spacing values under ui/ come from UiStyle's constants" % _checked)
	quit(0)


func _check_file(path: String, patterns: Array[RegEx], number: RegEx) -> void:
	var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
	for i: int in lines.size():
		var line: String = lines[i].strip_edges()
		if line.begins_with("#"):
			continue
		for pattern: RegEx in patterns:
			var found: RegExMatch = pattern.search(line)
			if found == null:
				continue
			_checked += 1
			var value: String = found.get_string("value").get_slice("#", 0)
			var where: String = "%s:%d" % [path.trim_prefix("res://"), i + 1]
			if EXEMPT_MARK in line:
				print("kept  %s  %s" % [where, line.get_slice(EXEMPT_MARK, 1).strip_edges()])
			elif number.search(value) != null:
				_failures += 1
				print("FAIL  %s  %s" % [where, line])
			break


func _compile(patterns: Array[String]) -> Array[RegEx]:
	var compiled: Array[RegEx] = []
	for pattern: String in patterns:
		compiled.append(RegEx.create_from_string(pattern))
	return compiled


# Every file under [param dir], recursively.
func _files(dir: String) -> PackedStringArray:
	var found: PackedStringArray = []
	for file: String in DirAccess.get_files_at(dir):
		found.append(dir + file)
	for sub: String in DirAccess.get_directories_at(dir):
		found.append_array(_files(dir + sub + "/"))
	return found
