extends Node
## The background music: one track at a time, looping, crossfaded when the
## track changes, quiet under speech on its own bus. Story picks the track for
## each scene and fades the music out while a concept card or the charter is
## on screen. The pause menu's Sound switch mutes the music and the
## characters' voices together.
##
## Each track is one constant: change the file name to swap it.


const MAP_TRACK: String = "res://art/ninja_adventure/Audio/Musics/33 - Calm Village.ogg"
const EXAM_DAY_TRACK: String = "res://art/ninja_adventure/Audio/Musics/28 - Tension.ogg"
const END_TRACK: String = "res://art/ninja_adventure/Audio/Musics/8 - End Theme.ogg"
## The music's bus and the characters' voices' bus, made here if the project has none.
const MUSIC_BUS: StringName = &"Music"
const VOICE_BUS: StringName = &"Voice"
## The music's level, quiet under speech.
const VOLUME_DB: float = -18.0
## A level that cannot be heard, where fades start and end.
const SILENT_DB: float = -80.0
const CROSSFADE_SECONDS: float = 1.0
const FADE_SECONDS: float = 1.0

## The track playing, or an empty string for none.
var current_track: String = ""
## True while a card or the charter has the music faded out.
var faded_out: bool = false

var _players: Array[AudioStreamPlayer] = []
var _active: int = 0
var _crossfade: Tween = null
var _fade: Tween = null


func _ready() -> void:
	# The music goes on while the binder or the pause menu holds the game.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus: StringName in [MUSIC_BUS, VOICE_BUS]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	_set_music_volume(VOLUME_DB)
	for i: int in 2:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = MUSIC_BUS
		player.volume_db = SILENT_DB
		add_child(player)
		_players.append(player)


## Crossfade to [param track], looping; an empty string fades the music out.
## Asking for the track already playing changes nothing.
func play(track: String) -> void:
	if track == current_track:
		return
	current_track = track
	var old: AudioStreamPlayer = _players[_active]
	_active = 1 - _active
	var new: AudioStreamPlayer = _players[_active]
	new.stop()
	if not track.is_empty():
		var stream: AudioStreamOggVorbis = load(track) as AudioStreamOggVorbis
		stream.loop = true
		new.stream = stream
		new.volume_db = SILENT_DB
		new.play()
	if _crossfade != null:
		_crossfade.kill()
	_crossfade = create_tween().set_parallel()
	_crossfade.tween_property(new, "volume_db", 0.0, CROSSFADE_SECONDS)
	_crossfade.tween_property(old, "volume_db", SILENT_DB, CROSSFADE_SECONDS)
	_crossfade.chain().tween_callback(old.stop)


## Stop the music, fading it out.
func stop() -> void:
	play("")


## Fade the music out, for a card on screen.
func fade_out() -> void:
	faded_out = true
	_fade_to(SILENT_DB)


## Fade the music back in after [method fade_out].
func fade_in() -> void:
	if not faded_out:
		return
	faded_out = false
	_fade_to(VOLUME_DB)


## Mute or unmute the music and the voices together.
func set_sound(on: bool) -> void:
	for bus: StringName in [MUSIC_BUS, VOICE_BUS]:
		AudioServer.set_bus_mute(AudioServer.get_bus_index(bus), not on)


## True if [param bus] is muted.
func is_muted(bus: StringName) -> bool:
	return AudioServer.is_bus_mute(AudioServer.get_bus_index(bus))


## The music bus's level now, in dB.
func music_volume() -> float:
	return AudioServer.get_bus_volume_db(AudioServer.get_bus_index(MUSIC_BUS))


func _fade_to(volume: float) -> void:
	if _fade != null:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_method(_set_music_volume, music_volume(), volume, FADE_SECONDS)


func _set_music_volume(volume: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(MUSIC_BUS), volume)
