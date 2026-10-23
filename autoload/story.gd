extends Node
## Runs the story: loads the content files, starts each scene's dialogue when the
## player talks to its character, and gives the dialogue its calls for showing
## cards, exhibits, the inspection, the binder and the ending. Dialogue files call
## it with lines like `do Story.show_card(2)`.
##
## The screens themselves belong to the stage, the binder and the dashboard in the
## map scene, which register here. With nothing registered (the headless tests),
## every call that would wait for the presenter returns at once.


## Emitted when the current scene changes or a scene starts or ends.
signal scene_changed

const CARDS_PATH: String = "res://content/cards.json"
const EXHIBITS_PATH: String = "res://content/exhibits.json"
const INSPECTION_PATH: String = "res://content/inspection.json"
const SCENES_PATH: String = "res://content/scenes.json"
const TITLE_SCENE: String = "res://ui/title/title.tscn"
const MAP_SCENE: String = "res://world/centre.tscn"
## The font every screen uses, at [constant FONT_SIZE]. It is put in the
## default theme at run time rather than in a project theme, so a first import
## does not load it before the font is imported.
const FONT_PATH: String = "res://fonts/ark-pixel-10px-proportional-latin.ttf"
const FONT_SIZE: int = 10
## The cue every scene's dialogue starts from.
const START_CUE: String = "start"
## The scene played after the last one, when the story is over.
const STORY_OVER: int = 11
## The ending's cues for the debrief and the last screen, where skipping the
## ending goes instead of leaving its title on screen.
const DEBRIEF_CUE: String = "debrief"
const LAST_SCREEN_CUE: String = "last_screen"

## The nine concept cards, in order, as in cards.json.
var cards: Array[Dictionary] = []
## What a debrief shows for a vote that was not taken.
var not_voted_text: String = ""
## The charter, organisational chart, RACI chart and histogram, by name.
var exhibits: Dictionary = {}
## The gate checklist and the five rehearsal candidates.
var inspection: Dictionary = {}
## Scenes 0 to 10, in order.
var scenes: Array[Dictionary] = []
## Each character's name and colour, by id.
var characters: Dictionary = {}
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

var _running_scene: int = -1
var _running_dialogue: DialogueResource = null
var _balloon: Node = null
var _snapshot: Dictionary = {}
## True once the ending has opened the debrief.
var _debrief_started: bool = false


func _ready() -> void:
	var theme: Theme = ThemeDB.get_default_theme()
	theme.default_font = load(FONT_PATH) as Font
	theme.default_font_size = FONT_SIZE
	_load_content()
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
	_balloon = DialogueManager.show_dialogue_balloon(_running_dialogue, cue)
	scene_changed.emit()


## Abandon the current scene, undoing its effects, and move to the next one.
## Its vote stays unrecorded, so the debrief shows it as not voted. The ending
## has no vote to undo: skipping it goes on to the debrief, then the last screen.
func skip_scene() -> void:
	if GameState.scene >= STORY_OVER:
		return
	if in_scene and _running_scene == STORY_OVER - 1:
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
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE_SCENE)


## Start a new game in Full or Short mode.
func new_game(short_mode: bool) -> void:
	_close_dialogue()
	GameState.short_mode = short_mode
	_reset_story()
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
## interact, and add it to the binder.
func show_card(number: int) -> void:
	var card: Dictionary = card_by_number(number)
	assert(not card.is_empty(), "no card %d in %s" % [number, CARDS_PATH])
	GameState.collect_card(number)
	shown_cards.append(number)
	if stage != null:
		await stage.present_card(card)


## Show an exhibit (the charter, a chart) full screen until the presenter presses
## interact. [param variant] picks a version of it, such as "levelled".
func show_exhibit(exhibit_name: String, variant: String = "") -> void:
	assert(exhibits.has(exhibit_name), "no exhibit %s in %s" % [exhibit_name, EXHIBITS_PATH])
	if stage != null:
		await stage.present_exhibit(exhibit_name, exhibits[exhibit_name], variant)


## Open the binder as the quest log until the presenter closes it.
func open_quest_log() -> void:
	if binder != null:
		await binder.open_quest_log()


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


## Apply the effect of one inspection call to the meters. Returns whether it was right.
func judge_candidate(index: int, admit: bool) -> bool:
	var right: bool = is_right_call(index, admit)
	var effects: Dictionary = inspection.correct if right else inspection.miss
	for meter: String in effects:
		GameState.set(meter, GameState.get(meter) + int(effects[meter]))
	GameState.inspection_calls[index] = right
	return right


## Put a full-screen backdrop behind the dialogue, with a title and an optional
## body; an empty title and body remove it.
func backdrop(title: String, body: String = "") -> void:
	if stage != null:
		stage.set_backdrop(title, body)


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


## The debrief line for a card: the line for the room's vote in its scene, or
## [member not_voted_text].
func debrief_line(card: Dictionary) -> String:
	var scene: int = int(card.scene)
	var vote: String = GameState.votes.get(scene, "")
	if vote.is_empty():
		if scene == 4 and not GameState.inspection_calls.is_empty():
			return card.debrief_inspection
		return not_voted_text
	return card.debrief[vote]


## A character's display name, or the id if it has none.
func character_name(character: String) -> String:
	return characters.get(character, {}).get("name", character)


func _load_content() -> void:
	var card_data: Dictionary = _load_json(CARDS_PATH)
	cards.assign(card_data.cards)
	not_voted_text = card_data.not_voted
	exhibits = _load_json(EXHIBITS_PATH)
	inspection = _load_json(INSPECTION_PATH)
	var scene_data: Dictionary = _load_json(SCENES_PATH)
	scenes.assign(scene_data.scenes)
	characters = scene_data.characters
	places = scene_data.places


# Content files are loaded as resources, so they also work in an exported build.
func _load_json(path: String) -> Dictionary:
	var json: JSON = load(path) as JSON
	assert(json != null, "could not load " + path)
	return json.data as Dictionary


#endregion
