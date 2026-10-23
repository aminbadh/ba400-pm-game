class_name PagedLabel
extends DialogueLabel
## A [DialogueLabel] that types one page of its line at a time, so a long line
## pages inside the box instead of overflowing it. The balloon splits the line
## into pages with [method paginate] and sets [member page_text] before each
## [method DialogueLabel.type_out].
##
## Inline mutations and speed changes are placed by character index in the
## whole line; the story's dialogue uses neither, so pages ignore them.


## The text of the page being typed.
var page_text: String = ""


func _init() -> void:
	bbcode_enabled = false
	fit_content = false
	scroll_active = false
	clip_contents = true
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	shortcut_keys_enabled = false
	visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	mouse_filter = Control.MOUSE_FILTER_PASS
	seconds_per_step = 0.025
	skip_pause_at_abbreviations = PackedStringArray(["Mr", "Mrs", "Ms", "Dr", "etc", "eg", "ex", "M", "Mme"])


func _update_text() -> void:
	text = page_text


## Split [param line] into pages of at most [param lines] lines, wrapped at
## [param width] pixels in this label's font, breaking between words.
func paginate(line: String, width: float, lines: int) -> PackedStringArray:
	var font: Font = get_theme_font(&"normal_font")
	var font_size: int = get_theme_font_size(&"normal_font_size")
	var wrapped: PackedStringArray = []
	var current: String = ""
	for word: String in line.split(" ", false):
		var candidate: String = word if current.is_empty() else current + " " + word
		if current.is_empty() or font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= width:
			current = candidate
		else:
			wrapped.append(current)
			current = word
	if not current.is_empty() or wrapped.is_empty():
		wrapped.append(current)
	var pages: PackedStringArray = []
	for start: int in range(0, wrapped.size(), lines):
		pages.append(" ".join(wrapped.slice(start, start + lines)))
	return pages


## The height of [param lines] lines of text in this label's font.
func lines_height(lines: int) -> int:
	var font: Font = get_theme_font(&"normal_font")
	var font_size: int = get_theme_font_size(&"normal_font_size")
	return int(ceilf(font.get_height(font_size) * lines + get_theme_constant(&"line_separation") * (lines - 1)))
