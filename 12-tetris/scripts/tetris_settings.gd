class_name TetrisSettings
extends RefCounted

## Every value read out of tetris.cfg, each with a fallback.
##
## The fallbacks are the dangerous part: a key added to the .cfg but not to
## this table does not error, it just silently runs on the fallback. Add both
## together. (10-marble-race lost a session to exactly this.)
##
## Board geometry is deliberately NOT here. 10x20 with spare rows above is
## fixed by the guideline rather than by taste, so it lives in TetrisBoard
## where the assertion suite can reach it.

const PATH := "res://12-tetris/tetris.cfg"

## Atlas order, which is the same order as Tetromino.Kind.
const COLOR_KEYS := ["i", "o", "t", "s", "z", "j", "l"]

var cell_size: int = 32

var lock_delay: float = 0.5
var lock_reset_cap: int = 15
var level_cap: int = 20
var min_fall_per_grid: float = 20.0
var sprint_lines: int = 40
var soft_drop_interval: float = 0.05

var das: float = 0.13
var arr: float = 0.02

var time_scale: float = 3.0

var board_bg: Color = Color.html("0A0E18")
var grid_color: Color = Color.html("1B2438")
var super_color: Color = Color.html("00E676")
var piece_colors: Array[Color] = []

var font_size: int = 16
var margin: float = 24.0

## Sound is taste, so every frequency is here rather than in code.
var audio_move_freq: float = 440.0
var audio_rotate_freq: float = 587.33
var audio_lock_freq: float = 146.83
var audio_line_freqs: Array[float] = [523.25, 659.25, 783.99, 1046.50]
var audio_tspin_freqs: Array[float] = [783.99, 987.77, 1174.66]
var audio_level_freqs: Array[float] = [494.0, 587.33, 783.99]
var audio_record_freqs: Array[float] = [659.25, 783.99, 1046.50]


func _init() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		push_warning("12-tetris: %s missing or unreadable, running on fallbacks" % PATH)

	cell_size = cfg.get_value("board", "cell_size", cell_size)

	lock_delay = cfg.get_value("play", "lock_delay", lock_delay)
	lock_reset_cap = cfg.get_value("play", "lock_reset_cap", lock_reset_cap)
	level_cap = cfg.get_value("play", "level_cap", level_cap)
	min_fall_per_grid = cfg.get_value("play", "min_fall_per_grid", min_fall_per_grid)
	sprint_lines = cfg.get_value("play", "sprint_lines", sprint_lines)
	soft_drop_interval = cfg.get_value("play", "soft_drop_interval", soft_drop_interval)

	das = cfg.get_value("input", "das", das)
	arr = cfg.get_value("input", "arr", arr)

	time_scale = cfg.get_value("cheat", "time_scale", time_scale)

	board_bg = _read_color(cfg, "board_bg", board_bg)
	grid_color = _read_color(cfg, "grid", grid_color)
	super_color = _read_color(cfg, "super", super_color)
	piece_colors.clear()
	for key in COLOR_KEYS:
		piece_colors.append(_read_color(cfg, key, Color.MAGENTA))

	font_size = cfg.get_value("hud", "font_size", font_size)
	margin = cfg.get_value("hud", "margin", margin)

	audio_move_freq = cfg.get_value("audio", "move_freq", audio_move_freq)
	audio_rotate_freq = cfg.get_value("audio", "rotate_freq", audio_rotate_freq)
	audio_lock_freq = cfg.get_value("audio", "lock_freq", audio_lock_freq)
	audio_line_freqs = _read_floats(cfg, "line_freqs", audio_line_freqs)
	audio_tspin_freqs = _read_floats(cfg, "tspin_freqs", audio_tspin_freqs)
	audio_level_freqs = _read_floats(cfg, "level_freqs", audio_level_freqs)
	audio_record_freqs = _read_floats(cfg, "record_freqs", audio_record_freqs)


func _read_color(cfg: ConfigFile, key: String, fallback: Color) -> Color:
	var text: String = cfg.get_value("colors", key, "")
	if text.is_empty():
		return fallback
	return Color.html(text)


## The .cfg stores these as an untyped array, so they are copied into a typed
## one here rather than left to leak Variants through the audio code.
func _read_floats(cfg: ConfigFile, key: String, fallback: Array[float]) -> Array[float]:
	var raw: Variant = cfg.get_value("audio", key, null)
	if not (raw is Array):
		return fallback
	var result: Array[float] = []
	for value in raw:
		result.append(float(value))
	return result
