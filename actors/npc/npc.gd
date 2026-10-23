class_name Npc
extends StaticBody2D
## A character the player can talk to. Set [member character] to an id from
## content/scenes.json; the sprite and the name above it follow from that.
## Only the character who starts the current scene answers, with a marker
## bobbing above them; when their scene comes up they walk to its spot.


## How far the marker bobs, in pixels, and how fast.
const BOB_HEIGHT: float = 2.0
const BOB_SPEED: float = 4.0
const SPRITE_PATH: String = "res://art/placeholder/characters/%s.png"

## The character's id in content/scenes.json, such as "salma".
@export var character: String = ""

var _bob_time: float = 0.0

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _name_label: Label = $NameLabel
@onready var _marker: Node2D = $Marker
@onready var _marker_rest: Vector2 = _marker.position


func _ready() -> void:
	_sprite.texture = load(SPRITE_PATH % character) as Texture2D
	_name_label.text = Story.character_name(character)
	Story.scene_changed.connect(_refresh)
	_refresh()


func _process(delta: float) -> void:
	if _marker.visible:
		_bob_time += delta
		_marker.position = _marker_rest + Vector2(0.0, roundf(sin(_bob_time * BOB_SPEED) * BOB_HEIGHT))


## Start this character's scene, if it is the current one. Returns whether it started.
func talk() -> bool:
	return Story.talk_to(character)


func _refresh() -> void:
	var scene: Dictionary = Story.current_scene()
	var is_mine: bool = scene.get("character", "") == character
	_marker.visible = is_mine and not Story.in_scene
	if is_mine and not Story.in_scene:
		_go_to_spot(scene.spot)


# Stand at the named Marker2D under the map's Spots node, if the scene has one.
func _go_to_spot(spot: String) -> void:
	var map: Node = get_tree().current_scene
	if map == null or spot.is_empty():
		return
	var target: Node2D = map.get_node_or_null("Spots/" + spot) as Node2D
	if target != null:
		global_position = target.global_position
