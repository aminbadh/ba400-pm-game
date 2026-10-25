extends SceneTree
## Plays the whole story through the Dialogue Manager API with fixed votes, one
## run per ending plus one that skips scene 8, and checks the final meters, flags,
## ending, the cards shown again after wrong answers, the debrief's three lines,
## the region's report, and lines that must or must not show. Exits non-zero on failure.
##
##   Godot --headless --path . -s tests/story_test.gd


## Each run: the room's vote per scene, the scenes skipped (started, then
## skipped with Story.skip_scene, as the pause menu does), the gate inspection calls (true
## admits), what the state must be at the end, the region's report as
## [criterion, met, lines], and lines that must or must not show, as
## "speaker: text" or text alone.
const RUNS: Array[Dictionary] = [
	{
		"name": "smooth",
		"votes": { 0: "C", 1: "A", 2: "B", 3: "C", 5: "B", 6: "A", 7: "C", 8: "C" },
		# The meters lit once scene 3 ends, sorted: Budget whatever the room picks.
		"lit": ["budget", "fairness", "integrity"],
		"inspection": [true, false, false, true, false],
		"integrity": 100, "fairness": 75, "team": 100, "budget": 2400,
		"flags": ["room12_fixed", "metrics_exam", "raci_clear", "staff_borrowed", "staff_protected"],
		"cards": [1, 2, 3, 4, 5, 6, 7, 8, 9],
		"inspection_debrief": "You made 5 of 5 calls right against the checklist. It catches what memory misses.",
		"ending": "smooth",
		"report": [
			["Every paper starts on time", true, ["Every envelope signed and opened on time."]],
			["No paper leaves its envelope early, and the exam stays secure", true, ["Envelopes sealed, devices kept out.", "The earpiece was caught."]],
			["Every candidate can sit every paper, special arrangements included", true, ["Nour had her quiet desk and her extra time."]],
			["The centre stays within budget", true, ["Within budget: 2400 TND left."]],
		],
		"present": ["7:30, the gate: The checklist works as well as the rehearsal went.", "Meters not lit stay greyed out with \"?\" until the ending."],
		"absent": ["7:30, the gate: Two phones get in.", "The dashboard: It shows green all day, whatever happened."],
	},
	{
		"name": "strained",
		"votes": { 0: "A", 1: "A", 2: "C", 3: "B", 5: "A", 6: "B", 7: "A", 8: "B" },
		# The meters lit once scene 3 ends, sorted: Budget whatever the room picks.
		"lit": ["budget", "team"],
		"inspection": [true, true, false, false, false],
		"integrity": 40, "fairness": 75, "team": 75, "budget": 2700,
		"flags": ["room12_fixed", "metrics_people", "raci_double", "staff_thin", "staff_trained"],
		"cards": [1, 1, 2, 3, 3, 4, 5, 6, 6, 7, 8, 9],
		"inspection_debrief": "You made 3 of 5 calls right against the checklist. It catches what memory misses.",
		"ending": "strained",
		"report": [
			["Every paper starts on time", false, ["The escort waited twenty minutes: each signer thought the other had signed."]],
			["No paper leaves its envelope early, and the exam stays secure", false, ["A smartwatch was missed in a thin room."]],
			["Every candidate can sit every paper, special arrangements included", true, ["Nour had her quiet desk and her extra time."]],
			["The centre stays within budget", true, ["Within budget: 2700 TND left."]],
		],
		"present": ["7:30, the gate: The checklist works as well as the rehearsal went."],
		"absent": ["7:30, the gate: Two phones get in."],
	},
	{
		"name": "in the news",
		"votes": { 0: "B", 1: "B", 2: "A", 3: "A", 5: "C", 6: "C", 7: "B", 8: "A" },
		# The meters lit once scene 3 ends, sorted: Budget whatever the room picks.
		"lit": ["budget", "fairness", "integrity", "team"],
		# The switched-off phone is admitted, which lets two phones in on exam day.
		"inspection": [true, true, true, false, true],
		"integrity": 20, "fairness": 40, "team": 60, "budget": 1500,
		"flags": ["room12_fixed", "metrics_passrate", "phone_admitted", "raci_none", "rooms_crowded", "bought_tech"],
		"cards": [1, 1, 2, 2, 3, 3, 4, 5, 6, 6, 7, 8, 9],
		"inspection_debrief": "You made 1 of 5 calls right against the checklist. It catches what memory misses.",
		"ending": "news",
		"report": [
			["Every paper starts on time", true, ["Every envelope signed and opened on time."]],
			["No paper leaves its envelope early, and the exam stays secure", false, ["An envelope sat unsigned on a desk.", "Two phones got in at the gate.", "The earpiece went unnoticed."]],
			["Every candidate can sit every paper, special arrangements included", false, ["Nour lost her quiet desk in a crowded room."]],
			["The centre stays within budget", true, ["Within budget: 1500 TND left."]],
			["The dashboard told the truth", false, ["Your dashboard showed green all day, on a number the centre didn't control."]],
		],
		"present": ["7:30, the gate: The checklist works as well as the rehearsal went.", "7:30, the gate: Two phones get in.", "The dashboard: It shows green all day, whatever happened."],
		"absent": ["Meters not lit stay greyed out with \"?\" until the ending."],
	},
	{
		"name": "scene 8 skipped",
		"votes": { 0: "C", 1: "A", 2: "B", 3: "C", 5: "B", 6: "A", 7: "C" },
		# The meters lit once scene 3 ends, sorted: Budget whatever the room picks.
		"lit": ["budget", "fairness", "integrity"],
		"skip": [8],
		"inspection": [true, false, false, true, false],
		"integrity": 95, "fairness": 75, "team": 80, "budget": 2400,
		"flags": ["room12_fixed", "metrics_exam", "raci_clear", "staff_borrowed"],
		"cards": [1, 2, 3, 4, 5, 6, 7, 8],
		"inspection_debrief": "You made 5 of 5 calls right against the checklist. It catches what memory misses.",
		"ending": "smooth",
		"report": [
			["Every paper starts on time", true, ["Every envelope signed and opened on time."]],
			["No paper leaves its envelope early, and the exam stays secure", true, ["Envelopes sealed, devices kept out."]],
			["Every candidate can sit every paper, special arrangements included", true, ["Nour had her quiet desk and her extra time."]],
			["The centre stays within budget", true, ["Within budget: 2400 TND left."]],
		],
		# Scene 9's 10:15 beat shows only when scene 8 set a flag.
		"present": [],
		"absent": ["10:15, an incident: A candidate is found with an earpiece."],
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
## Every speaker whose line showed in the current run.
var _speakers: Array[String] = []
## Every line that showed in the current run, as "speaker: text" or text alone.
var _lines: Array[String] = []


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
	_game_state.call(&"reset")
	(_story.get(&"shown_cards") as Array).clear()
	var calls: Array[bool] = []
	calls.assign(run.inspection)
	_story.set(&"scripted_inspection", calls)

	_speakers.clear()
	_lines.clear()
	var scenes: Array = _story.get(&"scenes")
	for scene: Dictionary in scenes:
		var number: int = int(scene.number)
		if number in run.get("skip", []):
			# As the pause menu does: start the scene, then skip it.
			_story.call(&"start_scene", number)
			for i: int in 3:
				await process_frame
			_story.call(&"skip_scene")
			for i: int in 3:
				await process_frame
			print("  (scene %d skipped; next scene %d)" % [number, _game_state.get(&"scene")])
			if _game_state.get(&"scene") != number + 1 or _story.get(&"in_scene"):
				return "skipping scene %d left the story at scene %d" % [number, _game_state.get(&"scene")]
			continue
		var result: String = await _play_scene(number, scene.dialogue, run.votes.get(number, ""))
		if result != PASSED:
			return "scene %d: %s" % [number, "a script error stopped it" if result.is_empty() else result]
		if number == 3:
			var lit: Array = (_game_state.get(&"lit_meters") as Array).duplicate()
			lit.sort()
			print("  lit after scene 3=%s" % [lit])
			if lit != run.lit:
				return "after scene 3 the lit meters are %s, expected %s" % [lit, run.lit]
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
			_speakers.append(line.character)
			_lines.append(line.text if line.character.is_empty() else "%s: %s" % [line.character, line.text])
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
	var collected: Array = (_game_state.get(&"cards") as Array).duplicate()
	collected.sort()
	var expected_collected: Array = []
	for number: int in run.cards:
		if number not in expected_collected:
			expected_collected.append(number)
	expected_collected.sort()
	if collected != expected_collected:
		problems.append("the binder holds cards %s, expected %s" % [collected, expected_collected])
	for line: String in run.present:
		if line not in _lines:
			problems.append("the line \"%s\" never showed" % line)
	for line: String in run.absent:
		if line in _lines:
			problems.append("the line \"%s\" showed" % line)

	# The debrief: the room's option, the line for it and the best choice, or
	# "Not voted" and the best choice; the inspection's count for card 5.
	var not_voted: String = _story.get(&"not_voted_text")
	for card: Dictionary in _story.get(&"cards"):
		var rows: Dictionary = _story.call(&"debrief_rows", card)
		var scene: int = int(card.scene)
		var vote: String = run.votes.get(scene, "")
		var expected: Dictionary
		if scene == 4:
			expected = { "chose": "", "line": run.inspection_debrief, "best": "" }
		elif vote.is_empty():
			expected = { "chose": not_voted, "line": "", "best": "Best: " + card.best }
		else:
			var option: String = _story.call(&"option_text", scene, vote)
			expected = { "chose": "You chose %s: %s" % [vote, option], "line": card.debrief[vote], "best": "Best: " + card.best }
			if option.is_empty():
				problems.append("scene %d has no option %s" % [scene, vote])
		if rows != expected:
			problems.append("debrief for card %d is %s, expected %s" % [int(card.number), rows, expected])
		print("  debrief %d: %s | %s | %s" % [int(card.number), rows.chose, rows.line, rows.best])

	# The region's report: each criterion that applies, met or not, with its lines.
	var report: Array = []
	for entry: Dictionary in _story.call(&"report"):
		report.append([entry.criterion, entry.met, entry.lines])
		print("  report %s %s: %s" % ["met" if entry.met else "NOT met", entry.criterion, " ".join(entry.lines)])
	if str(report) != str(run.report):
		problems.append("the report is %s, expected %s" % [report, run.report])

	if not problems.is_empty():
		return "; ".join(problems)
	return PASSED


func _on_timeout() -> void:
	printerr("FAIL: timed out after %.0f seconds" % TIMEOUT_SECONDS)
	quit(2)
