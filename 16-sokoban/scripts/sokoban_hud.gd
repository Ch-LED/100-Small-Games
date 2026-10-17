class_name SokobanHud
extends Control

## The standing readout: which level, moves, pushes, boxes home.
##
## Nothing here names a key -- the cheats are meant to be found
## (DECISION_LOG 100). The only help line says how to leave.

var _settings: SokobanSettings
var _font: FontFile
var _level := 0
var _moves := 0
var _pushes := 0
var _placed := 0
var _boxes := 0
var _total := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = PixelFont.get_font()


func setup(settings: SokobanSettings) -> void:
	_settings = settings
	_font = PixelFont.get_font()
	queue_redraw()


func refresh(level: int, moves: int, pushes: int, placed: int, boxes: int, total: int) -> void:
	_level = level
	_moves = moves
	_pushes = pushes
	_placed = placed
	_boxes = boxes
	_total = total
	queue_redraw()


func _draw() -> void:
	if _settings == null:
		return
	var font_size := _settings.font_size
	var margin := _settings.margin
	var top := margin + float(font_size)
	var headline := "LEVEL %d/%d" % [_level + 1, _total]
	draw_string(_font, Vector2(margin, top), headline,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, _settings.text_color)
	var info_left := margin + _text_width(headline, font_size) + float(font_size) * 1.5
	draw_string(_font, Vector2(info_left, top), "MOVES %d   PUSHES %d" % [_moves, _pushes],
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, _settings.accent_text)
	var right := "BOXES %d/%d" % [_placed, _boxes]
	var width := _text_width(right, font_size)
	draw_string(_font, Vector2(SokobanSettings.FIELD.x - margin - width, top), right,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, _settings.text_color)
	var help := "ESC  MENU"
	var help_width := _text_width(help, font_size)
	draw_string(_font, Vector2((SokobanSettings.FIELD.x - help_width) * 0.5,
			SokobanSettings.FIELD.y - margin), help,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, _settings.dim_text)


func _text_width(text: String, font_size: int) -> float:
	return _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
