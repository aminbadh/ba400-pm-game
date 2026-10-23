class_name Stage
extends CanvasLayer


func present_card(_card: Dictionary) -> void:
	pass


func present_exhibit(_name: String, _exhibit: Dictionary, _variant: String) -> void:
	pass


func inspect_candidate(_index: int, _inspection: Dictionary) -> bool:
	return true


func show_inspection_result(_index: int, _inspection: Dictionary, _right: bool) -> void:
	pass


func end_inspection() -> void:
	pass


func set_backdrop(_title: String, _body: String) -> void:
	pass


func cancel() -> void:
	pass
