extends Node
## The player's running score. Dialogue files change it with lines like
## `do GameState.xp += 10`; the HUD listens to [signal changed].


## Emitted whenever [member xp] or [member money] changes.
signal changed

const STARTING_XP: int = 0
const STARTING_MONEY: int = 100

var xp: int = STARTING_XP:
	set(value):
		xp = value
		changed.emit()

var money: int = STARTING_MONEY:
	set(value):
		money = value
		changed.emit()


## Put the score back to its starting values.
func reset() -> void:
	xp = STARTING_XP
	money = STARTING_MONEY
