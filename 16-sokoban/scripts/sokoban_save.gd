class_name SokobanSave
extends Node

## How far the run has got, and the fewest moves each cleared level took.
##
## Three things can be wrong with the file and all three fall back to an empty
## store rather than refusing to start: it is not there yet, it is not
## something this game wrote, or a different version wrote it. `loaded` says
## which happened, so the menu can admit it (spec 10).

const PATH := "user://sokoban.save"
const VERSION := 1

## Fewest moves per level; zero means never cleared. Typed, because growing an
## untyped Array pads with null and `int(null)` is not a thing (DECISION_LOG 101).
var best_moves: Array[int] = []
## How many levels have been cleared. The next one to play is exactly this.
var progress := 0
var loaded := true


func _ready() -> void:
	read()


func next_level() -> int:
	return progress


func best_for(level: int) -> int:
	if level < 0 or level >= best_moves.size():
		return 0
	return best_moves[level]


func record(level: int, moves: int) -> bool:
	if level < 0:
		return false
	if level >= best_moves.size():
		best_moves.resize(level + 1)
	var is_record := best_moves[level] <= 0 or moves < best_moves[level]
	if is_record:
		best_moves[level] = moves
	if level + 1 > progress:
		progress = level + 1
		is_record = true
	write()
	return is_record


func reset() -> void:
	progress = 0
	best_moves.clear()
	write()


func read() -> void:
	var file := ConfigFile.new()
	var err := file.load(PATH)
	if err == ERR_FILE_NOT_FOUND:
		_clear()
		loaded = true
		return
	if err != OK:
		_clear()
		loaded = false
		return
	if int(file.get_value("save", "version", 0)) != VERSION:
		_clear()
		loaded = false
		return
	var raw: Variant = file.get_value("save", "best_moves", [])
	var values: Array[int] = []
	if raw is Array:
		for value in raw:
			values.append(int(value))
	best_moves = values
	progress = int(file.get_value("save", "progress", 0))
	loaded = true


func write() -> void:
	var file := ConfigFile.new()
	file.set_value("save", "version", VERSION)
	file.set_value("save", "best_moves", best_moves)
	file.set_value("save", "progress", progress)
	if file.save(PATH) != OK:
		push_warning("sokoban: could not write %s" % PATH)


func _clear() -> void:
	best_moves.clear()
	progress = 0
