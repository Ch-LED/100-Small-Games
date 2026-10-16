class_name PipesSave
extends Node

## Progress kept in user:// between sessions: how far each mode has got, and
## the fastest solve for every level reached in it.
##
## Per mode, because the four modes are four different games as far as progress
## is concerned -- being stuck on 9x9 in one says nothing about the others.
##
## Three things can be wrong with the file and all three fall back to an empty
## store rather than refusing to start: it is not there yet (normal on a first
## run), it is not something this game wrote, or a different version wrote it.
## `loaded` says which happened, so the menu can admit it instead of offering
## to continue a run that never happened (spec 11).

const PATH := "user://pipes.save"
## Bumped when the shape of the file changed: version 1 kept one progress and
## one table, before the modes existed.
const VERSION := 2

## Levels cleared per mode; the next one to play is exactly this.
var progress: Array[int] = []
## Milliseconds per level per mode; zero means never finished.
var best_ms: Array = []
## False when the file existed but could not be believed.
var loaded := true


func _ready() -> void:
	read()


func next_level(mode: int) -> int:
	_ensure(mode)
	return progress[mode]


func best_for(mode: int, level: int) -> int:
	_ensure(mode)
	var table: Array[int] = best_ms[mode]
	if level < 0 or level >= table.size():
		return 0
	return table[level]


## Returns true when the run beat what was there, or opened a level that had
## never been reached. Written immediately: a record is worth exactly as much
## as its surviving the next crash.
func record(mode: int, level: int, milliseconds: int) -> bool:
	if level < 0:
		return false
	_ensure(mode)
	# Typed, and that matters: growing an untyped Array pads with null, and
	# `int(null)` is not a thing -- it took the whole run down at the first
	# record (DECISION_LOG 101). An Array[int] pads with zero, which is what
	# "never finished" means here.
	var table: Array[int] = best_ms[mode]
	if level >= table.size():
		table.resize(level + 1)
	var is_record := table[level] <= 0 or milliseconds < table[level]
	if is_record:
		table[level] = milliseconds
	if level + 1 > progress[mode]:
		progress[mode] = level + 1
		is_record = true
	write()
	return is_record


func reset(mode: int) -> void:
	_ensure(mode)
	progress[mode] = 0
	var fresh: Array[int] = []
	best_ms[mode] = fresh
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
	_clear()
	var raw_progress: Variant = file.get_value("save", "progress", [])
	if raw_progress is Array:
		for index in (raw_progress as Array).size():
			_ensure(index)
			progress[index] = int(raw_progress[index])
	var raw_best: Variant = file.get_value("save", "best_ms", [])
	if raw_best is Array:
		for index in (raw_best as Array).size():
			_ensure(index)
			var table: Array[int] = []
			if raw_best[index] is Array:
				for value in (raw_best[index] as Array):
					table.append(int(value))
			best_ms[index] = table
	loaded = true


func write() -> void:
	var file := ConfigFile.new()
	file.set_value("save", "version", VERSION)
	file.set_value("save", "progress", progress)
	file.set_value("save", "best_ms", best_ms)
	if file.save(PATH) != OK:
		push_warning("pipes: could not write %s" % PATH)


func _clear() -> void:
	progress = []
	best_ms = []
	for _mode in PipesModes.COUNT:
		progress.append(0)
		var fresh: Array[int] = []
		best_ms.append(fresh)


func _ensure(mode: int) -> void:
	if mode < 0:
		return
	while progress.size() <= mode:
		progress.append(0)
	while best_ms.size() <= mode:
		var fresh: Array[int] = []
		best_ms.append(fresh)


## mm:ss.mmm, which is the shape a solve time wants to be read in. Zero means
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
