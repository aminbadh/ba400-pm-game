extends Node
## Runs the story: loads the content files, starts each scene's dialogue when the
## player talks to its character, and gives the dialogue its calls for showing
## cards, exhibits, the inspection, the binder, the region's report and the
## last screen. Dialogue files call it with lines like `do Story.show_card(2)`.
##
## The screens themselves belong to the stage, the binder and the dashboard in the
## map scene, which register here. With nothing registered (the headless tests),
## every call that would wait for the presenter returns at once.


## Emitted when the current scene changes or a scene starts or ends.
signal scene_changed
## Emitted when scene 3 points at the dashboard strip, so it flashes.
signal dashboard_flashed

const CARDS_PATH: String = "res://content/cards.json"
const EXHIBITS_PATH: String = "res://content/exhibits.json"
const INSPECTION_PATH: String = "res://content/inspection.json"
const SCENES_PATH: String = "res://content/scenes.json"
const REPORT_PATH: String = "res://content/report.json"
const TITLE_SCENE: String = "res://ui/title/title.tscn"
const MAP_SCENE: String = "res://world/centre.tscn"
## The font every screen uses, at [constant FONT_SIZE]. It is put in the
## default theme at run time rather than in a project theme, so a first import
## does not load it before the font is imported. [Glyphs] adds the icons it lacks.
const FONT_PATH: String = "res://fonts/ark-pixel-10px-proportional-latin.ttf"
const FONT_SIZE: int = 10
## The cue every scene's dialogue starts from.
const START_CUE: String = "start"
## The scene played after the last one, when the story is over.
const STORY_OVER: int = 11
## The exam day and the ending, which each have their own music.
const EXAM_DAY_SCENE: int = 9
const ENDING_SCENE: int = 10
## The ending's cues for the debrief and the last screen, where skipping the
## ending goes instead of leaving its title on screen.
const DEBRIEF_CUE: String = "debrief"
const LAST_SCREEN_CUE: String = "last_screen"
## The scene whose debrief card shows the gate inspection instead of a vote.
const INSPECTION_SCENE: int = 4
## Each speaking character's three portraits, side by side, in [constant EXPRESSIONS] order.
const PORTRAIT_PATH: String = "res://art/portraits/%s.png"
const PORTRAIT_SIZE: int = 48
## The expressions a dialogue line can ask for with a tag, such as [#worried];
## a line with none shows the first.
const EXPRESSIONS: Array[String] = ["neutral", "worried", "pleased"]
## The letters of a vote's options, in order.
const LETTERS: String = "ABC"

## The nine concept cards, in order, as in cards.json.
var cards: Array[Dictionary] = []
## What a debrief shows for a vote that was not taken.
var not_voted_text: String = ""
## What a debrief puts before the room's option, with {letter}, and before the best one.
var you_chose_text: String = ""
var best_text: String = ""
## The charter, organisational chart, RACI chart and histogram, by name.
var exhibits: Dictionary = {}
## The gate checklist and the five rehearsal candidates.
var inspection: Dictionary = {}
## The region's report: its title and the charter's success criteria.
var report_content: Dictionary = {}
## Scenes 0 to 10, in order.
var scenes: Array[Dictionary] = []
## Each character's name and colour, by id; "player" is the centre head.
var characters: Dictionary = {}
## The centre head and the eight characters, in the order the last screen lines them up.
var cast: Array = []
## Each place's name, by id.
var places: Dictionary = {}

## The screen that shows cards, exhibits, the inspection and the backdrop.
## Null when headless; set by the stage itself.
var stage: Stage = null
## The binder screen, null when headless; set by the binder itself.
var binder: Binder = null
## When no stage is registered, the inspection uses these calls in order:
## true admits the candidate, false stops them. The tests fill it.
var scripted_inspection: Array[bool] = []
## Every card shown, in order, repeats included.
var shown_cards: Array[int] = []

## True while a scene's dialogue is running.
var in_scene: bool = false
## Whether the game makes any sound: the music and the characters' voices. A
## presenter's setting, on by default and kept across restarts; the pause menu switches it.
var sound_on: bool = true:
	set(value):
		sound_on = value
		Music.set_sound(value)

var _running_scene: int = -1
var _running_dialogue: DialogueResource = null
var _balloon: Node = null
var _snapshot: Dictionary = {}
## True once the ending has opened the debrief.
var _debrief_started: bool = false


func _ready() -> void:
	var theme: Theme = ThemeDB.get_default_theme()
	var font: FontFile = load(FONT_PATH) as FontFile
	font.fallbacks = [Glyphs.font(font, FONT_SIZE)]
	theme.default_font = font
	theme.default_font_size = FONT_SIZE
	_load_content()
	sound_on = sound_on
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)


#region Scenes


## The scene the player should play next, or an empty dictionary when the story is over.
func current_scene() -> Dictionary:
	if GameState.scene < scenes.size():
		return scenes[GameState.scene]
	return {}


## True if talking to [param character] starts the current scene.
func is_next_character(character: String) -> bool:
	return not in_scene and current_scene().get("character", "") == character


## Start the current scene if [param character] is the one who starts it.
func talk_to(character: String) -> bool:
	if not is_next_character(character):
		return false
	start_scene(GameState.scene)
	return true


## Start scene [param number]'s dialogue in the balloon, from [param cue].
func start_scene(number: int, cue: String = START_CUE) -> void:
	var scene: Dictionary = scenes[number]
	_snapshot = GameState.snapshot()
	_running_scene = number
	_running_dialogue = load(scene.dialogue) as DialogueResource
	in_scene = true
	Music.play(track_for_scene(number))
	_balloon = DialogueManager.show_dialogue_balloon(_running_dialogue, cue)
	scene_changed.emit()


## The music for scene [param number]: the map's until exam day, then exam
## day's, then the end theme from the ending on.
func track_for_scene(number: int) -> String:
	if number >= ENDING_SCENE:
		return Music.END_TRACK
	if number == EXAM_DAY_SCENE:
		return Music.EXAM_DAY_TRACK
	return Music.MAP_TRACK


## Abandon the current scene, undoing its effects, and move to the next one.
## Its vote stays unrecorded, so the debrief shows it as not voted. The ending
## has no vote to undo: skipping it goes on to the debrief, then the last screen.
func skip_scene() -> void:
	if GameState.scene >= STORY_OVER:
		return
	if in_scene and _running_scene == ENDING_SCENE:
		var cue: String = LAST_SCREEN_CUE if _debrief_started else DEBRIEF_CUE
		_close_dialogue()
		backdrop("")
		start_scene(_running_scene, cue)
		return
	if in_scene:
		_close_dialogue()
		GameState.restore(_snapshot)
	_finish_scene()


## Back to the title screen with a fresh state.
func restart() -> void:
	_close_dialogue()
	_reset_story()
	Music.stop()
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE_SCENE)


## Start a new game from scene 0.
func new_game() -> void:
	_close_dialogue()
	_reset_story()
	Music.play(track_for_scene(0))
	get_tree().change_scene_to_file(MAP_SCENE)


# Forget every scene in progress, so a new game starts from scene 0.
func _reset_story() -> void:
	GameState.reset()
	shown_cards.clear()
	_running_scene = -1
	_running_dialogue = null
	_snapshot = {}
	_debrief_started = false


func _close_dialogue() -> void:
	if is_instance_valid(_balloon):
		_balloon.queue_free()
	_balloon = null
	if stage != null:
		stage.cancel()
	if binder != null:
		binder.cancel()
	# A card closed by a skip never says so itself.
	Music.fade_in()
	in_scene = false


func _finish_scene() -> void:
	var finished: int = _running_scene if _running_scene >= 0 else GameState.scene
	_running_scene = -1
	_running_dialogue = null
	in_scene = false
	GameState.scene = finished + 1
	scene_changed.emit()
	# A scene with no character (the ending) starts on its own.
	var next: Dictionary = current_scene()
	if not next.is_empty() and next.character.is_empty():
		start_scene.call_deferred(GameState.scene)


func _on_dialogue_ended(resource: DialogueResource) -> void:
	if in_scene and resource == _running_dialogue:
		_balloon = null
		# Deferred, so the key press that closed the balloon cannot start another talk.
		_finish_scene.call_deferred()


#endregion

#region Calls from dialogue


## Show concept card [param number] full screen until the presenter presses
## interact, and add it to the binder. The music fades out while it shows.
func show_card(number: int) -> void:
	var card: Dictionary = card_by_number(number)
	assert(not card.is_empty(), "no card %d in %s" % [number, CARDS_PATH])
	GameState.collect_card(number)
	shown_cards.append(number)
	if stage != null:
		Music.fade_out()
		await stage.present_card(card)
		Music.fade_in()


## Show an exhibit (the charter, a chart) full screen until the presenter presses
## interact. [param variant] picks a version of it, such as "levelled". The
## music fades out while the charter, which has pages like a card, shows.
func show_exhibit(exhibit_name: String, variant: String = "") -> void:
	assert(exhibits.has(exhibit_name), "no exhibit %s in %s" % [exhibit_name, EXHIBITS_PATH])
	if stage != null:
		var paged: bool = (exhibits[exhibit_name] as Dictionary).has("pages")
		if paged:
			Music.fade_out()
		await stage.present_exhibit(exhibit_name, exhibits[exhibit_name], variant)
		if paged:
			Music.fade_in()


## Open the binder as a read-only overview of the nine cards, until the presenter goes on.
func open_overview() -> void:
	if binder != null:
		await binder.open_overview()


## Point at the dashboard strip: it flashes.
func flash_dashboard() -> void:
	dashboard_flashed.emit()


## Run scene 4's gate inspection: five candidates, each admitted or stopped.
func run_inspection() -> void:
	var candidates: Array = inspection.candidates
	for i: int in candidates.size():
		var admit: bool
		if stage != null:
			admit = await stage.inspect_candidate(i, inspection)
		else:
			assert(not scripted_inspection.is_empty(), "no scripted inspection call for candidate %d" % i)
			admit = scripted_inspection.pop_front()
		judge_candidate(i, admit)
		if stage != null:
			await stage.show_inspection_result(i, inspection, is_right_call(i, admit))
	if stage != null:
		stage.end_inspection()


## True if admitting (or stopping) candidate [param index] is the right call.
func is_right_call(index: int, admit: bool) -> bool:
	var answer: String = inspection.candidates[index].answer
	return (answer == "admit") == admit


## Apply the effect of one inspection call to the meters, and set the
## candidate's [code]admit_flag[/code] when they are admitted. Returns whether it was right.
func judge_candidate(index: int, admit: bool) -> bool:
	var right: bool = is_right_call(index, admit)
	var effects: Dictionary = inspection.correct if right else inspection.miss
	for meter: String in effects:
		GameState.set(meter, GameState.get(meter) + int(effects[meter]))
	var flag: String = inspection.candidates[index].get("admit_flag", "")
	if admit and not flag.is_empty():
		GameState.set_flag(flag)
	GameState.inspection_calls[index] = right
	return right


## Put a full-screen backdrop behind the dialogue, with a title; an empty
## title removes it.
func backdrop(title: String) -> void:
	if stage != null:
		stage.set_backdrop(title)


## Show the region's report on the charter's success criteria, until the presenter goes on.
func show_report() -> void:
	if stage != null:
		await stage.present_report(report_content.title, report())


## Show the last screen: the cast waving on the courtyard, [param title] and
## [param subtitle] above them, [param body] and [param closing] below.
func show_last_screen(title: String, subtitle: String, body: String, closing: String) -> void:
	if stage != null:
		stage.show_last_screen(title, subtitle, body, closing)


## Open the binder as the debrief until the presenter closes it.
func open_debrief() -> void:
	_debrief_started = true
	if binder != null:
		await binder.open_debrief()


#endregion

#region Content


## Card [param number] from cards.json, or an empty dictionary.
func card_by_number(number: int) -> Dictionary:
	for card: Dictionary in cards:
		if int(card.number) == number:
			return card
	return {}


## The text of option [param letter] in scene [param scene]'s vote, as its
## dialogue file writes it, or an empty string if it has no such option.
func option_text(scene: int, letter: String) -> String:
	var resource: DialogueResource = load(scenes[scene].dialogue) as DialogueResource
	var index: int = LETTERS.find(letter)
	for line: Dictionary in resource.lines.values():
		var options: Array = line.get(&"responses", [])
		if line.get(&"type", "") == "response" and not options.is_empty():
			return resource.lines[options[index]].text if index >= 0 and index < options.size() else ""
	return ""


## What the debrief shows for [param card], as up to three lines, each empty
## when it does not apply: [code]chose[/code], the room's option ("You chose
## B: ...") or "Not voted"; [code]line[/code], the line for that choice, or
## the gate inspection's count of right calls for card 5; and [code]best[/code],
## the best choice ("Best: ...").
func debrief_rows(card: Dictionary) -> Dictionary:
	var scene: int = int(card.scene)
	if scene == INSPECTION_SCENE:
		if GameState.inspection_calls.is_empty():
			return { "chose": not_voted_text, "line": "", "best": "" }
		var right: int = GameState.inspection_calls.values().count(true)
		var total: int = (inspection.candidates as Array).size()
		return { "chose": "", "line": (card.debrief_inspection as String).format({ "right": right, "total": total }), "best": "" }
	var best: String = "%s %s" % [best_text, card.best]
	var vote: String = GameState.votes.get(scene, "")
	if vote.is_empty():
		return { "chose": not_voted_text, "line": "", "best": best }
	var chose: String = "%s %s" % [you_chose_text.format({ "letter": vote }), option_text(scene, vote)]
	return { "chose": chose, "line": card.debrief[vote], "best": best }


## The region's report for the state the story ends in: one entry per success
## criterion that applies, each with its [code]criterion[/code], whether it
## was [code]met[/code], and the [code]lines[/code] that explain it.
func report() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for criterion: Dictionary in report_content.criteria:
		var only_with: String = criterion.get("only_with", "")
		if not only_with.is_empty() and not GameState.has_flag(only_with):
			continue
		var reasons: Array[String] = []
		for reason: Dictionary in criterion.reasons:
			var applies: bool = GameState.budget <= 0 if reason.get("budget_spent", false) else GameState.has_flag(reason.get("flag", ""))
			if applies:
				reasons.append(reason.text)
		var lines: Array[String] = reasons.duplicate()
		if reasons.is_empty():
			lines = [(criterion.met as String).format({ "budget": GameState.budget })]
			var also: Dictionary = criterion.get("met_also", {})
			for flag: String in also.get("flags", []):
				if GameState.has_flag(flag):
					lines.append(also.text)
					break
		entries.append({ "criterion": criterion.criterion, "met": reasons.is_empty(), "lines": lines })
	return entries


## A character's display name, or the id if it has none.
func character_name(character: String) -> String:
	return characters.get(character, {}).get("name", character)


## The id of the character whose display name is [param display_name], or an
## empty string for a speaker who is not a character, such as a time on exam day.
func character_id(display_name: String) -> String:
	for id: String in characters:
		if characters[id].name == display_name:
			return id
	return ""


## A character's colour from content/scenes.json, or the panel colour.
func character_color(character: String) -> Color:
	return Color(characters.get(character, {}).get("color", Palette.PANEL_RAISED.to_html(false)) as String)


## Character [param character]'s portrait in the expression named by one of
## [param tags], or neutral; null for a speaker with no portrait.
func portrait(character: String, tags: PackedStringArray) -> Texture2D:
	var path: String = PORTRAIT_PATH % character
	if character.is_empty() or not ResourceLoader.exists(path):
		return null
	var index: int = 0
	for tag: String in tags:
		if tag in EXPRESSIONS:
			index = EXPRESSIONS.find(tag)
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = load(path) as Texture2D
	atlas.region = Rect2(index * PORTRAIT_SIZE, 0, PORTRAIT_SIZE, PORTRAIT_SIZE)
	return atlas


func _load_content() -> void:
	var card_data: Dictionary = _load_json(CARDS_PATH)
	cards.assign(card_data.cards)
	not_voted_text = card_data.not_voted
	you_chose_text = card_data.you_chose
	best_text = card_data.best
	exhibits = _load_json(EXHIBITS_PATH)
	inspection = _load_json(INSPECTION_PATH)
	report_content = _load_json(REPORT_PATH)
	var scene_data: Dictionary = _load_json(SCENES_PATH)
	scenes.assign(scene_data.scenes)
	characters = scene_data.characters
	cast = scene_data.cast
	places = scene_data.places


# Content files are loaded as resources, so they also work in an exported build.
func _load_json(path: String) -> Dictionary:
	var json: JSON = load(path) as JSON
	assert(json != null, "could not load " + path)
	return json.data as Dictionary


#endregion
