class_name BejeweledInput
extends Node

## Translates the project's semantic-free key actions into this game's own
## vocabulary (CONSTITUTION 七).

const PREFIX := "gems_"

const LEFT := PREFIX + "left"
const RIGHT := PREFIX + "right"
const UP := PREFIX + "up"
const DOWN := PREFIX + "down"
const SELECT := PREFIX + "select"

const BINDINGS := {
	LEFT: ["arrow_left", "wasd_left"],
	RIGHT: ["arrow_right", "wasd_right"],
	UP: ["arrow_up", "wasd_up"],
	DOWN: ["arrow_down", "wasd_down"],
	SELECT: ["fire", "key_z"],
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
