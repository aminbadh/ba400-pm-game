class_name LastScreen
extends Control
## The game's last screen: the whole cast in a row on the courtyard, the centre
## head and the eight characters, each waving, with their name plates below
## them; a thank-you above and the hand-off to the next team below. The picture
## behind is the title screen's lycée with no trees or benches, drawn by
## tools/build_map.py, raised so the cast stands on the paving, with its paving
## repeated below it.
##
## Everything stacks from below the dashboard's strip to [constant UiStyle.EDGE]
## above the screen's bottom, [constant UiStyle.GAP] apart. Every name plate
## is under its character, in two staggered rows, since nine side by side do not
## fit, [constant UiStyle.GAP] apart, shifted sideways where two would touch.


const PICTURE_PATH: String = "res://art/ui/last_screen.png"
## How far the picture is raised, so the foot of its wall comes under the cast's feet.
const PICTURE_RAISE: int = 40
## The paving's pattern repeats every this many rows, two tiles of its bond,
## and runs to the picture's bottom edge: the band below repeats its last period.
const PAVING_PERIOD: int = 32
## Each character's two waving frames, side by side, drawn by tools/draw_characters.py:
## [constant WAVE_SIZE] each, the 16 px body centred, with room for the raised hand.
const WAVE_PATH: String = "res://art/characters/%s_wave.png"
const WAVE_SIZE: Vector2 = Vector2(24, 16)
const SPRITE_SIZE: int = 16
## How long each waving frame shows, and how far apart the characters' waves start.
const WAVE_SECONDS: float = 0.4
const WAVE_STAGGER: float = 0.15
const TITLE_SIZE: int = 20
const SCREEN: Vector2 = Vector2(320, 180)
## The height of a name plate: a line of text with [constant UiStyle.PLATE_Y] above and below.
const NAME_PLATE_HEIGHT: float = Balloon.NAME_PLATE_HEIGHT
## The row: the sprites, then [constant UiStyle.TIGHT] below them the first row
## of plates, then [constant UiStyle.GAP] below that the second.
const PLATE_ROWS_TOP: Array[float] = [SPRITE_SIZE + UiStyle.TIGHT, SPRITE_SIZE + UiStyle.TIGHT + NAME_PLATE_HEIGHT + UiStyle.GAP]
const CAST_HEIGHT: float = SPRITE_SIZE + UiStyle.TIGHT + 2.0 * NAME_PLATE_HEIGHT + UiStyle.GAP

var _title: Label
var _subtitle: Label
var _body: RichTextLabel
var _column: VBoxContainer
var _cast: Control
var _sprites: Array[TextureRect] = []
var _frames: Array[Array] = []
var _plates: Array[Label] = []
var _time: float = 0.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var picture: TextureRect = TextureRect.new()
	picture.texture = load(PICTURE_PATH) as Texture2D
	picture.position = Vector2(0, -PICTURE_RAISE)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(picture)
	# The band the raised picture leaves at the bottom, filled with its last
	# period of paving, as often as it takes, so the pattern runs on unbroken.
	var paving: AtlasTexture = AtlasTexture.new()
	paving.atlas = picture.texture
	paving.region = Rect2(0, SCREEN.y - PAVING_PERIOD, SCREEN.x, PAVING_PERIOD)
	for top: int in range(int(SCREEN.y) - PICTURE_RAISE, int(SCREEN.y), PAVING_PERIOD):
		var below: TextureRect = TextureRect.new()
		below.texture = paving
		below.position = Vector2(0, top)
		below.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(below)

	_column = VBoxContainer.new()
	_column.position = Vector2(UiStyle.EDGE, Dashboard.STRIP_HEIGHT + UiStyle.GAP)
	_column.size = Vector2(SCREEN.x - 2.0 * UiStyle.EDGE, SCREEN.y - Dashboard.STRIP_HEIGHT - UiStyle.GAP - UiStyle.EDGE)
	_column.add_theme_constant_override(&"separation", UiStyle.GAP)
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_column)

	var heading: PanelContainer = PanelContainer.new()
	heading.add_theme_stylebox_override(&"panel", UiStyle.plate())
	heading.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_column.add_child(heading)
	var heading_lines: VBoxContainer = VBoxContainer.new()
	heading_lines.add_theme_constant_override(&"separation", 0)  # spacing: not spacing; the two lines of one heading
	heading.add_child(heading_lines)
	_title = UiStyle.label(Palette.FOCUS, HORIZONTAL_ALIGNMENT_CENTER)
	_title.add_theme_font_size_override(&"font_size", TITLE_SIZE)
	heading_lines.add_child(_title)
	_subtitle = UiStyle.label(Palette.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	heading_lines.add_child(_subtitle)

	_cast = Control.new()
	_cast.custom_minimum_size = Vector2(0, CAST_HEIGHT)
	_cast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(_cast)

	var body_plate: PanelContainer = PanelContainer.new()
	body_plate.add_theme_stylebox_override(&"panel", UiStyle.plate())
	_column.add_child(body_plate)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_theme_color_override(&"default_color", Palette.TEXT)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body_plate.add_child(_body)


## Fill the screen and show it: [param title] and, smaller, [param subtitle]
## above the cast; [param body] below, ending on [param closing] in the
## heading colour. The cast and its order come from content/scenes.json.
func present(title: String, subtitle: String, body: String, closing: String) -> void:
	_title.text = title
	_subtitle.text = subtitle
	_body.text = "%s [color=#%s]%s[/color]" % [body.replace("[", "[lb]"), Palette.FOCUS.to_html(false), closing.replace("[", "[lb]")]
	_build_cast(Story.cast)
	show()


## The screen areas of the heading, each name plate, each sprite and the body,
## by name, for the layout check.
func areas() -> Dictionary[String, Rect2]:
	var found: Dictionary[String, Rect2] = {
		"heading": (_title.get_parent().get_parent() as Control).get_global_rect(),
		"body": (_body.get_parent() as Control).get_global_rect(),
	}
	for i: int in _plates.size():
		found["plate %s" % _plates[i].text] = _plates[i].get_global_rect()
		found["sprite %s" % _plates[i].text] = _sprites[i].get_global_rect()
	return found


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	for i: int in _sprites.size():
		var frame: int = int((_time + i * WAVE_STAGGER) / WAVE_SECONDS) % 2
		_sprites[i].texture = _frames[i][frame]


# One sprite per character, spread evenly across the row, each with its name
# plate above or below in turn, kept inside the screen's edges.
func _build_cast(cast: Array) -> void:
	for child: Node in _cast.get_children():
		child.queue_free()
	_sprites.clear()
	_frames.clear()
	_plates.clear()
	var width: float = SCREEN.x - 2.0 * UiStyle.EDGE
	var slot: float = width / cast.size()
	for i: int in cast.size():
		var character: String = cast[i]
		var sheet: Texture2D = load(WAVE_PATH % character) as Texture2D
		var frames: Array[AtlasTexture] = []
		for frame: int in 2:
			var atlas: AtlasTexture = AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(frame * WAVE_SIZE.x, 0, WAVE_SIZE.x, WAVE_SIZE.y)
			frames.append(atlas)
		_frames.append(frames)
		var centre: float = roundf(slot * (i + 0.5))
		var sprite: TextureRect = TextureRect.new()
		sprite.texture = frames[0]
		sprite.position = Vector2(centre - WAVE_SIZE.x / 2.0, 0)
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cast.add_child(sprite)
		_sprites.append(sprite)

		var plate: Label = UiStyle.label()
		var colors: Dictionary = Palette.name_plate(Story.character_color(character))
		plate.text = Story.character_name(character)
		plate.add_theme_stylebox_override(&"normal", UiStyle.plate(colors.plate))
		plate.add_theme_color_override(&"font_color", colors.text)
		_cast.add_child(plate)
		plate.size = plate.get_minimum_size()
		plate.position = Vector2(roundf(centre - plate.size.x / 2.0), PLATE_ROWS_TOP[i % 2])
		_plates.append(plate)
	for row: int in 2:
		_spread(_plates.filter(func(plate: Label) -> bool: return _plates.find(plate) % 2 == row), width)


# Keep one row's plates inside [0, width] and [constant UiStyle.GAP] apart:
# pushed right past the one before, then back left from the row's right end.
func _spread(row: Array, width: float) -> void:
	var edge: float = 0.0
	for plate: Label in row:
		plate.position.x = maxf(plate.position.x, edge)
		edge = plate.position.x + plate.size.x + UiStyle.GAP
	edge = width
	for i: int in range(row.size() - 1, -1, -1):
		var plate: Label = row[i]
		plate.position.x = minf(plate.position.x, edge - plate.size.x)
		edge = plate.position.x - UiStyle.GAP
