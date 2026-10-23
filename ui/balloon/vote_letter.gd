class_name VoteLetter
extends Control
## The left end of a vote card: a tile in the colour of the room's card with
## its big letter, drawn with a light edge above-left and a dark edge
## below-right for the 3D look of the printed letters. Fills its card's height.


## The card's border, which the tile sits just inside.
const BORDER: int = 2
const WIDTH: float = 26.0
const LETTER_SIZE: int = 20

## The letter, "A", "B" or "C".
var letter: String = ""
## The card's colours, one of [constant Palette.VOTE_CARDS].
var card: Dictionary = {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_bottom = 1.0
	offset_left = BORDER
	offset_top = BORDER
	offset_right = BORDER + WIDTH
	offset_bottom = -BORDER


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), card.card)
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, 1)), card.light)
	draw_rect(Rect2(size.x - 1.0, 0, 1, size.y), card.dark)
	var font: Font = get_theme_default_font()
	var glyph: Vector2 = font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, LETTER_SIZE)
	var at: Vector2 = Vector2(roundf((size.x - glyph.x) / 2.0), roundf((size.y - glyph.y) / 2.0 + font.get_ascent(LETTER_SIZE)))
	# The letter's edges, then its face.
	for offset: Vector2 in [Vector2(2, 2), Vector2(1, 2), Vector2(2, 1)]:
		draw_string(font, at + offset, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, LETTER_SIZE, card.dark)
	draw_string(font, at + Vector2(-1, -1), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, LETTER_SIZE, card.light)
	draw_string(font, at, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, LETTER_SIZE, card.text)
