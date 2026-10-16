class_name SudokuInput
extends Node

## Translates the project's semantic-free key actions into this game's own
## vocabulary (CONSTITUTION 七).
##
## `digit_1` and `erase` were added to project.godot for this game -- they carry
## no meaning there, they only say which key went down. Here they become
## sudoku's "enter a digit" and "clear the cell".

const PREFIX := "sudoku_"

const UP := PREFIX + "up"
const DOWN := PREFIX + "down"
const LEFT := PREFIX + "left"
const RIGHT := PREFIX + "right"
const ERASE := PREFIX + "erase"
const PENCIL := PREFIX + "pencil"

## Semantic action -> the project-level key actions that feed it.
const BINDINGS := {
	UP: ["arrow_up", "wasd_up"],
	DOWN: ["arrow_down", "wasd_down"],
	LEFT: ["arrow_left", "wasd_left"],
	RIGHT: ["arrow_right", "wasd_right"],
	ERASE: ["erase"],
	PENCIL: ["key_z"],
}


static func digit_action(digit: int) -> String:
	return "%sdigit_%d" % [PREFIX, digit]


static func digit_key_action(digit: int) -> String:
	return "digit_%d" % digit


func _ready() -> void:
	_register(BINDINGS)
	for digit in range(1, SudokuBoard.SIZE + 1):
		_register({digit_action(digit): [digit_key_action(digit)]})


func _exit_tree() -> void:
	for semantic in BINDINGS:
		_remove(semantic)
	for digit in range(1, SudokuBoard.SIZE + 1):
		_remove(digit_action(digit))


func _register(map: Dictionary) -> void:
	for semantic in map:
		_remove(semantic)
		InputMap.add_action(semantic)
		for source in map[semantic]:
			for event in InputMap.action_get_events(source):
				InputMap.action_add_event(semantic, event)


func _remove(semantic: String) -> void:
	if InputMap.has_action(semantic):
		InputMap.erase_action(semantic)
