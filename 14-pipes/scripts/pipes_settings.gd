class_name PipesSettings
extends RefCounted

## Loads pipes.cfg once and hands the values out typed.
##
## Every key has a fallback here, which is the price of the config being the
## single source of truth: a mistyped key in the file will not shout, it will
## just use the fallback. When adding a key, add it in both places (spec 7).

const PATH := "res://14-pipes/pipes.cfg"

## Fixed logical field. Kept here so the board, the HUD and the overlay agree
## without any of them measuring the window.
const FIELD := Vector2(1280.0, 720.0)

var bg_color := Color("080B14")
var empty_color := Color("141B2B")
var grid_color := Color("22304A")
var cursor_color := Color("2A3B5C")
var cell_size := 60.0
var line_width := 0.30
var dot_scale := 0.52
var joined_dot_scale := 0.34
var bridge_color := Color("F2F6FF")
var hint_color := Color("4BD3FF")
var super_color := Color("00E676")
var text_color := Color("E8EEF9")
var accent_text := Color("4FC3F7")
var dim_text := Color("7E8CA8")

var pipe_color := Color("8AA0C8")
var joined_pipe_color := Color("4BD3FF")
var pinned_pipe_color := Color("4A5A78")
var pipe_width := 0.34
var hover_alpha := 10

var palette: Array[Color] = []

var sides: Array[int] = [5, 6, 6, 7, 7, 8, 8, 9, 9, 9]
var pairs: Array[int] = [4, 5, 5, 6, 6, 7, 7, 8, 8, 9]
var min_run := 3

var shuffle_steps: Array[int] = [10, 14, 18, 23, 28, 34, 40, 47, 54, 62]
var slide_gaps: Array[int] = [3, 3, 4, 4, 5, 5, 6, 6, 7, 7]

var draw_freq := 440.00
var join_freq := 587.33
var clear_freq := 196.00
var blocked_freq := 138.59
var solved_freqs: Array[float] = [523.25, 659.25, 783.99, 1046.50]
var record_freqs: Array[float] = [659.25, 783.99, 1046.50]
var start_freq := 329.63

var font_size := 16
var margin := 28.0


func _init() -> void:
	load_from(PATH)


func load_from(path: String) -> void:
	var file := ConfigFile.new()
	if file.load(path) != OK:
		push_error("PipesSettings: cannot load %s -- using fallbacks" % path)
		_fill_palette([])
		return

	bg_color = _color(file, "board", "bg_color", bg_color)
	empty_color = _color(file, "board", "empty_color", empty_color)
	grid_color = _color(file, "board", "grid_color", grid_color)
	cursor_color = _color(file, "board", "cursor_color", cursor_color)
	cell_size = float(file.get_value("board", "cell_size", cell_size))
	line_width = float(file.get_value("board", "line_width", line_width))
	dot_scale = float(file.get_value("board", "dot_scale", dot_scale))
	joined_dot_scale = float(file.get_value("board", "joined_dot_scale", joined_dot_scale))
	bridge_color = _color(file, "board", "bridge_color", bridge_color)
	hint_color = _color(file, "board", "hint_color", hint_color)
	super_color = _color(file, "board", "super_color", super_color)
	text_color = _color(file, "board", "text_color", text_color)
	accent_text = _color(file, "board", "accent_text", accent_text)
	dim_text = _color(file, "board", "dim_text", dim_text)

	pipe_color = _color(file, "net", "pipe_color", pipe_color)
	joined_pipe_color = _color(file, "net", "joined_pipe_color", joined_pipe_color)
	pinned_pipe_color = _color(file, "net", "pinned_pipe_color", pinned_pipe_color)
	pipe_width = float(file.get_value("net", "pipe_width", pipe_width))
	hover_alpha = int(file.get_value("net", "hover_alpha", hover_alpha))

	_fill_palette(_colors(file, "colors", "palette"))

	sides = _ints(file, "levels", "sides", sides)
	pairs = _ints(file, "levels", "pairs", pairs)
	min_run = int(file.get_value("levels", "min_run", min_run))

	shuffle_steps = _ints(file, "net_levels", "shuffle_steps", shuffle_steps)
	slide_gaps = _ints(file, "net_levels", "slide_gaps", slide_gaps)

	draw_freq = float(file.get_value("audio", "draw_freq", draw_freq))
	join_freq = float(file.get_value("audio", "join_freq", join_freq))
	clear_freq = float(file.get_value("audio", "clear_freq", clear_freq))
	blocked_freq = float(file.get_value("audio", "blocked_freq", blocked_freq))
	solved_freqs = _floats(file, "audio", "solved_freqs", solved_freqs)
	record_freqs = _floats(file, "audio", "record_freqs", record_freqs)
	start_freq = float(file.get_value("audio", "start_freq", start_freq))

	font_size = int(file.get_value("hud", "font_size", font_size))
	margin = float(file.get_value("hud", "margin", margin))


func level_count() -> int:
	return mini(sides.size(), pairs.size())


func side_for(level: int) -> int:
	if level < 0 or level >= sides.size():
		return 9
	return sides[level]


func pairs_for(level: int) -> int:
	if level < 0 or level >= pairs.size():
		return 9
	return pairs[level]


func steps_for(level: int) -> int:
	if level < 0 or level >= shuffle_steps.size():
		return shuffle_steps[shuffle_steps.size() - 1]
	return shuffle_steps[level]


func gaps_for(level: int) -> int:
	if level < 0 or level >= slide_gaps.size():
		return slide_gaps[slide_gaps.size() - 1]
	return slide_gaps[level]


func color_for(index: int) -> Color:
	if palette.is_empty():
		return Color.WHITE
	return palette[clampi(index, 0, palette.size() - 1)]


func _fill_palette(loaded: Array[Color]) -> void:
	if not loaded.is_empty():
		palette = loaded
		return
	palette = [Color("FF5252"), Color("FFCA28"), Color("66BB6A"), Color("29B6F6"),
			Color("AB47BC"), Color("FF7043"), Color("26C6DA"), Color("8D6E63"),
			Color("EC407A"), Color("D4E157"), Color("BA68C8"), Color("4DB6AC")]


func _color(file: ConfigFile, section: String, key: String, fallback: Color) -> Color:
	var value: Variant = file.get_value(section, key, "")
	if value is String and Color.html_is_valid(value):
		return Color.html(value)
	return fallback


func _colors(file: ConfigFile, section: String, key: String) -> Array[Color]:
	var raw: Variant = file.get_value(section, key, null)
	var out: Array[Color] = []
	if raw is Array:
		for value in raw:
			if value is String and Color.html_is_valid(value):
				out.append(Color.html(value))
	return out


func _ints(file: ConfigFile, section: String, key: String, fallback: Array[int]) -> Array[int]:
	var raw: Variant = file.get_value(section, key, null)
	var out: Array[int] = []
	if raw is Array:
		for value in raw:
			out.append(int(value))
	return out if not out.is_empty() else fallback


func _floats(file: ConfigFile, section: String, key: String, fallback: Array[float]) -> Array[float]:
	var raw: Variant = file.get_value(section, key, null)
	var out: Array[float] = []
	if raw is Array:
		for value in raw:
			out.append(float(value))
	return out if not out.is_empty() else fallback
