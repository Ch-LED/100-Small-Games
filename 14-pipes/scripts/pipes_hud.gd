class_name PipesHud
extends Control

## The standing readout: which level, the clock, and how much of the board is
## joined and filled. Draws itself rather than juggling Labels, so every line
## shares one font pass and one margin (spec 8).
##
## Nothing here names a key. The cheats are meant to be found, not advertised,
## and a legend of what to press turns a board into a manual (DECISION_LOG 100).

var _settings: PipesSettings
var _font: FontFile
var _level := 0
var _clock_ms := 0
var _mode := ""
var _readout := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = PixelFont.get_font()


func setup(settings: PipesSettings) -> void:
	_settings = settings
	_font = PixelFont.get_font()
	queue_redraw()


## What goes on the right is the play screen's business: the four modes do not
## measure the same thing, and a HUD that knew about all of them would be a HUD
## with four jobs.
func refresh(level: int, clock_ms: int, mode: String, readout: String) -> void:
	_level = level
	_clock_ms = clock_ms
	_mode = mode
	_readout = readout
	queue_redraw()


func _draw() -> void:
	if _settings == null:
		return
	var font_size := _settings.font_size
	var margin := _settings.margin
	var top := margin + float(font_size)
	var headline := "LEVEL %d" % (_level + 1)

	draw_string(_font, Vector2(margin, top), headline,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, _settings.text_color)
	var clock_left := margin + _text_width(headline, font_size) + float(font_size) * 1.5
	draw_string(_font, Vector2(clock_left, top), PipesSave.format_clock(_clock_ms),
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, _settings.accent_text)
	_draw_right("%s   %s" % [_mode, _readout], top, font_size, _settings.text_color)

	# The one thing a player cannot work out by pressing it.
	_draw_centred("ESC  MENU", PipesSettings.FIELD.y - margin, font_size, _settings.dim_text)


func _draw_right(text: String, at_y: float, font_size: int, color: Color) -> void:
	var width := _text_width(text, font_size)
	draw_string(_font, Vector2(PipesSettings.FIELD.x - _settings.margin - width, at_y),
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw_centred(text: String, at_y: float, font_size: int, color: Color) -> void:
	var width := _text_width(text, font_size)
	draw_string(_font, Vector2((PipesSettings.FIELD.x - width) * 0.5, at_y),
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _text_width(text: String, font_size: int) -> float:
	return _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
