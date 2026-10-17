class_name BejeweledSave
extends Node

## The best score, kept in user:// between sessions.

const PATH := "user://bejeweled.save"
const VERSION := 1

var best_score := 0
var loaded := true


func _ready() -> void:
	read()


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
		push_warning("bejeweled: could not write %s" % PATH)
