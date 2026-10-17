class_name MinesweeperSave
extends Node

## The fastest clear per difficulty, kept in user:// between sessions.
##
## Three things can be wrong with the file and all three fall back to an empty
## store rather than refusing to start: it is not there yet (normal on a first
## run), it is not something this game wrote, or a different version wrote it.
## `loaded` says which happened, so the menu can admit it instead of showing a
## blank time as though it were a record (spec 11).

const PATH := "user://minesweeper.save"
const VERSION := 1

## Milliseconds per difficulty; zero means that tier has never been cleared.
## Typed, because growing an untyped Array pads with null and `int(null)` is
## not a thing (DECISION_LOG 101).
var best_ms: Array[int] = []
## False when the file existed but could not be believed.
var loaded := true


func _ready() -> void:
	read()


func best_for(level: int) -> int:
	if level < 0 or level >= best_ms.size():
		return 0
	return best_ms[level]


## Returns true when the run beat what was there. Written immediately: a record
## is worth exactly as much as its surviving the next crash.
func record(level: int, milliseconds: int) -> bool:
	if level < 0:
		return false
	if level >= best_ms.size():
		best_ms.resize(level + 1)
	var is_record := best_ms[level] <= 0 or milliseconds < best_ms[level]
	if is_record:
		best_ms[level] = milliseconds
		write()
	return is_record


func read() -> void:
	var file := ConfigFile.new()
	var err := file.load(PATH)
	if err == ERR_FILE_NOT_FOUND:
		best_ms.clear()
		loaded = true
		return
	if err != OK:
		best_ms.clear()
		loaded = false
		return
	if int(file.get_value("save", "version", 0)) != VERSION:
		best_ms.clear()
		loaded = false
		return
	var raw: Variant = file.get_value("save", "best_ms", [])
	var values: Array[int] = []
	if raw is Array:
		for value in raw:
			values.append(int(value))
	best_ms = values
	loaded = true


func write() -> void:
	var file := ConfigFile.new()
	file.set_value("save", "version", VERSION)
	file.set_value("save", "best_ms", best_ms)
	if file.save(PATH) != OK:
		push_warning("minesweeper: could not write %s" % PATH)


## mm:ss.mmm, which is the shape a clear time wants to be read in. Zero means
## there is no time yet, and says so rather than showing 00:00.000.
static func format_time(milliseconds: int) -> String:
	if milliseconds <= 0:
		return "--"
	var minutes := milliseconds / 60000
	var seconds := (milliseconds / 1000) % 60
	var millis := milliseconds % 1000
	return "%02d:%02d.%03d" % [minutes, seconds, millis]


## mm:ss, for the running clock where the milliseconds only flicker.
static func format_clock(milliseconds: int) -> String:
	var minutes := milliseconds / 60000
	var seconds := (milliseconds / 1000) % 60
	return "%02d:%02d" % [minutes, seconds]
