class_name BejeweledResult
extends Control

signal again_requested
signal menu_requested

@onready var _backdrop: ColorRect = $Backdrop
@onready var _title: Label = $Center/Column/Title
@onready var _score: Label = $Center/Column/Time
@onready var _best: Label = $Center/Column/Best
@onready var _detail: Label = $Center/Column/Detail
@onready var _hint: Label = $Center/Column/Hint


func configure(settings: BejeweledSettings, score: int, is_record: bool,
		save: BejeweledSave) -> void:
	var font_size := settings.font_size
	_backdrop.color = settings.bg_color
	PixelFont.apply(_title, font_size * 3)
	PixelFont.apply(_score, font_size * 2)
	PixelFont.apply(_best, font_size)
	PixelFont.apply(_detail, font_size)
	PixelFont.apply(_hint, font_size)
	_title.text = "TIME"
	_title.add_theme_color_override("font_color", settings.accent_text)
	_score.text = str(score)
	_detail.text = "%d SECONDS" % settings.round_seconds
	if is_record:
		_best.text = "NEW BEST"
		_best.add_theme_color_override("font_color", settings.super_color)
	else:
		_best.text = "BEST  %d" % save.best_score
		_best.add_theme_color_override("font_color", settings.dim_text)
	_hint.text = "SPACE  again   /   ESC  menu"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fire"):
		get_viewport().set_input_as_handled()
		again_requested.emit()
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		menu_requested.emit()
