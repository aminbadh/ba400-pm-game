class_name UiStyle
extends RefCounted
## The styles every screen shares: the pixel frame around panels, the small
## dark plates under names on the map, and the labels drawn on them. Colours
## come from [Palette].


## The nine-slice pixel frame drawn by tools/draw_ui.py.
const FRAME_PATH: String = "res://art/ui/frame.png"
## How many pixels of each side of the frame stay unstretched: its border.
const FRAME_MARGIN: int = 5


## The opaque pixel frame for a panel, with [param padding] inside its border.
static func frame(padding: int = 2) -> StyleBoxTexture:
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = load(FRAME_PATH) as Texture2D
	style.texture_margin_left = FRAME_MARGIN
	style.texture_margin_top = FRAME_MARGIN
	style.texture_margin_right = FRAME_MARGIN
	style.texture_margin_bottom = FRAME_MARGIN
	style.set_content_margin_all(FRAME_MARGIN + padding)
	return style


## A small dark plate with a dark outline, for a name on the map.
static func plate(color: Color = Palette.PANEL) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Palette.OUTLINE
	style.set_border_width_all(1)
	style.content_margin_left = 3
	style.content_margin_right = 3
	style.content_margin_top = 0
	style.content_margin_bottom = 0
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


## Put [param label] on a plate, shrunk to its text and centred where it was.
static func put_on_plate(label: Label, color: Color = Palette.PANEL) -> void:
	label.add_theme_stylebox_override(&"normal", plate(color))
	label.add_theme_color_override(&"font_color", Palette.TEXT)
	var centre_x: float = label.position.x + label.size.x / 2.0
	label.size = label.get_minimum_size()
	label.position.x = roundf(centre_x - label.size.x / 2.0)
