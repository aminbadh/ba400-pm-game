class_name Npc
extends StaticBody2D
## A character the player can talk to. Set [member character] to an id from
## content/scenes.json; the sprite and the name above it follow from that.
## It stands facing down, and turns to face the player who talks to it.
## Only the character who starts the current scene answers, with a marker
## bobbing above them; when their scene comes up they jump to its spot, or to
## the nearest free tile when someone already stands there.


## How far the marker bobs, in pixels, and how fast.
const BOB_HEIGHT: float = 2.0
const BOB_SPEED: float = 4.0
const SPRITE_PATH: String = "res://art/characters/%s.png"
## The sprite sheet's rows, by facing: down, left, right, up.
const FACING_ROWS: Dictionary[Vector2, int] = { Vector2.DOWN: 0, Vector2.LEFT: 1, Vector2.RIGHT: 2, Vector2.UP: 3 }
const TILE_SIZE: float = 16.0
## How many tiles from a blocked spot to look for a free one.
const SEARCH_TILES: int = 3

## The character's id in content/scenes.json, such as "salma".
@export var character: String = ""

var _bob_time: float = 0.0

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _name_label: Label = $NameLabel
@onready var _marker: Node2D = $Marker
@onready var _marker_rest: Vector2 = _marker.position
@onready var _body: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	_sprite.texture = load(SPRITE_PATH % character) as Texture2D
	_name_label.text = Story.character_name(character)
	UiStyle.put_on_plate(_name_label)
	Story.scene_changed.connect(_refresh)
	_refresh()


func _process(delta: float) -> void:
	if _marker.visible:
		_bob_time += delta
		_marker.position = _marker_rest + Vector2(0.0, roundf(sin(_bob_time * BOB_SPEED) * BOB_HEIGHT))


## Start this character's scene, if it is the current one, turning to face
## [param from], where the player stands. Returns whether it started.
func talk(from: Vector2) -> bool:
	if not Story.talk_to(character):
		return false
	face(from - global_position)
	return true


## Turn to the one of the four directions closest to [param direction].
func face(direction: Vector2) -> void:
	var facing: Vector2 = Vector2.DOWN
	if absf(direction.x) > absf(direction.y):
		facing = Vector2.RIGHT if direction.x > 0.0 else Vector2.LEFT
	elif direction.y < 0.0:
		facing = Vector2.UP
	_sprite.frame = FACING_ROWS[facing] * _sprite.hframes


func _refresh() -> void:
	var scene: Dictionary = Story.current_scene()
	var is_mine: bool = scene.get("character", "") == character
	_marker.visible = is_mine and not Story.in_scene
	if not Story.in_scene:
		face(Vector2.DOWN)
	if is_mine and not Story.in_scene:
		_go_to_spot(scene.spot)


# Stand at the named Marker2D under the map's Spots node, if the scene has one.
func _go_to_spot(spot: String) -> void:
	var map: Node = get_tree().current_scene
	if map == null or spot.is_empty():
		return
	var target: Node2D = map.get_node_or_null("Spots/" + spot) as Node2D
	if target != null:
		global_position = _nearest_free(target.global_position)


# [param spot] if this character fits there, else the nearest tile centre where
# its body touches no wall, player or other character, so it never lands on the
# player after a skip. Keeps [param spot] if no tile nearby is free.
func _nearest_free(spot: Vector2) -> Vector2:
	var offsets: Array[Vector2] = []
	for x: int in range(-SEARCH_TILES, SEARCH_TILES + 1):
		for y: int in range(-SEARCH_TILES, SEARCH_TILES + 1):
			offsets.append(Vector2(x, y) * TILE_SIZE)
	offsets.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.length_squared() < b.length_squared())
	for offset: Vector2 in offsets:
		if _fits_at(spot + offset):
			return spot + offset
	return spot


func _fits_at(at: Vector2) -> bool:
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = _body.shape
	query.transform = Transform2D(0.0, at + _body.position)
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()
