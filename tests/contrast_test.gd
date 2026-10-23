extends SceneTree
## Checks the WCAG contrast ratio of every text colour the UI draws on its
## background: the pairs in Palette.TEXT_PAIRS, each vote card's letter on its
## card, and each character's name on its name plate. Prints every pair with its
## ratio and exits non-zero if any is under Palette.MIN_CONTRAST (7:1).
##
##   Godot --headless --path . -s tests/contrast_test.gd


const SCENES_PATH: String = "res://content/scenes.json"


func _initialize() -> void:
	var failures: int = 0
	for pair: Dictionary in Palette.TEXT_PAIRS:
		failures += _check(pair.use, pair.text, pair.background)
	for card: Dictionary in Palette.VOTE_CARDS:
		failures += _check("vote card %s letter" % card.letter, card.text, card.card)
	var characters: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string(SCENES_PATH)) as Dictionary).characters
	for id: String in characters:
		var plate: Dictionary = Palette.name_plate(Color(characters[id].color as String))
		failures += _check("dialogue name plate: %s" % characters[id].name, plate.text, plate.plate)
	if failures > 0:
		printerr("FAIL: %d text colour pairs under %.0f:1" % [failures, Palette.MIN_CONTRAST])
		quit(1)
		return
	print("PASS: every text colour pair is %.0f:1 or more" % Palette.MIN_CONTRAST)
	quit(0)


# Print one pair with its ratio; returns 1 if it fails.
func _check(use: String, text: Color, background: Color) -> int:
	var ratio: float = Palette.contrast(text, background)
	var passed: bool = ratio >= Palette.MIN_CONTRAST
	print("%5.2f:1  %s  #%s on #%s  %s" % [ratio, "ok  " if passed else "FAIL", text.to_html(false), background.to_html(false), use])
	return 0 if passed else 1
