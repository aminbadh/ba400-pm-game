extends SceneTree
## Walks one branch of dialogue/test.dialogue through the Dialogue Manager API
## and checks the score it leaves behind. Exits non-zero on failure.
##
##   Godot --headless --path . -s tests/smoke_test.gd


const DIALOGUE_PATH: String = "res://dialogue/test.dialogue"
## Which response to pick at each choice, by index: C, then A.
const CHOICES: Array[int] = [2, 0]
const EXPECTED_XP: int = 20
const EXPECTED_MONEY: int = 130
## Give up after this many lines, in case the dialogue loops.
const MAX_LINES: int = 50


func _initialize() -> void:
	_main.call_deferred()


func _main() -> void:
	var failure: String = await _walk()
	# Let the Dialogue Manager's deferred signals flush, so nothing leaks at exit.
	await process_frame
	if failure.is_empty():
		print("PASS")
		quit(0)
	else:
		printerr("FAIL: " + failure)
		quit(1)


## Walk the dialogue and return what went wrong, or an empty string.
func _walk() -> String:
	# Autoloads are looked up at run time, since this script compiles before they exist.
	var game_state: Node = root.get_node("GameState")
	var dialogue_manager: Node = root.get_node("DialogueManager")
	var resource: DialogueResource = load(DIALOGUE_PATH)
	game_state.call(&"reset")

	var choices: Array[int] = CHOICES.duplicate()
	var line: DialogueLine = await dialogue_manager.call(&"get_next_dialogue_line", resource, "start")
	var count: int = 0
	while line != null and count < MAX_LINES:
		count += 1
		if line.responses.is_empty():
			print("  %s: %s" % [line.character, line.text])
			line = await dialogue_manager.call(&"get_next_dialogue_line", resource, line.next_id)
		else:
			if choices.is_empty():
				return "more choices than expected at: %s" % line.text
			var response: DialogueResponse = line.responses[choices.pop_front()]
			print("  %s: %s\n  -> %s" % [line.character, line.text, response.text])
			line = await dialogue_manager.call(&"get_next_dialogue_line", resource, response.next_id)

	var xp: int = game_state.get(&"xp")
	var money: int = game_state.get(&"money")
	print("xp=%d money=%d" % [xp, money])
	if line != null:
		return "dialogue did not end within %d lines" % MAX_LINES
	if not choices.is_empty():
		return "dialogue ended before all choices were made"
	if xp != EXPECTED_XP or money != EXPECTED_MONEY:
		return "expected xp=%d money=%d" % [EXPECTED_XP, EXPECTED_MONEY]
	return ""
