class_name SokobanResult
extends Control

## What the level cost. Moves, because in Sokoban the count is the score.

signal next_requested
signal menu_requested

@onready var _backdrop: ColorRect = $Backdrop
@onready var _title: Label = $Center/Column/Title
@onready var _moves: Label = $Center/Column/Time
@onready var _best: Label = $Center/Column/Best
@onready var _detail: Label = $Center/Column/Detail
@onready var _hint: Label = $Center/Column/Hint

var _has_next := true


func configure(settings: SokobanSettings, level_index: int, moves: int, is_record: bool,
		has_next: bool, save: SokobanSave) -> void:
	var font_size := settings.font_size
	_has_next = has_next
	_backdrop.color = settings.bg_color
	PixelFont.apply(_title, font_size * 3)
	PixelFont.apply(_moves, font_size * 2)
	PixelFont.apply(_best, font_size)
	PixelFont.apply(_detail, font_size)
	PixelFont.apply(_hint, font_size)
	_title.text = "LEVEL %d CLEARED" % (level_index + 1)
	_title.add_theme_color_override("font_color", settings.accent_text)
	_moves.text = "%d MOVES" % moves
	_detail.text = ""
	if is_record:
		_best.text = "NEW BEST"
		_best.add_theme_color_override("font_color", settings.super_color)
	else:
		_best.text = "BEST  %d MOVES" % save.best_for(level_index)
		_best.add_theme_color_override("font_color", settings.dim_text)
	if has_next:
		_hint.text = "SPACE  next level   /   ESC  menu"
	else:
		_hint.text = "ALL LEVELS CLEARED   /   ESC  menu"


func _unhandled_input(event: InputEvent) -> void:
	if _has_next and event.is_action_pressed("fire"):
		get_viewport().set_input_as_handled()
		next_requested.emit()
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		menu_requested.emit()
