extends SceneTree
## Plays the whole story through the Dialogue Manager API three times with fixed
## votes, one run per ending, and checks the final meters, flags, ending, the
## cards shown again after wrong answers, and the debrief. Exits non-zero on failure.
##
##   Godot --headless --path . -s tests/story_test.gd


## Each run: the mode, the room's vote per scene, the gate inspection calls
## (true admits), and what the state must be at the end.
const RUNS: Array[Dictionary] = [
	{
		"name": "smooth, Full mode",
		"short": false,
		"votes": { 0: "B", 1: "B", 2: "A", 3: "B", 5: "B", 6: "A", 7: "A", 8: "B" },
		"inspection": [true, false, false, true, false],
		"integrity": 100, "fairness": 75, "team": 100, "budget": 2400,
		"flags": ["room12_fixed", "metrics_exam", "raci_clear", "staff_borrowed", "staff_protected"],
		"cards": [1, 2, 3, 4, 5, 6, 7, 8, 9],
		"inspection_debrief": "You made 5 of 5 calls right against the checklist. It catches what memory misses.",
		"ending": "smooth",
	},
	{
		"name": "strained, Full mode",
		"short": false,
		"votes": { 0: "A", 1: "B", 2: "C", 3: "A", 5: "A", 6: "B", 7: "C", 8: "A" },
		"inspection": [true, true, false, false, false],
		"integrity": 40, "fairness": 75, "team": 75, "budget": 2700,
		"flags": ["room12_fixed", "metrics_people", "raci_double", "staff_thin", "staff_trained"],
		"cards": [1, 1, 2, 3, 3, 4, 5, 6, 6, 7, 8, 9],
		"inspection_debrief": "You made 3 of 5 calls right against the checklist. It catches what memory misses.",
		"ending": "strained",
	},
	{
		"name": "in the news, Short mode",
		"short": true,
		"votes": { 1: "A", 3: "C", 4: "C", 6: "C", 7: "C", 8: "C" },
		"inspection": [],
		"integrity": 2, "fairness": 55, "team": 60, "budget": 1500,
		"flags": ["room12_fixed", "metrics_passrate", "raci_none", "staff_thin", "bought_tech"],
		"cards": [1, 2, 2, 3, 4, 5, 5, 6, 7, 8, 9],
		"ending": "news",
	},
]
const LETTERS: String = "ABC"
const METERS: Array[String] = ["integrity", "fairness", "team", "budget"]
## Give up on a scene after this many lines, in case its dialogue loops.
const MAX_LINES: int = 200
## Exit 2 after this many seconds, in case a run dies on an error and never quits.
const TIMEOUT_SECONDS: float = 30.0
## What a check returns when it passed. Success must be explicit: a coroutine
## that dies on a runtime error hands its caller an empty value.
const PASSED: String = "passed"

var _game_state: Node
var _story: Node
var _dialogue_manager: Node


func _initialize() -> void:
	create_timer(TIMEOUT_SECONDS).timeout.connect(_on_timeout)
	_main.call_deferred()


func _main() -> void:
	# Autoloads are looked up at run time, since this script compiles before they exist.
	_game_state = root.get_node_or_null("GameState")
	_story = root.get_node_or_null("Story")
	_dialogue_manager = root.get_node_or_null("DialogueManager")
	if _game_state == null or _story == null or _dialogue_manager == null:
		_finish(["the GameState, Story or DialogueManager autoload is missing"])
		return

	var failures: Array[String] = []
	for run: Dictionary in RUNS:
		print("== Run: %s" % run.name)
		var result: String = await _play(run)
		if result == PASSED:
			print("PASS: %s" % run.name)
		else:
			failures.append("%s: %s" % [run.name, "a script error stopped the run" if result.is_empty() else result])
	# Let the Dialogue Manager's deferred signals flush, and break the cycle it
	# makes by storing each dialogue resource in its own line data, so nothing
	# leaks at exit.
	await process_frame
	for scene: Dictionary in _story.get(&"scenes"):
		var resource: DialogueResource = load(scene.dialogue) as DialogueResource
		for line: Dictionary in resource.lines.values():
			line.erase(&"resource")
	_finish(failures)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("PASS: all %d runs" % RUNS.size())
		quit(0)
		return
	for failure: String in failures:
		printerr("FAIL: " + failure)
	quit(1)


## Play scenes 0 to 10 with the run's votes and return what went wrong, or [constant PASSED].
func _play(run: Dictionary) -> String:
	_game_state.set(&"short_mode", run.short)
	_game_state.call(&"reset")
	(_story.get(&"shown_cards") as Array).clear()
	var calls: Array[bool] = []
	calls.assign(run.inspection)
	_story.set(&"scripted_inspection", calls)

	var scenes: Array = _story.get(&"scenes")
	for scene: Dictionary in scenes:
		var number: int = int(scene.number)
		var result: String = await _play_scene(number, scene.dialogue, run.votes.get(number, ""))
		if result != PASSED:
			return "scene %d: %s" % [number, "a script error stopped it" if result.is_empty() else result]
		_game_state.set(&"scene", number + 1)
	return _check(run)


## Play one scene's dialogue, picking [param vote] at its choice, if any.
func _play_scene(number: int, path: String, vote: String) -> String:
	var resource: DialogueResource = load(path) as DialogueResource
	if resource == null:
		return "could not load " + path
	var line: DialogueLine = await _dialogue_manager.call(&"get_next_dialogue_line", resource, "start")
	var count: int = 0
	var voted: bool = false
	while line != null and count < MAX_LINES:
		count += 1
		if line.responses.is_empty():
			print("  %s%s" % ["" if line.character.is_empty() else line.character + ": ", line.text])
			line = await _dialogue_manager.call(&"get_next_dialogue_line", resource, line.next_id)
			continue
		if vote.is_empty() or voted:
			return "a vote nobody planned for: %s" % line.text
		var index: int = LETTERS.find(vote)
		if index < 0 or index >= line.responses.size():
			return "no option %s at: %s" % [vote, line.text]
		var response: DialogueResponse = line.responses[index]
		print("  VOTE %s -> %s %s" % [line.text, vote, response.text])
		voted = true
		line = await _dialogue_manager.call(&"get_next_dialogue_line", resource, response.next_id)
	if line != null:
		return "the dialogue did not end within %d lines" % MAX_LINES
	if not vote.is_empty() and not voted:
		return "the planned vote %s never came" % vote
	if not vote.is_empty() and not _game_state.call(&"voted", number, vote):
		return "vote %s was not recorded" % vote
	return PASSED


func _check(run: Dictionary) -> String:
	var problems: PackedStringArray = []
	var values: PackedStringArray = []
	for meter: String in METERS:
		var value: int = _game_state.get(meter)
		values.append("%s=%d" % [meter, value])
		if value != int(run[meter]):
			problems.append("%s is %d, expected %d" % [meter, value, int(run[meter])])
	var ending: String = _game_state.call(&"ending")
	var flags: Array = (_game_state.get(&"flags") as Dictionary).keys()
	var cards: Array = _story.get(&"shown_cards")
	print("  %s ending=%s" % [" ".join(values), ending])
	print("  flags=%s" % [flags])
	print("  cards shown=%s" % [cards])

	if ending != run.ending:
		problems.append("ending is %s, expected %s" % [ending, run.ending])
	var expected_flags: Array = run.flags.duplicate()
	expected_flags.sort()
	flags.sort()
	if flags != expected_flags:
		problems.append("flags are %s, expected %s" % [flags, expected_flags])
	if cards != run.cards:
		problems.append("cards shown are %s, expected %s" % [cards, run.cards])
	if (_game_state.get(&"cards") as Array).size() != 9:
		problems.append("the binder does not hold all nine cards")

	# The debrief: each card's line follows the room's vote, or says it was not voted.
	var not_voted: String = _story.get(&"not_voted_text")
	for card: Dictionary in _story.get(&"cards"):
		var line: String = _story.call(&"debrief_line", card)
		var vote: String = run.votes.get(int(card.scene), "")
		var expected: String = not_voted if vote.is_empty() else card.debrief[vote]
		if run.short == false and int(card.scene) == 4:
			expected = run.inspection_debrief
		if line != expected:
			problems.append("debrief for card %d is \"%s\", expected \"%s\"" % [int(card.number), line, expected])
		print("  debrief %d: %s" % [int(card.number), line])

	if not problems.is_empty():
		return "; ".join(problems)
	return PASSED


func _on_timeout() -> void:
	printerr("FAIL: timed out after %.0f seconds" % TIMEOUT_SECONDS)
	quit(2)
