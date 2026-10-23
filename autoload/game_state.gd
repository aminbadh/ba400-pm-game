extends Node
## The state of the centre's project: four meters, the story flags, the room's
## votes and how far the story has got. Dialogue files change it with lines like
## `do GameState.integrity += 10` and `do GameState.set_flag("raci_clear")`;
## the dashboard listens to [signal changed].


## Emitted whenever anything in the state changes.
signal changed

## Where Integrity, Fairness and Team start, out of 100.
const METER_START: int = 60
## The most a meter can hold.
const METER_MAX: int = 100
## Budget in TND, where it starts and the most it can hold.
const BUDGET_START: int = 3000
## The four meters, in the order the dashboard shows them.
const METERS: Array[String] = ["integrity", "fairness", "team", "budget"]
## A meter below this, on a 0 to 100 scale, puts the centre in the news.
const NEWS_BELOW: int = 30
## Every meter at or above this, on a 0 to 100 scale, makes a smooth session.
const SMOOTH_FROM: int = 60
## The three endings, as [method ending] names them.
const ENDING_SMOOTH: String = "smooth"
const ENDING_STRAINED: String = "strained"
const ENDING_NEWS: String = "news"

var integrity: int = METER_START:
	set(value):
		integrity = clampi(value, 0, METER_MAX)
		changed.emit()

var fairness: int = METER_START:
	set(value):
		fairness = clampi(value, 0, METER_MAX)
		changed.emit()

var team: int = METER_START:
	set(value):
		team = clampi(value, 0, METER_MAX)
		changed.emit()

var budget: int = BUDGET_START:
	set(value):
		budget = clampi(value, 0, BUDGET_START)
		changed.emit()

## Set on the title screen: the 20-minute path that drops the optional moments.
var short_mode: bool = false

## The story flags that are set, as keys (the values are always true).
var flags: Dictionary[String, bool] = {}
## The room's vote in each scene, by scene number: "A", "B" or "C".
## A scene with no entry was not voted (skipped, or optional in short mode).
var votes: Dictionary[int, String] = {}
## The cards the player has been shown, by number, in the order first shown.
var cards: Array[int] = []
## Scene 4's inspection calls, by candidate index: true when the call was right.
var inspection_calls: Dictionary[int, bool] = {}
## The scene to play next, 0 to 10; 11 once the story is over.
var scene: int = 0

## True once scene 3 has put the dashboard on screen.
var dashboard_shown: bool = false
## The meters the chosen metrics light up; the others stay greyed out.
var lit_meters: Array[String] = []
## True once the ending shows the dashboard's real values.
var dashboard_revealed: bool = false


## Put everything back to how a new game starts. Keeps [member short_mode].
func reset() -> void:
	integrity = METER_START
	fairness = METER_START
	team = METER_START
	budget = BUDGET_START
	flags = {}
	votes = {}
	cards = []
	inspection_calls = {}
	scene = 0
	dashboard_shown = false
	lit_meters = []
	dashboard_revealed = false
	changed.emit()


func set_flag(flag: String) -> void:
	flags[flag] = true
	changed.emit()


func has_flag(flag: String) -> bool:
	return flags.has(flag)


## Record the option the room chose in a scene's vote.
func record_vote(scene_number: int, option: String) -> void:
	votes[scene_number] = option
	changed.emit()


## True if the room chose [param option] in [param scene_number]'s vote.
func voted(scene_number: int, option: String) -> bool:
	return votes.get(scene_number, "") == option


## Add a card to the binder.
func collect_card(number: int) -> void:
	if number not in cards:
		cards.append(number)
		changed.emit()


## Put the dashboard on screen, every meter greyed out until [method light_meter].
func show_dashboard() -> void:
	dashboard_shown = true
	changed.emit()


## Light up one meter on the dashboard: "integrity", "fairness", "team" or "budget".
func light_meter(meter: String) -> void:
	assert(meter in METERS, "unknown meter: " + meter)
	if meter not in lit_meters:
		lit_meters.append(meter)
		changed.emit()


## From now on the dashboard shows the true values, even with metrics_passrate.
func reveal_dashboard() -> void:
	dashboard_revealed = true
	changed.emit()


## A meter's value on a 0 to 100 scale; Budget is scaled against its start.
func scaled(meter: String) -> int:
	match meter:
		"integrity":
			return integrity
		"fairness":
			return fairness
		"team":
			return team
		"budget":
			return roundi(budget * 100.0 / BUDGET_START)
	assert(false, "unknown meter: " + meter)
	return 0


## Which ending the meters lead to: [constant ENDING_NEWS] if any meter is below
## 30, [constant ENDING_SMOOTH] if every meter is 60 or above, else
## [constant ENDING_STRAINED].
func ending() -> String:
	var lowest: int = METER_MAX
	for meter: String in METERS:
		lowest = mini(lowest, scaled(meter))
	if lowest < NEWS_BELOW:
		return ENDING_NEWS
	if lowest >= SMOOTH_FROM:
		return ENDING_SMOOTH
	return ENDING_STRAINED


## Everything a skipped scene could have changed, for [method restore].
func snapshot() -> Dictionary:
	return {
		"integrity": integrity,
		"fairness": fairness,
		"team": team,
		"budget": budget,
		"flags": flags.duplicate(),
		"votes": votes.duplicate(),
		"cards": cards.duplicate(),
		"inspection_calls": inspection_calls.duplicate(),
		"dashboard_shown": dashboard_shown,
		"lit_meters": lit_meters.duplicate(),
		"dashboard_revealed": dashboard_revealed,
	}


## Undo every change made since [param saved] was taken with [method snapshot].
func restore(saved: Dictionary) -> void:
	integrity = saved.integrity
	fairness = saved.fairness
	team = saved.team
	budget = saved.budget
	flags = saved.flags
	votes = saved.votes
	cards = saved.cards
	inspection_calls = saved.inspection_calls
	dashboard_shown = saved.dashboard_shown
	lit_meters = saved.lit_meters
	dashboard_revealed = saved.dashboard_revealed
	changed.emit()
