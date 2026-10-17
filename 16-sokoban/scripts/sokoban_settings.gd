class_name SokobanSettings
extends RefCounted

## Loads sokoban.cfg once and hands the values out typed.
##
## Every key has a fallback here, which is the price of the config being the
## single source of truth: a mistyped key will not shout, it will just use the
## fallback. When adding a key, add it in both places (spec 6).

const PATH := "res://16-sokoban/sokoban.cfg"
const LEVEL_DIR := "res://16-sokoban/levels/"

const FIELD := Vector2(1280.0, 720.0)

var bg_color := Color("080B14")
var wall_color := Color("2A3B5C")
var wall_edge := Color("3F5A8C")
var floor_color := Color("141B2B")
var goal_color := Color("4FC3F7")
var box_color := Color("FFB300")
var box_edge := Color("FFD54F")
var box_done_color := Color("66BB6A")
var box_done_edge := Color("A5D6A7")
var player_color := Color("FF7043")
var player_edge := Color("FFAB91")
var super_color := Color("00E676")
var text_color := Color("E8EEF9")
var accent_text := Color("4FC3F7")
var dim_text := Color("7E8CA8")
var cell_size := 56.0
var corner_scale := 0.12

var step_freq := 392.00
var push_freq := 261.63
var blocked_freq := 138.59
var undo_freq := 220.00
var placed_freq := 587.33
var win_freqs: Array[float] = [523.25, 659.25, 783.99, 1046.50]
var record_freqs: Array[float] = [659.25, 783.99, 1046.50]
var start_freq := 329.63

var font_size := 16
var margin := 28.0


func _init() -> void:
	load_from(PATH)


func load_from(path: String) -> void:
	var file := ConfigFile.new()
	if file.load(path) != OK:
		push_error("SokobanSettings: cannot load %s -- using fallbacks" % path)
		return

	bg_color = _color(file, "board", "bg_color", bg_color)
	wall_color = _color(file, "board", "wall_color", wall_color)
	wall_edge = _color(file, "board", "wall_edge", wall_edge)
	floor_color = _color(file, "board", "floor_color", floor_color)
	goal_color = _color(file, "board", "goal_color", goal_color)
	box_color = _color(file, "board", "box_color", box_color)
	box_edge = _color(file, "board", "box_edge", box_edge)
	box_done_color = _color(file, "board", "box_done_color", box_done_color)
	box_done_edge = _color(file, "board", "box_done_edge", box_done_edge)
	player_color = _color(file, "board", "player_color", player_color)
	player_edge = _color(file, "board", "player_edge", player_edge)
	super_color = _color(file, "board", "super_color", super_color)
	text_color = _color(file, "board", "text_color", text_color)
	accent_text = _color(file, "board", "accent_text", accent_text)
	dim_text = _color(file, "board", "dim_text", dim_text)
	cell_size = float(file.get_value("board", "cell_size", cell_size))
	corner_scale = float(file.get_value("board", "corner_scale", corner_scale))

	step_freq = float(file.get_value("audio", "step_freq", step_freq))
	push_freq = float(file.get_value("audio", "push_freq", push_freq))
	blocked_freq = float(file.get_value("audio", "blocked_freq", blocked_freq))
	undo_freq = float(file.get_value("audio", "undo_freq", undo_freq))
	placed_freq = float(file.get_value("audio", "placed_freq", placed_freq))
	win_freqs = _floats(file, "audio", "win_freqs", win_freqs)
	record_freqs = _floats(file, "audio", "record_freqs", record_freqs)
	start_freq = float(file.get_value("audio", "start_freq", start_freq))

	font_size = int(file.get_value("hud", "font_size", font_size))
	margin = float(file.get_value("hud", "margin", margin))


## Level files in order: 01.txt, 02.txt, ... Anything that is not a `.txt` is
## ignored, so a stray note in the folder does not break the game.
func level_files() -> PackedStringArray:
	var out := PackedStringArray()
	var directory := DirAccess.open(LEVEL_DIR)
	if directory == null:
		push_error("SokobanSettings: cannot open %s" % LEVEL_DIR)
		return out
	for name in directory.get_files():
		if name.ends_with(".txt"):
			out.append(LEVEL_DIR + name)
	out.sort()
	return out


func _color(file: ConfigFile, section: String, key: String, fallback: Color) -> Color:
	var value: Variant = file.get_value(section, key, "")
	if value is String and Color.html_is_valid(value):
		return Color.html(value)
	return fallback


func _floats(file: ConfigFile, section: String, key: String, fallback: Array[float]) -> Array[float]:
	var raw: Variant = file.get_value(section, key, null)
	var out: Array[float] = []
	if raw is Array:
		for value in raw:
			out.append(float(value))
	return out if not out.is_empty() else fallback
