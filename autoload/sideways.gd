extends Node
## While the window is taller than it is wide, as a phone held upright, covers
## the game with a short message asking to turn the phone sideways. The game
## goes on under it, paused by nothing, so turning back returns to it as it was.


const MESSAGE: String = "Turn your phone sideways"
## Over everything, the touch controls included.
const LAYER: int = 140

var _layer: CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_refresh()


## True while the message covers the game.
func is_showing() -> bool:
	return _layer.visible


## True if a window of [param size] is held upright.
static func is_upright(size: Vector2i) -> bool:
	return size.y > size.x


# Looked at every frame: a browser turned on its side resizes the page without
# always telling the root viewport.
func _process(_delta: float) -> void:
	_refresh()


func _refresh() -> void:
	_layer.visible = is_upright(get_tree().root.size)


func _build() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = LAYER
	add_child(_layer)
	# Opaque, and it stops the clicks made from touches, so nothing under it takes a tap.
	var cover: ColorRect = ColorRect.new()
	cover.color = Palette.PANEL
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(cover)
	var centre: CenterContainer = CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(centre)
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", UiStyle.frame())
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.add_child(panel)
	var message: Label = UiStyle.label(Palette.FOCUS, HORIZONTAL_ALIGNMENT_CENTER)
	message.text = MESSAGE
	message.add_theme_font_size_override(&"font_size", Story.FONT_SIZE * 2)
	panel.add_child(message)
