class_name Player
extends CharacterBody2D
## The project manager. Walks in four directions and talks to the NPC it faces.
## Stands still while a scene plays.


## Walking speed in pixels per second.
const SPEED: float = 64.0
## How far the probe sweeps beyond its start in front of the player's body.
const REACH: float = 10.0
## How deep the probe box is along [member facing].
const PROBE_DEPTH: float = 4.0
## Walking frames per second.
const STEPS_PER_SECOND: float = 8.0
## The sprite sheet's rows, by facing: down, left, right, up.
const FACING_ROWS: Dictionary[Vector2, int] = { Vector2.DOWN: 0, Vector2.LEFT: 1, Vector2.RIGHT: 2, Vector2.UP: 3 }

## The direction the player last moved in, one of the four unit vectors.
var facing: Vector2 = Vector2.DOWN

var _walk_time: float = 0.0

## Sweeps a small box from just in front of the player's body towards [member facing].
@onready var _talk_probe: ShapeCast2D = $TalkProbe
@onready var _body: CollisionShape2D = $CollisionShape2D
@onready var _sprite: Sprite2D = $Sprite2D


func _physics_process(delta: float) -> void:
	if Story.in_scene:
		velocity = Vector2.ZERO
		_show_frame(0)
		return

	var direction: Vector2 = _read_direction()
	if direction != Vector2.ZERO:
		facing = direction
	velocity = direction * SPEED
	move_and_slide()
	# Standing, then the two walking steps in turn while moving.
	if direction == Vector2.ZERO:
		_walk_time = 0.0
		_show_frame(0)
	else:
		_walk_time += delta
		_show_frame(1 + int(_walk_time * STEPS_PER_SECOND) % 2)


func _show_frame(step: int) -> void:
	_sprite.frame = FACING_ROWS[facing] * _sprite.hframes + step


func _unhandled_input(event: InputEvent) -> void:
	if Story.in_scene or not event.is_action_pressed(&"interact"):
		return

	var npc: Npc = _npc_in_reach()
	if npc != null and npc.talk(global_position):
		get_viewport().set_input_as_handled()


# Collapse the input to one axis so the player only walks in four directions.
# When both axes are held, keep walking along the axis already faced.
func _read_direction() -> Vector2:
	var input: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	var horizontal: Vector2 = Vector2(signf(input.x), 0.0)
	var vertical: Vector2 = Vector2(0.0, signf(input.y))
	if input.x == 0.0:
		return vertical
	if input.y == 0.0:
		return horizontal
	return horizontal if facing.x != 0.0 else vertical


func _npc_in_reach() -> Npc:
	# Fit the probe just past the body on the facing side, and narrower than the
	# body across it, so an NPC touching the player from behind or beside is not
	# picked up.
	var body_size: Vector2 = (_body.shape as RectangleShape2D).size
	var across: Vector2 = Vector2(absf(facing.y), absf(facing.x))
	var probe_size: Vector2 = across * (body_size - Vector2(2.0, 2.0)) + facing.abs() * PROBE_DEPTH
	(_talk_probe.shape as RectangleShape2D).size = probe_size
	_talk_probe.position = _body.position + facing * ((body_size + probe_size) / 2.0 + Vector2.ONE)
	_talk_probe.target_position = facing * REACH
	_talk_probe.force_shapecast_update()
	for i: int in _talk_probe.get_collision_count():
		var collider: Object = _talk_probe.get_collider(i)
		if collider is Npc:
			return collider as Npc
	return null
