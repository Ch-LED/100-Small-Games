class_name BejeweledSettings
extends RefCounted

## Loads bejeweled.cfg once and hands the values out typed.

const PATH := "res://17-bejeweled/bejeweled.cfg"
const FIELD := Vector2(1280.0, 720.0)

var rows := 8
var cols := 8
var kinds := 6
var gem_colors: Array[Color] = []
var cell_size := 64.0
var bg_color := Color("080B14")
var cell_color := Color("161F33")
var cell_alt_color := Color("111A2B")
var cursor_color := Color("E8EEF9")
var hint_color := Color("4BD3FF")
var super_color := Color("00E676")
var text_color := Color("E8EEF9")
var accent_text := Color("4FC3F7")
var dim_text := Color("7E8CA8")
var gem_inset := 0.16

var round_seconds := 90
var per_gem := 10
var swap_time := 0.12
var clear_time := 0.16
var fall_time := 0.16

var swap_freq := 440.00
var reject_freq := 174.61
var clear_freqs: Array[float] = [523.25, 587.33, 659.25, 698.46, 783.99, 880.00]
var cascade_freq := 659.25
var over_freq := 196.00
var record_freqs: Array[float] = [659.25, 783.99, 1046.50]
var start_freq := 329.63

var font_size := 16
var margin := 28.0


func _init() -> void:
	load_from(PATH)


func load_from(path: String) -> void:
	var file := ConfigFile.new()
	if file.load(path) != OK:
		push_error("BejeweledSettings: cannot load %s -- using fallbacks" % path)
		_fill_gems([])
		return
	rows = maxi(4, int(file.get_value("board", "rows", rows)))
	cols = maxi(4, int(file.get_value("board", "cols", cols)))
	kinds = maxi(3, int(file.get_value("board", "kinds", kinds)))
	_fill_gems(_colors(file, "board", "gem_colors"))
	cell_size = float(file.get_value("board", "cell_size", cell_size))
	bg_color = _color(file, "board", "bg_color", bg_color)
	cell_color = _color(file, "board", "cell_color", cell_color)
	cell_alt_color = _color(file, "board", "cell_alt_color", cell_alt_color)
	cursor_color = _color(file, "board", "cursor_color", cursor_color)
	hint_color = _color(file, "board", "hint_color", hint_color)
	super_color = _color(file, "board", "super_color", super_color)
	text_color = _color(file, "board", "text_color", text_color)
	accent_text = _color(file, "board", "accent_text", accent_text)
	dim_text = _color(file, "board", "dim_text", dim_text)
	gem_inset = float(file.get_value("board", "gem_inset", gem_inset))

	round_seconds = int(file.get_value("round", "seconds", round_seconds))
	per_gem = int(file.get_value("score", "per_gem", per_gem))
	swap_time = float(file.get_value("score", "swap_time", swap_time))
	clear_time = float(file.get_value("score", "clear_time", clear_time))
	fall_time = float(file.get_value("score", "fall_time", fall_time))

	swap_freq = float(file.get_value("audio", "swap_freq", swap_freq))
	reject_freq = float(file.get_value("audio", "reject_freq", reject_freq))
	clear_freqs = _floats(file, "audio", "clear_freqs", clear_freqs)
	cascade_freq = float(file.get_value("audio", "cascade_freq", cascade_freq))
	over_freq = float(file.get_value("audio", "over_freq", over_freq))
	record_freqs = _floats(file, "audio", "record_freqs", record_freqs)
	start_freq = float(file.get_value("audio", "start_freq", start_freq))

	font_size = int(file.get_value("hud", "font_size", font_size))
	margin = float(file.get_value("hud", "margin", margin))


func gem_color(kind: int) -> Color:
	if gem_colors.is_empty():
		return Color.WHITE
	return gem_colors[clampi(kind, 0, gem_colors.size() - 1)]


func _fill_gems(loaded: Array[Color]) -> void:
	if not loaded.is_empty():
		gem_colors = loaded
		return
	gem_colors = [Color("FF5252"), Color("FFB300"), Color("FFEB3B"), Color("66BB6A"),
			Color("42A5F5"), Color("AB47BC")]


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


func _floats(file: ConfigFile, section: String, key: String, fallback: Array[float]) -> Array[float]:
	var raw: Variant = file.get_value(section, key, null)
	var out: Array[float] = []
	if raw is Array:
		for value in raw:
			out.append(float(value))
	return out if not out.is_empty() else fallback
