extends Node
## Turns the controller's left stick into steps for menus, the binder, the
## vote cards and the gate's Admit and Stop: one push is one press of the
## D-pad in its direction, and holding it repeats after [constant
## REPEAT_DELAY], then every [constant REPEAT_EVERY], as a held key would.
##
## A stick sends a stream of motion events on one push, and each counts as a
## press of its action, so screens that step ignore stick motion through
## [method step] and take these D-pad presses instead. Walking on the map
## reads the stick itself and is not stepped: steps are made only while a
## scene runs or the game is paused, when the player stands still.


## How far the stick must go to count as pushed, and how far back to count as released.
const PUSH: float = 0.5
const RELEASE: float = 0.3
## Holding the stick repeats the step after this long, then this often.
const REPEAT_DELAY: float = 0.4
const REPEAT_EVERY: float = 0.15
## The D-pad button for each way along each stick axis: [negative, positive].
const BUTTONS: Dictionary[int, Array] = {
	JOY_AXIS_LEFT_X: [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT],
	JOY_AXIS_LEFT_Y: [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN],
}
## Marks the D-pad presses made here, so the controller check can tell them apart.
const FROM_STICK: StringName = &"from_stick"

# For each device and axis, as "device:axis": the way it is pushed (-1, 0 or 1)
# and the seconds until it repeats.
var _held: Dictionary[String, Dictionary] = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Every event reaches the window before any screen can mark it handled.
	get_tree().root.window_input.connect(notice)


## True if [param event] presses [param action] as a step: any press but the
## stick's own motion, which steps through the D-pad presses made here instead.
func step(event: InputEvent, action: StringName) -> bool:
	return not event is InputEventJoypadMotion and event.is_action_pressed(action)


## Take note of a stick's motion: a new push presses the D-pad, a release lets it go.
func notice(event: InputEvent) -> void:
	var motion: InputEventJoypadMotion = event as InputEventJoypadMotion
	if motion == null or not BUTTONS.has(motion.axis):
		return
	var key: String = "%d:%d" % [motion.device, motion.axis]
	var held: Dictionary = _held.get(key, { "way": 0, "wait": 0.0 })
	var way: int = held.way
	if absf(motion.axis_value) >= PUSH:
		way = int(signf(motion.axis_value))
	elif absf(motion.axis_value) < RELEASE:
		way = 0
	if way == held.way:
		return
	if held.way != 0:
		_press(motion.device, motion.axis, held.way, false)
	_held[key] = { "way": way, "wait": REPEAT_DELAY }
	if way != 0 and _stepping():
		_press(motion.device, motion.axis, way, true)


func _process(delta: float) -> void:
	for key: String in _held:
		var held: Dictionary = _held[key]
		if held.way == 0:
			continue
		held.wait -= delta
		if held.wait <= 0.0:
			held.wait += REPEAT_EVERY
			if _stepping():
				var device: int = int(key.get_slice(":", 0))
				var axis: int = int(key.get_slice(":", 1))
				_press(device, axis, held.way, false)
				_press(device, axis, held.way, true)


# Steps only where the player stands still: in a scene or with the game paused.
func _stepping() -> bool:
	return Story.in_scene or get_tree().paused


func _press(device: int, axis: int, way: int, pressed: bool) -> void:
	var button: InputEventJoypadButton = InputEventJoypadButton.new()
	button.device = device
	button.button_index = BUTTONS[axis][0 if way < 0 else 1]
	button.pressed = pressed
	button.set_meta(FROM_STICK, true)
	Input.parse_input_event(button)
