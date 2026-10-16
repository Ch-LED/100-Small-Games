class_name PipesInput
extends Node

## Translates the project's semantic-free key actions into this game's own
## vocabulary (CONSTITUTION 七).
##
## This is a mouse game -- the drawing is a drag and nothing else does it well.
## The keyboard is here for the two things a drag cannot do: take a line back,
## and take a whole colour off the board.

const PREFIX := "pipes_"

const ERASE := PREFIX + "erase"
const UNDO := PREFIX + "undo"

const BINDINGS := {
	ERASE: ["erase"],
	UNDO: ["key_z"],
}


func _ready() -> void:
	for semantic in BINDINGS:
		if InputMap.has_action(semantic):
			InputMap.erase_action(semantic)
		InputMap.add_action(semantic)
		for source in BINDINGS[semantic]:
			for event in InputMap.action_get_events(source):
				InputMap.action_add_event(semantic, event)


func _exit_tree() -> void:
	for semantic in BINDINGS:
		if InputMap.has_action(semantic):
			InputMap.erase_action(semantic)
