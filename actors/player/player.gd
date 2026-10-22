class_name Player
extends CharacterBody2D
## The project manager. Walks in four directions and talks to the NPC it faces.


## Walking speed in pixels per second.
const SPEED: float = 64.0
## How far in front of the player's centre it can reach an NPC.
const REACH: float = 10.0

## The direction the player last moved in, one of the four unit vectors.
var facing: Vector2 = Vector2.DOWN

var _is_talking: bool = false

## Sweeps a small box from the player's centre towards [member facing].
@onready var _talk_probe: ShapeCast2D = $TalkProbe


func _ready() -> void:
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)


func _physics_process(_delta: float) -> void:
	if _is_talking:
		velocity = Vector2.ZERO
		return

	var direction: Vector2 = _read_direction()
	if direction != Vector2.ZERO:
		facing = direction
	velocity = direction * SPEED
	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if _is_talking or not event.is_action_pressed(&"interact"):
		return

	var npc: Npc = _npc_in_reach()
	if npc == null or npc.dialogue_resource == null:
		return

	get_viewport().set_input_as_handled()
	_is_talking = true
	npc.talk()


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
	_talk_probe.target_position = facing * REACH
	_talk_probe.force_shapecast_update()
	for i: int in _talk_probe.get_collision_count():
		var collider: Object = _talk_probe.get_collider(i)
		if collider is Npc:
			return collider as Npc
	return null


func _on_dialogue_ended(_resource: DialogueResource) -> void:
	# Deferred, so the key press that closed the balloon cannot reopen it.
	set_deferred(&"_is_talking", false)
