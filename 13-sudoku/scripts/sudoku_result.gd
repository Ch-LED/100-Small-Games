class_name SudokuResult
extends Control

## What the solve was worth. No score: in sudoku the time is the score, and the
## only thing to beat is your own.

signal again_requested
signal menu_requested

@onready var _backdrop: ColorRect = $Backdrop
@onready var _title: Label = $Center/Column/Title
@onready var _time: Label = $Center/Column/Time
@onready var _best: Label = $Center/Column/Best
@onready var _detail: Label = $Center/Column/Detail
@onready var _hint: Label = $Center/Column/Hint


func configure(settings: SudokuSettings, difficulty: int, elapsed_ms: int,
		mistakes: int, is_record: bool, save: SudokuSave) -> void:
	var font_size := settings.font_size
	_backdrop.color = settings.bg_color
	PixelFont.apply(_title, font_size * 3)
	PixelFont.apply(_time, font_size * 2)
	PixelFont.apply(_best, font_size)
	PixelFont.apply(_detail, font_size)
	PixelFont.apply(_hint, font_size)
	_title.text = "SOLVED"
	_title.add_theme_color_override("font_color", settings.entry_color)
	_time.text = SudokuSave.format_time(elapsed_ms)
	_detail.text = "%s   /   MISTAKES %d" % [settings.difficulty_name(difficulty), mistakes]
	if is_record:
		_best.text = "NEW BEST"
		_best.add_theme_color_override("font_color", settings.super_color)
	else:
		_best.text = "BEST  %s" % SudokuSave.format_time(save.best_for(difficulty))
		_best.add_theme_color_override("font_color", settings.note_color)
	_hint.text = "SPACE  another   /   ESC  menu"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fire"):
		get_viewport().set_input_as_handled()
		again_requested.emit()
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		menu_requested.emit()
