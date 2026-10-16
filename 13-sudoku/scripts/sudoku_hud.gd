class_name SudokuHud
extends Control

## The standing readout: which difficulty, the clock, how much is left, and
## which of the three modes are on. Draws itself rather than juggling Labels,
## so every line shares one font pass and one margin (spec 7).

var _settings: SudokuSettings
var _font: FontFile
var _difficulty := ""
var _clock_ms := 0
var _blanks := 0
var _pencil := false
var _hints := false
var _auto := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = PixelFont.get_font()


func setup(settings: SudokuSettings) -> void:
	_settings = settings
	_font = PixelFont.get_font()
	queue_redraw()


func refresh(difficulty: String, clock_ms: int, blanks: int,
		pencil: bool, hints: bool, auto: bool) -> void:
	_difficulty = difficulty
	_clock_ms = clock_ms
	_blanks = blanks
	_pencil = pencil
	_hints = hints
	_auto = auto
	queue_redraw()


func _draw() -> void:
	if _settings == null:
		return
	var font_size := _settings.font_size
	var margin := _settings.margin
	var top := margin + float(font_size)

	draw_string(_font, Vector2(margin, top), _difficulty,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, _settings.given_color)
	var clock_text := "TIME  %s" % SudokuSave.format_clock(_clock_ms)
	var clock_left := margin + _text_width(_difficulty, font_size) + float(font_size) * 1.5
	draw_string(_font, Vector2(clock_left, top), clock_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, _settings.entry_color)
	_draw_right("BLANKS  %d" % _blanks, top, font_size, _settings.given_color)

	# The three switches stack on their own line, each in its own colour, so
	# "which cheats are on" is answered without reading a word.
	var badges: Array[Array] = []
	if _pencil:
		badges.append(["PENCIL", _settings.note_color])
	if _hints:
		badges.append(["CANDIDATES", _settings.auto_note_color])
	if _auto:
		badges.append(["ANSWER", _settings.super_color])
	var badge_y := top + float(font_size) * 1.6
	for badge in badges:
		var text: String = badge[0]
		var width := _text_width(text, font_size)
		draw_string(_font, Vector2(SudokuSettings.FIELD.x - margin - width, badge_y),
				text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, badge[1])
		badge_y += float(font_size) * 1.4

	var help := "ARROWS MOVE   1-9 ENTER   Z PENCIL   BKSP CLEAR   ESC MENU"
	var help_width := _text_width(help, font_size)
	draw_string(_font, Vector2((SudokuSettings.FIELD.x - help_width) * 0.5,
			SudokuSettings.FIELD.y - margin), help,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, _settings.note_color)


func _draw_right(text: String, at_y: float, font_size: int, color: Color) -> void:
	var width := _text_width(text, font_size)
	draw_string(_font, Vector2(SudokuSettings.FIELD.x - _settings.margin - width, at_y),
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _text_width(text: String, font_size: int) -> float:
	return _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
