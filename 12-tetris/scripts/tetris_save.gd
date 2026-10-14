class_name TetrisSave
extends Node

## Two records kept in user:// between sessions: the best marathon score and
## the fastest sprint.
##
## Three things can be wrong with the file and all three fall back to an empty
## store rather than refusing to start: it is not there yet (normal on a first
## run), it is not something this game wrote, or a different version wrote it.
## `loaded` says which happened, so the menu can admit it instead of showing a
## blank scoreboard as though it were the truth (spec 11).

const PATH := "user://tetris.save"
const VERSION := 1

var best_score: int = 0
## Milliseconds; zero means no sprint has ever been finished.
var best_sprint_ms: int = 0
## False when the file existed but could not be believed.
var loaded: bool = true


func _ready() -> void:
	read()


## Returns true when the run beat what was there. Written immediately: a record
## is worth exactly as much as its surviving the next crash.
func record_marathon(score: int) -> bool:
	if score <= best_score:
		return false
	best_score = score
	write()
	return true


func record_sprint(milliseconds: int) -> bool:
	if best_sprint_ms > 0 and milliseconds >= best_sprint_ms:
		return false
	best_sprint_ms = milliseconds
	write()
	return true


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
	best_score = int(file.get_value("save", "best_score", 0))
	best_sprint_ms = int(file.get_value("save", "best_sprint_ms", 0))
	loaded = true


func write() -> void:
	var file := ConfigFile.new()
	file.set_value("save", "version", VERSION)
	file.set_value("save", "best_score", best_score)
	file.set_value("save", "best_sprint_ms", best_sprint_ms)
	if file.save(PATH) != OK:
		push_warning("tetris: could not write %s" % PATH)


func _clear() -> void:
	best_score = 0
	best_sprint_ms = 0


## mm:ss.mmm, which is the shape a sprint time wants to be read in. Zero means
## there is no time yet, and says so rather than showing 00:00.000.
static func format_time(milliseconds: int) -> String:
	if milliseconds <= 0:
		return "--"
	var minutes := milliseconds / 60000
	var seconds := (milliseconds / 1000) % 60
	var millis := milliseconds % 1000
	return "%02d:%02d.%03d" % [minutes, seconds, millis]
