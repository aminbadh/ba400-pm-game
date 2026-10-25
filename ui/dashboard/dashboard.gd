class_name Dashboard
extends CanvasLayer
## The project dashboard, a strip as wide as the screen along its top:
## Integrity, Fairness, Team and Budget, left to right, each cell with an icon,
## a name and a number over a bar, so no meter is read by colour alone. On
## screen from the first scene with every meter greyed out and "?" for its
## number; scene 3 flashes it and lights the meters the room's metrics measure,
## and the others stay greyed out until the ending reveals them all. With
## metrics_passrate it shows every meter green and full until the ending
## reveals the real values.
##
## At the bottom, while the player walks, a line says who to talk to next, in a
## strip as wide as the screen. The map's camera stops [constant STRIP_HEIGHT]
## pixels before the map's top edge and [constant HINT_HEIGHT] pixels past its
## bottom edge, so neither strip hides any of the map the camera can show: room
## and name plates scroll under them as off the screen.


const METER_NAMES: Dictionary[String, String] = {
	"integrity": "Integrity",
	"fairness": "Fairness",
	"team": "Team",
	"budget": "Budget",
}
## The meter icons, 9x9 each in this order, drawn by tools/draw_ui.py.
const ICONS_PATH: String = "res://art/ui/icons.png"
const ICON_ORDER: Array[String] = ["integrity", "fairness", "team", "budget"]
const ICON_SIZE: int = 9
## The height of a line of text at the font's base size.
const ROW_HEIGHT: int = 14
## The bar along the bottom of each cell, as wide as the cell.
const BAR_HEIGHT: int = 2
## The height of the strip at the top: a row of text and the bars inside the
## plate's padding and outline. world/centre.tscn's camera keeps it clear.
const STRIP_HEIGHT: int = 2 * (UiStyle.PLATE_BORDER + UiStyle.PLATE_Y) + ROW_HEIGHT + BAR_HEIGHT
## The widest number each cell shows, so a cell keeps its width as values change.
const WIDEST_VALUE: String = "100"
const WIDEST_BUDGET: String = "3000 TND"
## The height of the strip at the bottom; world/centre.tscn's camera keeps it clear.
const HINT_HEIGHT: int = 14
## What an unlit meter shows in place of its number.
const UNKNOWN: String = "?"
## The flash: the strip's outline turns to the heading colour this many
## times, leaving the text on its panel colour.
const FLASHES: int = 3
const FLASH_SECONDS: float = 0.2
const GOOD: Color = Palette.METER_GOOD
const WARN: Color = Palette.METER_WARN
const BAD: Color = Palette.METER_BAD
const GREY: Color = Palette.METER_OFF

var _strip: Panel
var _bars: Dictionary[String, ColorRect] = {}
var _values: Dictionary[String, Label] = {}
var _names: Dictionary[String, Label] = {}
var _icons: Dictionary[String, TextureRect] = {}
var _hint_panel: Panel
var _hint_label: Label


func _ready() -> void:
	layer = 20
	_build()
	GameState.changed.connect(_refresh)
	Story.scene_changed.connect(_refresh)
	Story.dashboard_flashed.connect(flash)
	_refresh()


## The text and colour one meter shows, for the dashboard and the tests.
static func display(meter: String) -> Dictionary:
	var faked: bool = GameState.has_flag("metrics_passrate") and not GameState.dashboard_revealed
	var lit: bool = meter in GameState.lit_meters or GameState.dashboard_revealed
	var scaled: int = 100 if faked else GameState.scaled(meter)
	var value: int = GameState.budget if meter == "budget" else scaled
	if faked and meter == "budget":
		value = GameState.BUDGET_START
	if not lit:
		# Greyed out, with nothing to read in the bar either.
		return { "fill": 1.0, "color": GREY, "text": UNKNOWN, "lit": false }
	var color: Color = GOOD if scaled >= GameState.SMOOTH_FROM else (WARN if scaled >= GameState.NEWS_BELOW else BAD)
	var text: String = str(value) if meter != "budget" else "%d TND" % value
	return { "fill": scaled / 100.0, "color": color, "text": text, "lit": true }


## What the strip at the top shows of each meter, as drawn: whether its cell is
## on screen, its name and number, their colours, and the icon's tint.
func shown_meters() -> Dictionary[String, Dictionary]:
	var shown: Dictionary[String, Dictionary] = {}
	for meter: String in GameState.METERS:
		shown[meter] = {
			"on_screen": _values[meter].is_visible_in_tree() and _names[meter].is_visible_in_tree() and _icons[meter].is_visible_in_tree(),
			"name": _names[meter].text,
			"value": _values[meter].text,
			"name_color": _names[meter].get_theme_color(&"font_color"),
			"value_color": _values[meter].get_theme_color(&"font_color"),
			"icon_tint": _icons[meter].modulate,
		}
	return shown


## Flash the strip, to point the room at it.
func flash() -> void:
	var lit: StyleBoxFlat = UiStyle.plate()
	lit.border_color = Palette.FOCUS
	var tween: Tween = create_tween()
	for i: int in FLASHES:
		tween.tween_callback(_strip.add_theme_stylebox_override.bind(&"panel", lit))
		tween.tween_interval(FLASH_SECONDS)
		tween.tween_callback(_strip.add_theme_stylebox_override.bind(&"panel", UiStyle.plate()))
		tween.tween_interval(FLASH_SECONDS)


## The screen area the strip at the top covers, so nothing else is drawn under it.
func strip_rect() -> Rect2:
	return _strip.get_rect()


## The screen area the strip at the bottom covers.
func hint_rect() -> Rect2:
	return _hint_panel.get_rect()


func _refresh() -> void:
	for meter: String in GameState.METERS:
		var shown: Dictionary = display(meter)
		_bars[meter].anchor_right = float(shown.fill)
		_bars[meter].color = shown.color
		_values[meter].text = shown.text
		var text_color: Color = Palette.TEXT if shown.lit else Palette.DIM
		_values[meter].add_theme_color_override(&"font_color", text_color)
		_names[meter].add_theme_color_override(&"font_color", text_color)
		_icons[meter].modulate = Color.WHITE if shown.lit else Color(0.55, 0.55, 0.6)

	var scene: Dictionary = Story.current_scene()
	var character: String = scene.get("character", "")
	_hint_panel.visible = not Story.in_scene and not character.is_empty()
	if _hint_panel.visible:
		_hint_label.text = "Next: %s, %s" % [Story.character_name(character), Story.places.get(scene.place, "")]


func _build() -> void:
	# The meters in a strip at the top, in the same plate as the strip at the
	# bottom: one cell each, side by side inside the plate's padding. Each cell
	# is at least as wide as its icon, name and widest number, and the cells
	# share what is left of the screen's width.
	_strip = Panel.new()
	_strip.add_theme_stylebox_override(&"panel", UiStyle.plate())
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strip.anchor_left = 0.0
	_strip.anchor_right = 1.0
	_strip.offset_bottom = STRIP_HEIGHT
	add_child(_strip)
	var cells: HBoxContainer = HBoxContainer.new()
	cells.add_theme_constant_override(&"separation", UiStyle.GAP)
	cells.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cells.set_anchors_preset(Control.PRESET_FULL_RECT)
	cells.offset_left = UiStyle.PLATE_BORDER + UiStyle.PLATE_X
	cells.offset_right = -(UiStyle.PLATE_BORDER + UiStyle.PLATE_X)
	cells.offset_top = UiStyle.PLATE_BORDER + UiStyle.PLATE_Y
	cells.offset_bottom = -(UiStyle.PLATE_BORDER + UiStyle.PLATE_Y)
	_strip.add_child(cells)
	var icons: Texture2D = load(ICONS_PATH) as Texture2D
	for meter: String in GameState.METERS:
		var cell: Control = Control.new()
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cells.add_child(cell)
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override(&"separation", UiStyle.GAP)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.set_anchors_preset(Control.PRESET_TOP_WIDE)
		row.offset_bottom = ROW_HEIGHT
		cell.add_child(row)

		var icon: TextureRect = TextureRect.new()
		var region: AtlasTexture = AtlasTexture.new()
		region.atlas = icons
		region.region = Rect2(ICON_ORDER.find(meter) * ICON_SIZE, 0, ICON_SIZE, ICON_SIZE)
		icon.texture = region
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)
		_icons[meter] = icon

		var name_label: Label = UiStyle.label()
		name_label.text = METER_NAMES[meter]
		row.add_child(name_label)
		_names[meter] = name_label

		# The number on the cell's right, as wide as the widest it shows.
		var value_label: Label = UiStyle.label(Palette.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
		value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var widest: String = WIDEST_BUDGET if meter == "budget" else WIDEST_VALUE
		var font: Font = value_label.get_theme_font(&"font")
		var font_size: int = value_label.get_theme_font_size(&"font_size")
		value_label.custom_minimum_size.x = ceilf(font.get_string_size(widest, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
		row.add_child(value_label)
		_values[meter] = value_label
		cell.custom_minimum_size = Vector2(row.get_combined_minimum_size().x, ROW_HEIGHT + BAR_HEIGHT)

		# The bar along the cell's bottom, filled from the left over a dark track.
		var track: ColorRect = ColorRect.new()
		track.color = Palette.METER_TRACK
		track.mouse_filter = Control.MOUSE_FILTER_IGNORE
		track.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		track.offset_top = -BAR_HEIGHT
		cell.add_child(track)
		var bar: ColorRect = ColorRect.new()
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.anchor_bottom = 1.0
		track.add_child(bar)
		_bars[meter] = bar

	# Who to talk to next, in the strip at the bottom, where the dialogue box
	# goes once they talk. The strip keeps its height whatever the plate's
	# padding, so the camera's clearance stays right: its line is centred in it.
	_hint_panel = Panel.new()
	_hint_panel.add_theme_stylebox_override(&"panel", UiStyle.plate())
	_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_panel.anchor_left = 0.0
	_hint_panel.anchor_right = 1.0
	_hint_panel.anchor_top = 1.0
	_hint_panel.anchor_bottom = 1.0
	_hint_panel.offset_top = -HINT_HEIGHT
	add_child(_hint_panel)
	_hint_label = UiStyle.label(Palette.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hint_panel.add_child(_hint_label)
