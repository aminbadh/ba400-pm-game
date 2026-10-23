class_name Dashboard
extends CanvasLayer
## The project dashboard, top-left: Integrity, Fairness, Team and Budget.
## Hidden until scene 3 puts it on screen; meters the chosen metrics do not
## light stay greyed out. With metrics_passrate it shows every meter green and
## full until the ending reveals the real values.
##
## Top-right, a line says who to talk to next.


const METER_NAMES: Dictionary[String, String] = {
	"integrity": "Integrity",
	"fairness": "Fairness",
	"team": "Team",
	"budget": "Budget",
}
const BAR_SIZE: Vector2 = Vector2(36, 5)
const GOOD: Color = Color("43a047")
const WARN: Color = Color("f9a825")
const BAD: Color = Color("e53935")
const GREY: Color = Color("5a5f66")
const TEXT: Color = Color("f3efe2")
const PANEL: Color = Color(0.067, 0.067, 0.067, 0.85)

var _panel: PanelContainer
var _bars: Dictionary[String, ColorRect] = {}
var _values: Dictionary[String, Label] = {}
var _names: Dictionary[String, Label] = {}
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


func _refresh() -> void:
	_panel.visible = GameState.dashboard_shown or GameState.scene > 3
	for meter: String in GameState.METERS:
		var shown: Dictionary = display(meter)
		_bars[meter].size.x = roundf(BAR_SIZE.x * float(shown.fill))
		_bars[meter].color = shown.color
		_values[meter].text = shown.text
		_values[meter].modulate = Color.WHITE if shown.lit else Color(1, 1, 1, 0.45)
		_names[meter].modulate = _values[meter].modulate

	var scene: Dictionary = Story.current_scene()
	var character: String = scene.get("character", "")
	_hint_panel.visible = not Story.in_scene and not character.is_empty()
	if _hint_panel.visible:
		_hint_label.text = "Next: %s, %s" % [Story.character_name(character), Story.places.get(scene.place, "")]


func _build() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL
	style.set_content_margin_all(3)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override(&"panel", style)
	_panel.position = Vector2(3, 3)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override(&"h_separation", 4)
	grid.add_theme_constant_override(&"v_separation", 0)
	_panel.add_child(grid)
	for meter: String in GameState.METERS:
		var name_label: Label = Label.new()
		name_label.text = METER_NAMES[meter]
		name_label.add_theme_color_override(&"font_color", TEXT)
		grid.add_child(name_label)
		_names[meter] = name_label

		var track: ColorRect = ColorRect.new()
		track.color = Color(0.2, 0.2, 0.2)
		track.custom_minimum_size = BAR_SIZE
		track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(track)
		var bar: ColorRect = ColorRect.new()
		bar.size = BAR_SIZE
		track.add_child(bar)
		_bars[meter] = bar

		var value_label: Label = Label.new()
		value_label.add_theme_color_override(&"font_color", TEXT)
		grid.add_child(value_label)
		_values[meter] = value_label

	_hint_panel = PanelContainer.new()
	_hint_panel.add_theme_stylebox_override(&"panel", style)
	_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_panel.anchor_left = 1.0
	_hint_panel.anchor_right = 1.0
	_hint_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_hint_panel.offset_right = -3
	_hint_panel.offset_top = 3
	add_child(_hint_panel)
	_hint_label = Label.new()
	_hint_label.add_theme_color_override(&"font_color", TEXT)
	_hint_panel.add_child(_hint_label)
