class_name MinesweeperSettings
extends RefCounted

## Loads minesweeper.cfg once and hands the values out typed.
##
## Every key has a fallback here, which is the price of the config being the
## single source of truth: a mistyped key will not shout, it will just use the
## fallback. When adding a key, add it in both places (spec 7).

const PATH := "res://15-minesweeper/minesweeper.cfg"

## Fixed logical field. Kept here so the board, the HUD and the overlay agree
## without any of them measuring the window.
const FIELD := Vector2(1280.0, 720.0)

var bg_color := Color("080B14")
var hidden_color := Color("2A3B5C")
var hidden_edge := Color("3F5A8C")
var open_color := Color("141B2B")
var grid_color := Color("0A1020")
var number_colors: Array[Color] = []
var flag_color := Color("E94560")
var mine_color := Color("E8EEF9")
var wrong_flag_color := Color("7E8CA8")
var super_color := Color("00E676")
var cursor_color := Color("4FC3F7")
var text_color := Color("E8EEF9")
var accent_text := Color("4FC3F7")
var dim_text := Color("7E8CA8")
var cell_size := 28.0
var edge_scale := 0.09

var level_names: Array[String] = ["BEGINNER", "INTERMEDIATE", "EXPERT"]
var level_rows: Array[int] = [9, 16, 16]
var level_cols: Array[int] = [9, 16, 30]
var level_mines: Array[int] = [10, 40, 99]

var open_freq := 523.25
var flag_freq := 392.00
var unflag_freq := 329.63
var boom_freq := 98.00
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
		push_error("MinesweeperSettings: cannot load %s -- using fallbacks" % path)
		_fill_numbers([])
		return

	bg_color = _color(file, "board", "bg_color", bg_color)
	hidden_color = _color(file, "board", "hidden_color", hidden_color)
	hidden_edge = _color(file, "board", "hidden_edge", hidden_edge)
	open_color = _color(file, "board", "open_color", open_color)
	grid_color = _color(file, "board", "grid_color", grid_color)
	_fill_numbers(_colors(file, "board", "number_colors"))
	flag_color = _color(file, "board", "flag_color", flag_color)
	mine_color = _color(file, "board", "mine_color", mine_color)
	wrong_flag_color = _color(file, "board", "wrong_flag_color", wrong_flag_color)
	super_color = _color(file, "board", "super_color", super_color)
	cursor_color = _color(file, "board", "cursor_color", cursor_color)
	text_color = _color(file, "board", "text_color", text_color)
	accent_text = _color(file, "board", "accent_text", accent_text)
	dim_text = _color(file, "board", "dim_text", dim_text)
	cell_size = float(file.get_value("board", "cell_size", cell_size))
	edge_scale = float(file.get_value("board", "edge_scale", edge_scale))

	level_names = _strings(file, "levels", "names", level_names)
	level_rows = _ints(file, "levels", "rows", level_rows)
	level_cols = _ints(file, "levels", "cols", level_cols)
	level_mines = _ints(file, "levels", "mines", level_mines)

	open_freq = float(file.get_value("audio", "open_freq", open_freq))
	flag_freq = float(file.get_value("audio", "flag_freq", flag_freq))
	unflag_freq = float(file.get_value("audio", "unflag_freq", unflag_freq))
	boom_freq = float(file.get_value("audio", "boom_freq", boom_freq))
	win_freqs = _floats(file, "audio", "win_freqs", win_freqs)
	record_freqs = _floats(file, "audio", "record_freqs", record_freqs)
	start_freq = float(file.get_value("audio", "start_freq", start_freq))

	font_size = int(file.get_value("hud", "font_size", font_size))
	margin = float(file.get_value("hud", "margin", margin))


func level_count() -> int:
	return mini(mini(level_names.size(), level_rows.size()),
			mini(level_cols.size(), level_mines.size()))


func level_name(level: int) -> String:
	if level < 0 or level >= level_names.size():
		return "?"
	return level_names[level]


func rows_for(level: int) -> int:
	if level < 0 or level >= level_rows.size():
		return 9
	return level_rows[level]


func cols_for(level: int) -> int:
	if level < 0 or level >= level_cols.size():
		return 9
	return level_cols[level]


func mines_for(level: int) -> int:
	if level < 0 or level >= level_mines.size():
		return 10
	return level_mines[level]


func number_color(digit: int) -> Color:
	if number_colors.is_empty():
		return Color.WHITE
	return number_colors[clampi(digit - 1, 0, number_colors.size() - 1)]


func _fill_numbers(loaded: Array[Color]) -> void:
	if not loaded.is_empty():
		number_colors = loaded
		return
	number_colors = [Color("4FC3F7"), Color("66BB6A"), Color("E94560"), Color("AB47BC"),
			Color("FFB300"), Color("26C6DA"), Color("FF7043"), Color("E8EEF9")]


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


func _strings(file: ConfigFile, section: String, key: String, fallback: Array[String]) -> Array[String]:
	var raw: Variant = file.get_value(section, key, null)
	var out: Array[String] = []
	if raw is Array:
		for value in raw:
			out.append(str(value))
	return out if not out.is_empty() else fallback
