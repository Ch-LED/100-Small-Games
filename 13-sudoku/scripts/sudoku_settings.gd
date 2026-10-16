class_name SudokuSettings
extends RefCounted

## Loads sudoku.cfg once and hands the values out typed.
##
## Every key has a fallback here, which is the price of the config being the
## single source of truth: a mistyped key in the file will not shout, it will
## just use the fallback. When adding a key, add it in both places (spec 6).

const PATH := "res://13-sudoku/sudoku.cfg"

## Fixed logical field. Kept here so the board, the HUD and the overlay agree
## without any of them measuring the window.
const FIELD := Vector2(1280.0, 720.0)

var bg_color := Color("080B14")
var board_bg := Color("141B2B")
var line_color := Color("2A3550")
var box_line_color := Color("5A6E9E")
var given_color := Color("E8EEF9")
var entry_color := Color("4FC3F7")
var conflict_color := Color("E94560")
var cursor_color := Color("1E2A44")
var peer_color := Color("182034")
var note_color := Color("7E8CA8")
var auto_note_color := Color("4BD3FF")
var super_color := Color("00E676")
var cell_size := 56.0

var digit_scale := 0.62
var note_scale := 0.22

var difficulty_names: Array[String] = ["EASY", "NORMAL", "HARD"]
var difficulty_blanks: Array[int] = [40, 48, 52]

var fill_freq := 523.25
var erase_freq := 196.00
var note_freq := 392.00
var clash_freq := 110.00
var complete_freqs: Array[float] = [523.25, 659.25, 783.99, 1046.50]
var record_freqs: Array[float] = [659.25, 783.99, 1046.50]
var start_freq := 329.63

var font_size := 16
var margin := 28.0


func _init() -> void:
	load_from(PATH)


func load_from(path: String) -> void:
	var file := ConfigFile.new()
	if file.load(path) != OK:
		push_error("SudokuSettings: cannot load %s -- using fallbacks" % path)
		return

	bg_color = _color(file, "board", "bg_color", bg_color)
	board_bg = _color(file, "board", "board_bg", board_bg)
	line_color = _color(file, "board", "line_color", line_color)
	box_line_color = _color(file, "board", "box_line_color", box_line_color)
	given_color = _color(file, "board", "given_color", given_color)
	entry_color = _color(file, "board", "entry_color", entry_color)
	conflict_color = _color(file, "board", "conflict_color", conflict_color)
	cursor_color = _color(file, "board", "cursor_color", cursor_color)
	peer_color = _color(file, "board", "peer_color", peer_color)
	note_color = _color(file, "board", "note_color", note_color)
	auto_note_color = _color(file, "board", "auto_note_color", auto_note_color)
	super_color = _color(file, "board", "super_color", super_color)
	cell_size = float(file.get_value("board", "cell_size", cell_size))

	digit_scale = float(file.get_value("text", "digit_scale", digit_scale))
	note_scale = float(file.get_value("text", "note_scale", note_scale))

	difficulty_names = _strings(file, "generator", "difficulty_names", difficulty_names)
	difficulty_blanks = _ints(file, "generator", "difficulty_blanks", difficulty_blanks)

	fill_freq = float(file.get_value("audio", "fill_freq", fill_freq))
	erase_freq = float(file.get_value("audio", "erase_freq", erase_freq))
	note_freq = float(file.get_value("audio", "note_freq", note_freq))
	clash_freq = float(file.get_value("audio", "clash_freq", clash_freq))
	complete_freqs = _floats(file, "audio", "complete_freqs", complete_freqs)
	record_freqs = _floats(file, "audio", "record_freqs", record_freqs)
	start_freq = float(file.get_value("audio", "start_freq", start_freq))

	font_size = int(file.get_value("hud", "font_size", font_size))
	margin = float(file.get_value("hud", "margin", margin))


func difficulty_count() -> int:
	return mini(difficulty_names.size(), difficulty_blanks.size())


func difficulty_name(index: int) -> String:
	if index < 0 or index >= difficulty_names.size():
		return "?"
	return difficulty_names[index]


func blanks_for(index: int) -> int:
	if index < 0 or index >= difficulty_blanks.size():
		return 40
	return difficulty_blanks[index]


## Board side in pixels, so the view, the HUD and the overlay can line up
## without recomputing it.
func board_side() -> float:
	return cell_size * float(SudokuBoard.SIZE)


func _color(file: ConfigFile, section: String, key: String, fallback: Color) -> Color:
	var value: Variant = file.get_value(section, key, "")
	if value is String and Color.html_is_valid(value):
		return Color.html(value)
	return fallback


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
