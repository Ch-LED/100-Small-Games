class_name PinballSaveStore
extends Node
## The best score, kept in user:// between sessions.
##
## Three things can be wrong with the file and all three fall back to an empty
## store rather than refusing to start: it is not there yet (normal on a first
## run), it is not something this game wrote, or it was written by a different
## version. `loaded` says which of those happened, so the menu can admit it
## instead of showing a blank scoreboard as if it were the truth (spec 8).

const PATH := "user://pinball.save"
const VERSION := 1

var best_score := 0
## False when the file existed but could not be believed.
var loaded := true


func _ready() -> void:
	read()


## Returns true when the run beat what was there. Writes immediately: a run's
## best score is worth exactly as much as its surviving the next crash.
func record(score: int) -> bool:
	if score <= best_score:
		return false
	best_score = score
	write()
	return true


func read() -> void:
	var file := ConfigFile.new()
	var err := file.load(PATH)
	if err == ERR_FILE_NOT_FOUND:
		best_score = 0
		loaded = true
		return
	if err != OK:
		best_score = 0
		loaded = false
		return
	if int(file.get_value("save", "version", 0)) != VERSION:
		best_score = 0
		loaded = false
		return
	best_score = int(file.get_value("save", "best_score", 0))
	loaded = true


func write() -> void:
	var file := ConfigFile.new()
	file.set_value("save", "version", VERSION)
	file.set_value("save", "best_score", best_score)
	if file.save(PATH) != OK:
		push_warning("pinball: could not write %s" % PATH)
