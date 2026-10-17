class_name MinesweeperHud
extends Control

## The standing readout: difficulty, mines left, and the clock.
##
## Nothing here names a key. The cheats are meant to be found, not advertised
## (DECISION_LOG 100), so the only help line says how to leave.

var _settings: MinesweeperSettings
var _font: FontFile
var _level := 0
var _mines_left := 0
var _clock_ms := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = PixelFont.get_font()


func setup(settings: MinesweeperSettings) -> void:
	_settings = settings
	_font = PixelFont.get_font()
	queue_redraw()


func refresh(level: int, mines_left: int, clock_ms: int) -> void:
	_level = level
	_mines_left = mines_left
	_clock_ms = clock_ms
	queue_redraw()


func _draw() -> void:
	if _settings == null:
		return
	var font_size := _settings.font_size
	var margin := _settings.margin
	var top := margin + float(font_size)

	draw_string(_font, Vector2(margin, top), _settings.level_name(_level),
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, _settings.text_color)
	var clock_left := margin + _text_width(_settings.level_name(_level), font_size) \
			+ float(font_size) * 1.5
	draw_string(_font, Vector2(clock_left, top), MinesweeperSave.format_clock(_clock_ms),
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, _settings.accent_text)
	_draw_right("MINES %d" % _mines_left, top, font_size, _settings.text_color)
	_draw_centred("ESC  MENU", MinesweeperSettings.FIELD.y - margin, font_size,
			_settings.dim_text)


func _draw_right(text: String, at_y: float, font_size: int, color: Color) -> void:
	var width := _text_width(text, font_size)
	draw_string(_font, Vector2(MinesweeperSettings.FIELD.x - _settings.margin - width, at_y),
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw_centred(text: String, at_y: float, font_size: int, color: Color) -> void:
	var width := _text_width(text, font_size)
	draw_string(_font, Vector2((MinesweeperSettings.FIELD.x - width) * 0.5, at_y),
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _text_width(text: String, font_size: int) -> float:
	return _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
