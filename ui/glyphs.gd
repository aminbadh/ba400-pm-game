class_name Glyphs
extends RefCounted
## The icons the pixel font lacks, as a fallback font for it: a tick and a
## cross for the region's report, and the controller's cross and Start
## buttons for the hints. Any text can then show them, in its own colour, and
## measuring and wrapping it count them like letters. The font's own circle
## and triangle (○ △) serve for those two buttons.
##
## The icons are drawn in white by tools/draw_ui.py, one per cell of
## [constant CELL] in [constant CHARACTERS] order, standing on the cell's
## bottom edge, which is the text's baseline.


const PATH: String = "res://art/ui/glyphs.png"
const CELL: Vector2i = Vector2i(12, 8)
const TICK: String = "✓"
const BALLOT: String = "✗"
const CROSS_BUTTON: String = "✕"
## Start has no character of its own, so it takes one from the private use area.
const START_BUTTON: String = ""
const CHARACTERS: Array[String] = [TICK, BALLOT, CROSS_BUTTON, START_BUTTON]
## The space after each icon, like the space the font leaves after a letter.
const SPACING: int = 1


## A font with the icons at [param size], with [param main]'s line metrics.
static func font(main: Font, size: int) -> FontFile:
	var image: Image = (load(PATH) as Texture2D).get_image()
	var made: FontFile = FontFile.new()
	made.fixed_size = size
	made.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
	var cache: Vector2i = Vector2i(size, 0)
	made.set_cache_ascent(0, size, main.get_ascent(size))
	made.set_cache_descent(0, size, main.get_descent(size))
	made.set_texture_image(0, cache, 0, image)
	for i: int in CHARACTERS.size():
		var glyph: int = CHARACTERS[i].unicode_at(0)
		var cell: Rect2i = Rect2i(i * CELL.x, 0, CELL.x, CELL.y)
		var width: int = image.get_region(cell).get_used_rect().end.x
		made.set_glyph_texture_idx(0, cache, glyph, 0)
		made.set_glyph_uv_rect(0, cache, glyph, Rect2(cell.position, Vector2(width, CELL.y)))
		made.set_glyph_size(0, cache, glyph, Vector2(width, CELL.y))
		made.set_glyph_offset(0, cache, glyph, Vector2(0, -CELL.y))
		made.set_glyph_advance(0, size, glyph, Vector2(width + SPACING, 0))
	return made
