class_name PipesResult
extends Control

## What the level was worth. No score: in this game the time is the score, and
## the only thing to beat is your own.

signal next_requested
signal menu_requested

@onready var _backdrop: ColorRect = $Backdrop
@onready var _title: Label = $Center/Column/Title
@onready var _time: Label = $Center/Column/Time
@onready var _best: Label = $Center/Column/Best
@onready var _detail: Label = $Center/Column/Detail
@onready var _hint: Label = $Center/Column/Hint


func configure(settings: PipesSettings, mode: int, level_index: int, elapsed_ms: int,
		is_record: bool, save: PipesSave) -> void:
	var font_size := settings.font_size
	_backdrop.color = settings.bg_color
	PixelFont.apply(_title, font_size * 3)
	PixelFont.apply(_time, font_size * 2)
	PixelFont.apply(_best, font_size)
	PixelFont.apply(_detail, font_size)
	PixelFont.apply(_hint, font_size)
	_title.text = "%s  LEVEL %d CLEARED" % [PipesModes.name_of(mode), level_index + 1]
	_title.add_theme_color_override("font_color", settings.accent_text)
	_time.text = PipesSave.format_time(elapsed_ms)
	_detail.text = PipesModes.blurb_of(mode)
	if is_record:
		_best.text = "NEW BEST"
		_best.add_theme_color_override("font_color", settings.super_color)
	else:
		_best.text = "BEST  %s" % PipesSave.format_time(save.best_for(mode, level_index))
		_best.add_theme_color_override("font_color", settings.dim_text)
	_hint.text = "SPACE  next level   /   ESC  menu"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fire"):
		get_viewport().set_input_as_handled()
		next_requested.emit()
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		menu_requested.emit()
