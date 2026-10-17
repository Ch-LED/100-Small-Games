class_name BejeweledHud
extends Control

## Score, clock, best. Nothing here names a key (DECISION_LOG 100).

var _settings: BejeweledSettings
var _font: FontFile
var _score := 0
var _remaining := 0.0
var _best := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = PixelFont.get_font()


func setup(settings: BejeweledSettings) -> void:
	_settings = settings
	_font = PixelFont.get_font()
	queue_redraw()


func refresh(score: int, remaining: float, best: int) -> void:
	_score = score
	_remaining = remaining
	_best = best
	queue_redraw()


func _draw() -> void:
	if _settings == null:
		return
	var font_size := _settings.font_size
	var margin := _settings.margin
	var top := margin + float(font_size)
	var headline := "SCORE %d" % _score
	draw_string(_font, Vector2(margin, top), headline,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, _settings.text_color)
	var clock := "TIME %02d" % maxi(0, ceili(_remaining))
	var clock_left := margin + _text_width(headline, font_size) + float(font_size) * 1.5
	var ink := _settings.accent_text if _remaining > 10.0 else _settings.gem_color(0)
	draw_string(_font, Vector2(clock_left, top), clock,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
	var right := "BEST %d" % _best
	var width := _text_width(right, font_size)
	draw_string(_font, Vector2(BejeweledSettings.FIELD.x - margin - width, top), right,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, _settings.text_color)
	var help := "ESC  MENU"
	var help_width := _text_width(help, font_size)
	draw_string(_font, Vector2((BejeweledSettings.FIELD.x - help_width) * 0.5,
			BejeweledSettings.FIELD.y - margin), help,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, _settings.dim_text)


func _text_width(text: String, font_size: int) -> float:
	return _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
