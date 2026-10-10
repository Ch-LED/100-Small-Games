class_name MarbleHud
extends CanvasLayer
## The race clock along the top, and one line of status under it.

@onready var _time: Label = $Time
@onready var _message: Label = $Message


func configure(settings: Dictionary) -> void:
	var hud: Dictionary = settings.hud
	PixelFont.apply(_time, int(hud.font_size))
	PixelFont.apply(_message, int(hud.font_size))
	_time.add_theme_color_override("font_color", hud.time_color)
	_message.add_theme_color_override("font_color", hud.message_color)


func set_time(seconds: float) -> void:
	_time.text = "TIME %s" % format_time(seconds)


func set_message(text: String) -> void:
	_message.text = text


## mm:ss.hh. Hundredths rather than thousandths: this has to be readable at a
## glance while moving, and the pixel font is wide.
static func format_time(seconds: float) -> String:
	var total := maxf(seconds, 0.0)
	var minutes := int(total / 60.0)
	return "%02d:%05.2f" % [minutes, total - float(minutes) * 60.0]
