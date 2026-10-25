extends Node
## Which device the presenter used last, the keyboard or a PlayStation-style
## controller, and the hints on screen for it. A hint is a template with the
## names below in braces, such as "{interact}  next": [method text] fills in
## "E" or the cross button. Screens that show hints redraw them on
## [signal device_changed].


## Emitted when the last input comes from the other device.
signal device_changed

## What each name in a hint stands for on the keyboard.
const KEYBOARD: Dictionary[String, String] = {
	"interact": "E",
	"open_binder": "B",
	"close_binder": "B",
	"menu": "Esc",
	"resume": "Esc",
	"back": "Esc",
	"move": "WASD",
	"choose": "Up/Down",
	"admit": "1",
	"stop": "2",
}
## And on the controller: the cross button talks and confirms, the circle backs
## out, the triangle opens the binder, Start the menu; the D-pad or the left stick moves.
const JOYPAD: Dictionary[String, String] = {
	"interact": Glyphs.CROSS_BUTTON,
	"open_binder": "△",
	"close_binder": "○",
	"menu": Glyphs.START_BUTTON,
	"resume": "○",
	"back": "○",
	"move": "D-pad",
	"choose": "↑/↓",
	"admit": "←",
	"stop": "→",
}
## A stick pushed further than this counts as using the controller; less is drift.
const STICK_THRESHOLD: float = 0.5

## True when the last input came from a controller.
var joypad: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Every event reaches the window before any screen can mark it handled.
	get_tree().root.window_input.connect(notice)


## [param template] with each name in braces replaced by its key or button
## on the device used last.
func text(template: String) -> String:
	return template.format(JOYPAD if joypad else KEYBOARD)


## Take note of the device [param event] came from.
func notice(event: InputEvent) -> void:
	var from_joypad: bool
	if event is InputEventJoypadButton:
		if not event.is_pressed():
			return
		from_joypad = true
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) < STICK_THRESHOLD:
			return
		from_joypad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		if not event.is_pressed():
			return
		from_joypad = false
	else:
		return
	if from_joypad != joypad:
		joypad = from_joypad
		device_changed.emit()
