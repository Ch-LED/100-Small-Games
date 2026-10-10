class_name MarbleSave
extends RefCounted
## Best times, kept across runs in user://. The first persistence in this
## project, so it is written to survive the two things that will actually
## happen to it: the file being absent on a first run, and the file being
## garbage after a crash or a hand edit. Both fall back to an empty save —
## a racing game that refuses to start because its scoreboard is unreadable
## would be a worse failure than a missing scoreboard.

const PATH := "user://marble_race.save"
## Bumped whenever the layout changes in a way old files cannot be read as.
const FORMAT := 1

var _best: Dictionary = {}
## True when the last load had to throw something away, for the caller to say
## so rather than silently pretending the times were never set.
var recovered := false


static func load_from_disk() -> MarbleSave:
	var save := MarbleSave.new()
	var file := ConfigFile.new()
	if not FileAccess.file_exists(PATH):
		return save
	var error := file.load(PATH)
	if error != OK:
		save.recovered = true
		push_warning("MarbleSave: cannot read %s (%s); starting empty"
				% [PATH, error_string(error)])
		return save
	if int(file.get_value("meta", "format", 0)) != FORMAT:
		save.recovered = true
		push_warning("MarbleSave: %s is format %s, expected %d; starting empty"
				% [PATH, file.get_value("meta", "format", 0), FORMAT])
		return save
	for track_id in file.get_section_keys("best"):
		var time: Variant = file.get_value("best", track_id, 0.0)
		if time is float and time > 0.0:
			save._best[track_id] = time
		else:
			save.recovered = true
	return save


func best(track_id: String) -> float:
	return float(_best.get(track_id, 0.0))


func record(track_id: String, seconds: float) -> bool:
	var previous := best(track_id)
	if previous > 0.0 and seconds >= previous:
		return false
	_best[track_id] = seconds
	_write()
	return true


func _write() -> void:
	var file := ConfigFile.new()
	file.set_value("meta", "format", FORMAT)
	for track_id in _best:
		file.set_value("best", track_id, _best[track_id])
	var error := file.save(PATH)
	if error != OK:
		push_error("MarbleSave: cannot write %s (%s)" % [PATH, error_string(error)])


## mm:ss.hh, or a dash while nothing has been set. Shared with the HUD so a
## time never reads two ways in one game.
static func format(seconds: float) -> String:
	if seconds <= 0.0:
		return "--:--.--"
	var total := seconds
	var minutes := int(total / 60.0)
	return "%02d:%05.2f" % [minutes, total - float(minutes) * 60.0]
