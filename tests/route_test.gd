extends SceneTree
## Walks the player, with the movement keys, from the start to each scene's
## character in order, on the real map, and talks to them; then skips the scene
## and walks to the next. The route is the shortest one over free tiles, so it
## hugs walls and props. Fails if the player stops short of a tile on the way
## or the character does not answer. Exits non-zero on failure.
##
##   Godot --headless --path . --fixed-fps 60 -s tests/route_test.gd


const TILE_SIZE: int = 16
## The last scene a character starts; the ending after it starts on its own.
const LAST_SCENE: int = 9
## How close to a tile's centre counts as there, in pixels: under a frame's step.
const ARRIVED: float = 1.0
## Physics frames without moving before the player counts as stopped.
const STALL_FRAMES: int = 10
## The most physics frames one leg may take.
const LEG_FRAMES: int = 3000
const SETTLE_FRAMES: int = 5
const TIMEOUT_SECONDS: float = 300.0
const DIRECTIONS: Dictionary[Vector2i, StringName] = {
	Vector2i.LEFT: &"move_left", Vector2i.RIGHT: &"move_right", Vector2i.UP: &"move_up", Vector2i.DOWN: &"move_down",
}

var _story: Node
var _game_state: Node
var _map: Node
var _player: CharacterBody2D
var _problems: PackedStringArray = []


func _initialize() -> void:
	create_timer(TIMEOUT_SECONDS).timeout.connect(_on_timeout)
	_main.call_deferred()


func _main() -> void:
	# Autoloads are looked up at run time, since this script compiles before they exist.
	_story = root.get_node_or_null("Story")
	_game_state = root.get_node_or_null("GameState")
	if _story == null or _game_state == null:
		_finish(["the GameState or Story autoload is missing"])
		return
	_story.call(&"new_game", false)
	await _settle()
	_map = current_scene
	_player = _map.get_node("Actors/Player") as CharacterBody2D
	print("start at tile %s" % _tile_of(_player.global_position))
	for number: int in LAST_SCENE + 1:
		if not await _walk_to_scene(number):
			break
	# Close the map, then break the cycle the Dialogue Manager makes by storing
	# each dialogue resource in its own line data, so nothing leaks at exit.
	_story.call(&"restart")
	await _settle()
	current_scene.queue_free()
	await _settle()
	for scene: Dictionary in _story.get(&"scenes"):
		var resource: DialogueResource = load(scene.dialogue) as DialogueResource
		for line: Dictionary in resource.lines.values():
			line.erase(&"resource")
	_finish(_problems)


# Walk to scene [param number]'s character, talk, then skip the scene.
func _walk_to_scene(number: int) -> bool:
	var scene: Dictionary = _story.call(&"current_scene")
	var npc: Node2D = _npc(scene.character)
	if npc == null:
		_problems.append("scene %d: no character %s on the map" % [number, scene.character])
		return false
	var target: Vector2i = _tile_of(npc.global_position)
	var path: Array[Vector2i] = _route_beside(target)
	if path.is_empty():
		_problems.append("scene %d: no route from %s to beside %s at %s" % [number, _tile_of(_player.global_position), scene.character, target])
		return false
	for tile: Vector2i in path.slice(1):
		if not await _step_to(tile):
			_problems.append("scene %d: the player stopped at %s on the way to %s at %s, short of tile %s"
				% [number, _player.global_position.round(), scene.character, target, tile])
			return false
	# Face the character and press interact.
	var toward: Vector2i = target - path[-1]
	Input.action_press(DIRECTIONS[toward])
	await physics_frame
	await physics_frame
	Input.action_release(DIRECTIONS[toward])
	await physics_frame
	var press: InputEventAction = InputEventAction.new()
	press.action = &"interact"
	press.pressed = true
	Input.parse_input_event(press)
	await _settle()
	if not _story.get(&"in_scene"):
		_problems.append("scene %d: %s at %s did not answer the player at %s" % [number, scene.character, target, _player.global_position.round()])
		return false
	print("scene %d: walked %d tiles to %s at %s, who answered" % [number, path.size() - 1, scene.character, target])
	var release: InputEventAction = InputEventAction.new()
	release.action = &"interact"
	Input.parse_input_event(release)
	_story.call(&"skip_scene")
	await _settle()
	return true


# Hold the one key that leads to [param tile]'s centre until the player is there.
func _step_to(tile: Vector2i) -> bool:
	var goal: Vector2 = Vector2(tile * TILE_SIZE) + Vector2.ONE * TILE_SIZE / 2.0
	var here: Vector2i = _tile_of(_player.global_position)
	var direction: Vector2i = (tile - here).sign()
	var action: StringName = DIRECTIONS[direction]
	var last: Vector2 = _player.global_position
	var still: int = 0
	Input.action_press(action)
	for frame: int in LEG_FRAMES:
		await physics_frame
		var offset: Vector2 = goal - _player.global_position
		if absf(offset.x if direction.x != 0 else offset.y) <= ARRIVED or signf(offset.x if direction.x != 0 else offset.y) != float(direction.x + direction.y):
			break
		still = still + 1 if _player.global_position.is_equal_approx(last) else 0
		last = _player.global_position
		if still >= STALL_FRAMES:
			Input.action_release(action)
			return false
	Input.action_release(action)
	return true


# The shortest route over free tiles from the player's tile to a tile beside [param target].
func _route_beside(target: Vector2i) -> Array[Vector2i]:
	var grid: AStarGrid2D = AStarGrid2D.new()
	var used: Rect2i = Rect2i()
	var layers: Array[TileMapLayer] = []
	for node: Node in _map.find_children("*", "TileMapLayer", true, false):
		layers.append(node as TileMapLayer)
		used = used.merge((node as TileMapLayer).get_used_rect())
	grid.region = used
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	for layer: TileMapLayer in layers:
		for cell: Vector2i in layer.get_used_cells():
			var data: TileData = layer.get_cell_tile_data(cell)
			if data != null and data.get_collision_polygons_count(0) > 0:
				grid.set_point_solid(cell)
	for npc: Node2D in _npcs():
		grid.set_point_solid(_tile_of(npc.global_position))
	var from: Vector2i = _tile_of(_player.global_position)
	var best: Array[Vector2i] = []
	for side: Vector2i in DIRECTIONS.keys():
		var beside: Vector2i = target + side
		if not grid.is_in_boundsv(beside) or grid.is_point_solid(beside):
			continue
		var path: Array[Vector2i] = grid.get_id_path(from, beside)
		if not path.is_empty() and (best.is_empty() or path.size() < best.size()):
			best = path
	return best


func _npc(character: String) -> Node2D:
	for npc: Node2D in _npcs():
		if npc.get(&"character") == character:
			return npc
	return null


# The characters on the map. Npc is not named, since its script needs the
# autoloads, which do not exist when this script compiles.
func _npcs() -> Array[Node2D]:
	var found: Array[Node2D] = []
	for node: Node in _map.get_node("Actors").get_children():
		if node is StaticBody2D and node.get(&"character") is String:
			found.append(node as Node2D)
	return found


func _tile_of(at: Vector2) -> Vector2i:
	return Vector2i((at / TILE_SIZE).floor())


func _settle() -> void:
	for i: int in SETTLE_FRAMES:
		await process_frame


func _finish(problems: PackedStringArray) -> void:
	if problems.is_empty():
		print("PASS: the player walked to every scene's character")
		quit(0)
		return
	for problem: String in problems:
		printerr("FAIL: " + problem)
	quit(1)


func _on_timeout() -> void:
	printerr("FAIL: timed out after %.0f seconds" % TIMEOUT_SECONDS)
	quit(2)
