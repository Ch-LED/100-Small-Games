class_name TetrisInput
extends Node

## Translates the project's semantic-free key actions into this game's own
## vocabulary (CONSTITUTION 七).
##
## project.godot only says which key went down -- `key_z`, `arrow_left`, `fire`.
## What those mean is the game's business, and this node is where that meaning
## is written down. The rest of the code reads only the `tetris_*` names, so
## the key binding lives in exactly one place.
##
## The events are copied, not aliased: InputMap has no notion of one action
## pointing at another.

const PREFIX := "tetris_"

const MOVE_LEFT := PREFIX + "move_left"
const MOVE_RIGHT := PREFIX + "move_right"
const SOFT_DROP := PREFIX + "soft_drop"
const HARD_DROP := PREFIX + "hard_drop"
const ROTATE_CW := PREFIX + "rotate_cw"
const ROTATE_CCW := PREFIX + "rotate_ccw"
const HOLD := PREFIX + "hold"
## Landing preview. Separate from P's overlay on purpose: the preview is
## something a player reads while playing, the overlay is read while working
## out why the game did something.
const TOGGLE_GHOST := PREFIX + "toggle_ghost"

## Semantic action -> the project-level key actions that feed it.
const BINDINGS := {
	MOVE_LEFT: ["arrow_left", "wasd_left"],
	MOVE_RIGHT: ["arrow_right", "wasd_right"],
	SOFT_DROP: ["arrow_down", "wasd_down"],
	HARD_DROP: ["fire"],
	ROTATE_CW: ["key_x", "arrow_up", "wasd_up"],
	ROTATE_CCW: ["key_z"],
	HOLD: ["key_c"],
	TOGGLE_GHOST: ["key_q"],
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
