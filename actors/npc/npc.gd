class_name Npc
extends StaticBody2D
## A character the player can talk to. Set the dialogue file and the cue to
## start from in the inspector, per NPC placed in a map.


## The dialogue file this character speaks from.
@export var dialogue_resource: DialogueResource
## The cue (a `~ name` line in the dialogue file) where the conversation starts.
@export var start_cue: String = "start"


## Open this character's conversation in the dialogue balloon.
func talk() -> void:
	DialogueManager.show_dialogue_balloon(dialogue_resource, start_cue)
