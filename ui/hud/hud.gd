extends CanvasLayer
## Shows the player's XP and money in the top-left corner.


@onready var _xp_label: Label = %XpLabel
@onready var _money_label: Label = %MoneyLabel


func _ready() -> void:
	GameState.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	_xp_label.text = "XP %d" % GameState.xp
	_money_label.text = "$%d" % GameState.money
