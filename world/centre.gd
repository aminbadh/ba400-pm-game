extends Node2D
## The exam centre: the gate, the courtyard, the admin office, Room 12, the
## staff room and the deposit room. Names each place from content/scenes.json,
## on a dark plate on the wall beside its door.
##
## The tile layers are filled by tools/build_map.py; edit the layout there.


func _ready() -> void:
	for label: Label in $Places.get_children():
		label.text = Story.places.get(label.name, label.name)
		UiStyle.put_on_plate(label)
