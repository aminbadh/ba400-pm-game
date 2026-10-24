class_name UiStyle
extends RefCounted
## The styles every screen shares: the pixel frame around panels, the small
## dark plates under names on the map, and the labels drawn on them. Colours
## come from [Palette].


## The nine-slice pixel frame drawn by tools/draw_ui.py.
const FRAME_PATH: String = "res://art/ui/frame.png"
## How many pixels of each side of the frame stay unstretched: its border.
const FRAME_MARGIN: int = 5

## The spacing rule every screen follows, in base pixels.
## From the inside of any frame's border to its content, on all four sides.
const INSET: int = 6
## Between separate items: vote cards, groups in a menu, portrait to text, question to cards.
const GAP: int = 4
## Between the lines of one list: binder rows, dashboard meters, menu items.
const TIGHT: int = 2
## From any panel to the screen's edge.
const EDGE: int = 4
## Inside the small name and room plates, on the left and right of the text.
const PLATE_X: int = 3
## Inside the small name and room plates, above and below the text.
const PLATE_Y: int = 1
## The dark outline around the small plates and the strips along the screen's edges.
const PLATE_BORDER: int = 1


## The opaque pixel frame for a panel, with its content [constant INSET]
## inside its border.
static func frame() -> StyleBoxTexture:
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = load(FRAME_PATH) as Texture2D
	style.texture_margin_left = FRAME_MARGIN
	style.texture_margin_top = FRAME_MARGIN
	style.texture_margin_right = FRAME_MARGIN
	style.texture_margin_bottom = FRAME_MARGIN
	style.set_content_margin_all(FRAME_MARGIN + INSET)
	return style


## A small dark plate with a dark outline, for a name on the map.
static func plate(color: Color = Palette.PANEL) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Palette.OUTLINE
	style.set_border_width_all(PLATE_BORDER)
	style.content_margin_left = PLATE_X
	style.content_margin_right = PLATE_X
	style.content_margin_top = PLATE_Y
	style.content_margin_bottom = PLATE_Y
	return style


## A flat, fully opaque panel colour, for full screens.
static func flat(color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	return style


## A label in [param color] that ignores the mouse.
static func label(color: Color = Palette.TEXT, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var made: Label = Label.new()
	made.add_theme_color_override(&"font_color", color)
	made.horizontal_alignment = align
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return made


## Put [param label] on a plate, shrunk to its text and centred where it was;
## the plate grows [constant PLATE_Y] above the text as well as below it.
static func put_on_plate(label: Label, color: Color = Palette.PANEL) -> void:
	label.add_theme_stylebox_override(&"normal", plate(color))
	label.add_theme_color_override(&"font_color", Palette.TEXT)
	var centre_x: float = label.position.x + label.size.x / 2.0
	label.size = label.get_minimum_size()
	label.position.x = roundf(centre_x - label.size.x / 2.0)
	label.position.y -= PLATE_Y
