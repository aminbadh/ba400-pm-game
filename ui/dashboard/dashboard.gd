class_name Dashboard
extends CanvasLayer
## The project dashboard, top-left: Integrity, Fairness, Team and Budget, each
## with an icon, a label, a bar and a number, so no meter is read by colour
## alone. Hidden until scene 3 puts it on screen; meters the chosen metrics do
## not light stay greyed out. With metrics_passrate it shows every meter green
## and full until the ending reveals the real values.
##
## At the bottom, while the player walks, a line says who to talk to next.


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
const BAR_SIZE: Vector2 = Vector2(36, 5)
const EDGE: float = 3.0
const GOOD: Color = Palette.METER_GOOD
const WARN: Color = Palette.METER_WARN
const BAD: Color = Palette.METER_BAD
const GREY: Color = Palette.METER_OFF

var _panel: PanelContainer
var _bars: Dictionary[String, ColorRect] = {}
var _values: Dictionary[String, Label] = {}
var _names: Dictionary[String, Label] = {}
var _icons: Dictionary[String, TextureRect] = {}
var _hint_panel: PanelContainer
var _hint_label: Label


func _ready() -> void:
	layer = 20
	_build()
	GameState.changed.connect(_refresh)
	Story.scene_changed.connect(_refresh)
	_refresh()


## The text and colour one meter shows, for the dashboard and the tests.
static func display(meter: String) -> Dictionary:
	var faked: bool = GameState.has_flag("metrics_passrate") and not GameState.dashboard_revealed
	var lit: bool = meter in GameState.lit_meters or GameState.dashboard_revealed
	var scaled: int = 100 if faked else GameState.scaled(meter)
	var value: int = GameState.budget if meter == "budget" else scaled
	if faked and meter == "budget":
		value = GameState.BUDGET_START
	var color: Color = GREY
	if lit:
		color = GOOD if scaled >= GameState.SMOOTH_FROM else (WARN if scaled >= GameState.NEWS_BELOW else BAD)
	var text: String = str(value) if meter != "budget" else "%d TND" % value
	return { "fill": scaled / 100.0, "color": color, "text": text, "lit": lit }


## The screen area the dashboard covers, so nothing else is drawn under it.
func panel_rect() -> Rect2:
	return _panel.get_rect()


func _refresh() -> void:
	_panel.visible = GameState.dashboard_shown or GameState.scene > 3
	for meter: String in GameState.METERS:
		var shown: Dictionary = display(meter)
		_bars[meter].size.x = roundf(BAR_SIZE.x * float(shown.fill))
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
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override(&"panel", UiStyle.frame(0))
	_panel.position = Vector2(EDGE, EDGE)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override(&"h_separation", 4)
	grid.add_theme_constant_override(&"v_separation", -2)
	_panel.add_child(grid)
	var icons: Texture2D = load(ICONS_PATH) as Texture2D
	for meter: String in GameState.METERS:
		var icon: TextureRect = TextureRect.new()
		var region: AtlasTexture = AtlasTexture.new()
		region.atlas = icons
		region.region = Rect2(ICON_ORDER.find(meter) * ICON_SIZE, 0, ICON_SIZE, ICON_SIZE)
		icon.texture = region
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(icon)
		_icons[meter] = icon

		var name_label: Label = UiStyle.label()
		name_label.text = METER_NAMES[meter]
		grid.add_child(name_label)
		_names[meter] = name_label

		# The bar in a dark outlined track.
		var track: ColorRect = ColorRect.new()
		track.color = Palette.OUTLINE
		track.custom_minimum_size = BAR_SIZE + Vector2(2, 2)
		track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(track)
		var inner: ColorRect = ColorRect.new()
		inner.color = Palette.METER_TRACK
		inner.position = Vector2.ONE
		inner.size = BAR_SIZE
		track.add_child(inner)
		var bar: ColorRect = ColorRect.new()
		bar.size = BAR_SIZE
		inner.add_child(bar)
		_bars[meter] = bar

		var value_label: Label = UiStyle.label(Palette.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
		grid.add_child(value_label)
		_values[meter] = value_label

	# Who to talk to next, at the bottom, where the dialogue box goes once they talk.
	_hint_panel = PanelContainer.new()
	_hint_panel.add_theme_stylebox_override(&"panel", UiStyle.frame(0))
	_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_panel.anchor_left = 0.5
	_hint_panel.anchor_right = 0.5
	_hint_panel.anchor_top = 1.0
	_hint_panel.anchor_bottom = 1.0
	_hint_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint_panel.offset_bottom = -EDGE
	add_child(_hint_panel)
	_hint_label = UiStyle.label(Palette.TEXT)
	_hint_panel.add_child(_hint_label)
