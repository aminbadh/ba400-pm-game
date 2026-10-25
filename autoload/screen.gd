extends Node
## Full screen on or off. F11 or Alt+Enter switch it anywhere, and so does the
## pause menu's Full screen item, the only way on a controller. On the web it
## is the browser's own full screen, requested on the press. The Windows build
## starts full screen (window/size/mode.windows in project.godot); the setting
## is not saved between runs.


## Full screen went on or off.
signal changed

# What was asked for last, which the headless display server cannot keep.
var _asked: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Every event reaches the window before any screen sees it, so the press is
	# taken here before Enter, under Alt+Enter, can confirm anything.
	get_tree().root.window_input.connect(notice)


## True while the game fills the screen.
func is_full_screen() -> bool:
	# The headless display server, in the tests, has no window to fill.
	if DisplayServer.get_name() == "headless":
		return _asked
	var mode: int = DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


## Fill the screen if [param on], or go back to a window.
func set_full_screen(on: bool) -> void:
	_asked = on
	get_tree().root.mode = Window.MODE_FULLSCREEN if on else Window.MODE_WINDOWED
	changed.emit()


func toggle() -> void:
	set_full_screen(not is_full_screen())


## Switch full screen on F11 or Alt+Enter. The press then reads as a release,
## so no screen also takes Alt+Enter's Enter as a confirm.
func notice(event: InputEvent) -> void:
	if not event is InputEventKey or event.is_echo() or not event.is_action_pressed(&"full_screen"):
		return
	toggle()
	(event as InputEventKey).pressed = false
