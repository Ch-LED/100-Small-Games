class_name MinesweeperResult
extends Control

## What the board was worth. Losing shows the time spent, because a run that
## took four minutes and blew up is a different run from one that lasted six
## seconds, and the clock is the only thing the game measured.

signal again_requested
signal menu_requested

@onready var _backdrop: ColorRect = $Backdrop
@onready var _title: Label = $Center/Column/Title
@onready var _time: Label = $Center/Column/Time
@onready var _best: Label = $Center/Column/Best
@onready var _detail: Label = $Center/Column/Detail
@onready var _hint: Label = $Center/Column/Hint


func configure(settings: MinesweeperSettings, level: int, won: bool, elapsed_ms: int,
		is_record: bool, save: MinesweeperSave) -> void:
	var font_size := settings.font_size
	_backdrop.color = settings.bg_color
	PixelFont.apply(_title, font_size * 3)
	PixelFont.apply(_time, font_size * 2)
	PixelFont.apply(_best, font_size)
	PixelFont.apply(_detail, font_size)
	PixelFont.apply(_hint, font_size)
	_title.text = "CLEARED" if won else "BOOM"
	_title.add_theme_color_override("font_color",
			settings.accent_text if won else settings.flag_color)
	_time.text = MinesweeperSave.format_time(elapsed_ms)
	_detail.text = settings.level_name(level)
	if not won:
		_best.text = ""
	elif is_record:
		_best.text = "NEW BEST"
		_best.add_theme_color_override("font_color", settings.super_color)
	else:
		_best.text = "BEST  %s" % MinesweeperSave.format_time(save.best_for(level))
		_best.add_theme_color_override("font_color", settings.dim_text)
	_hint.text = "SPACE  again   /   ESC  menu"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fire"):
		get_viewport().set_input_as_handled()
		again_requested.emit()
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		menu_requested.emit()
