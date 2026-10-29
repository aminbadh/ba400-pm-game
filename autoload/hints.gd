extends Node
## Which device the presenter used last, the keyboard, a PlayStation-style
## controller or a touchscreen, and the hints on screen for it. A hint is a
## template with the names below in braces, such as "{interact}  next":
## [method text] fills in "E", the cross button or "Tap". Screens that show
## hints redraw them on [signal device_changed].


## The devices a hint can be written for.
enum Device { KEYBOARD, JOYPAD, TOUCH }

## Emitted when the last input comes from another device.
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
## And by touch: a tap on the line, the card or the item itself, or one of
## [Touch]'s buttons, named by the word it shows.
const TOUCH: Dictionary[String, String] = {
	"interact": "Tap",
	"open_binder": "Binder",
	"close_binder": "Binder",
	"menu": "Menu",
	"resume": "Menu",
	"back": "Tap",
	"move": "D-pad",
	"choose": "Tap",
	"admit": "Tap",
	"stop": "Tap",
}
## A stick pushed further than this counts as using the controller; less is drift.
const STICK_THRESHOLD: float = 0.5

## The device the last input came from.
var device: Device = Device.KEYBOARD


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Every event reaches the window before any screen can mark it handled.
	get_tree().root.window_input.connect(notice)


## [param template] with each name in braces replaced by its key or button
## on the device used last. A screen whose hint would read badly in taps
## gives its own [param touch_template].
func text(template: String, touch_template: String = "") -> String:
	match device:
		Device.JOYPAD:
			return template.format(JOYPAD)
		Device.TOUCH:
			return (template if touch_template.is_empty() else touch_template).format(TOUCH)
	return template.format(KEYBOARD)


## True while the last input came from a touchscreen.
func is_touch() -> bool:
	return device == Device.TOUCH


## Take note of the device [param event] came from.
func notice(event: InputEvent) -> void:
	var from: Device
	if event is InputEventJoypadButton:
		if not event.is_pressed():
			return
		from = Device.JOYPAD
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) < STICK_THRESHOLD:
			return
		from = Device.JOYPAD
	elif event is InputEventScreenTouch:
		if not event.is_pressed():
			return
		from = Device.TOUCH
	elif event is InputEventKey or event is InputEventMouseButton:
		# The clicks Godot makes from a touch are the touch's, not a mouse's.
		if not event.is_pressed() or event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		from = Device.KEYBOARD
	else:
		return
	if from != device:
		device = from
		device_changed.emit()
