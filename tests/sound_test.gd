extends SceneTree
## Checks the music and the sound switch on the real map: with Sound off the
## music and voice buses are muted, and on they are not; the map's track plays
## from scene 0, exam day's in scene 9 and the end theme from the ending; and
## the music fades out while a card is on screen and back in when it closes.
## Exits non-zero on failure.
##
##   Godot --headless --path . -s tests/sound_test.gd


const SETTLE_FRAMES: int = 5
## Longer than a fade or a crossfade.
const FADE_WAIT_SECONDS: float = 1.3
## How close to a level counts as there, in dB.
const LEVEL_TOLERANCE: float = 1.0
const TIMEOUT_SECONDS: float = 30.0

var _story: Node
var _music: Node
var _problems: PackedStringArray = []


func _initialize() -> void:
	create_timer(TIMEOUT_SECONDS).timeout.connect(_on_timeout)
	_main.call_deferred()


func _main() -> void:
	# Autoloads are looked up at run time, since this script compiles before they exist.
	_story = root.get_node_or_null("Story")
	_music = root.get_node_or_null("Music")
	if _story == null or _music == null:
		_finish(["the Story or Music autoload is missing"])
		return
	_story.call(&"new_game")
	await _settle()
	_check_sound_switch()
	await _check_tracks()
	await _check_card_fade()
	_story.call(&"restart")
	await _settle()
	_music.call(&"silence")
	await _settle()
	for scene: Dictionary in _story.get(&"scenes"):
		var resource: DialogueResource = load(scene.dialogue) as DialogueResource
		for line: Dictionary in resource.lines.values():
			line.erase(&"resource")
	_finish(_problems)


# Sound off mutes the music and the voices; on, neither is muted. On by default.
func _check_sound_switch() -> void:
	print("== Sound switch")
	var buses: Array[StringName] = [_music.get(&"MUSIC_BUS"), _music.get(&"VOICE_BUS")]
	_expect(_story.get(&"sound_on"), "Sound is not on by default")
	for on: bool in [false, true]:
		_story.set(&"sound_on", on)
		for bus: StringName in buses:
			var muted: bool = _music.call(&"is_muted", bus)
			print("  Sound %s: %s bus muted %s" % ["on" if on else "off", bus, muted])
			_expect(muted != on, "with Sound %s the %s bus is %smuted" % ["on" if on else "off", bus, "" if muted else "not "])


# Each scene's track: the map's from scene 0, exam day's in scene 9, the end
# theme from the ending, which starts on its own after scene 9.
func _check_tracks() -> void:
	print("== Tracks")
	var game_state: Node = root.get_node("GameState")
	await _expect_track(0, _music.get(&"MAP_TRACK"))
	for number: int in [0, 3, 8]:
		game_state.set(&"scene", number)
		_story.call(&"start_scene", number)
		await _settle()
		await _expect_track(number, _music.get(&"MAP_TRACK"))
		_story.call(&"skip_scene")
		await _settle()
	game_state.set(&"scene", 9)
	_story.call(&"start_scene", 9)
	await _settle()
	await _expect_track(9, _music.get(&"EXAM_DAY_TRACK"))
	# Skipping exam day starts the ending.
	_story.call(&"skip_scene")
	await _settle()
	await _expect_track(10, _music.get(&"END_TRACK"))


func _expect_track(scene: int, track: String) -> void:
	await create_timer(FADE_WAIT_SECONDS).timeout
	var playing: String = ""
	for player: AudioStreamPlayer in _music.get(&"_players"):
		if player.playing and player.stream != null and player.volume_db > -LEVEL_TOLERANCE:
			playing = player.stream.resource_path
	print("  scene %d: playing %s" % [scene, playing.get_file()])
	_expect(playing == track, "scene %d plays %s, not %s" % [scene, playing.get_file(), track.get_file()])


# A card fades the music out; closing it fades the music back in.
func _check_card_fade() -> void:
	print("== A card on screen")
	var stage: Node = _story.get(&"stage")
	if stage == null:
		_problems.append("the map's stage did not register with Story")
		return
	var level: float = _music.get(&"VOLUME_DB")
	var silent: float = _music.get(&"SILENT_DB")
	_story.call(&"show_card", 1)
	await create_timer(FADE_WAIT_SECONDS).timeout
	var during: float = _music.call(&"music_volume")
	print("  during the card: music at %.1f dB" % during)
	_expect(absf(during - silent) < LEVEL_TOLERANCE, "the music is at %.1f dB during a card, not faded out to %.1f" % [during, silent])
	# The presenter closes the card.
	while (stage.get(&"_card_view") as Control).visible:
		stage.call(&"_next_page")
		await _settle()
	await create_timer(FADE_WAIT_SECONDS).timeout
	var after: float = _music.call(&"music_volume")
	print("  after the card: music at %.1f dB" % after)
	_expect(absf(after - level) < LEVEL_TOLERANCE, "the music is at %.1f dB after the card, not back to %.1f" % [after, level])


func _expect(ok: bool, problem: String) -> void:
	if not ok:
		_problems.append(problem)


func _settle() -> void:
	for i: int in SETTLE_FRAMES:
		await process_frame


func _finish(problems: PackedStringArray) -> void:
	if problems.is_empty():
		print("PASS: music and sound")
		quit(0)
		return
	for problem: String in problems:
		printerr("FAIL: " + problem)
	quit(1)


func _on_timeout() -> void:
	printerr("FAIL: timed out after %.0f seconds" % TIMEOUT_SECONDS)
	quit(2)
