class_name SokobanInput
extends Node

## Translates the project's semantic-free key actions into this game's own
## vocabulary (CONSTITUTION 七).

const PREFIX := "sokoban_"

const UP := PREFIX + "up"
const DOWN := PREFIX + "down"
const LEFT := PREFIX + "left"
const RIGHT := PREFIX + "right"
const UNDO := PREFIX + "undo"
const RESTART := PREFIX + "restart"

const BINDINGS := {
	UP: ["arrow_up", "wasd_up"],
	DOWN: ["arrow_down", "wasd_down"],
	LEFT: ["arrow_left", "wasd_left"],
	RIGHT: ["arrow_right", "wasd_right"],
	UNDO: ["key_z"],
	RESTART: ["erase"],
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
