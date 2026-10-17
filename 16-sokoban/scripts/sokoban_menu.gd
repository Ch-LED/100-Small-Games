class_name SokobanMenu
extends Control

## Where the run stands, and the two ways into it.

signal level_chosen(level_index: int)
signal back_requested

@onready var _backdrop: ColorRect = $Backdrop
@onready var _title: Label = $Center/Column/Title
@onready var _continue: Button = $Center/Column/Continue
@onready var _progress: Label = $Center/Column/Progress
@onready var _restart: Button = $Center/Column/Restart
@onready var _back: Button = $Center/Column/Back
@onready var _hint: Label = $Center/Column/Hint

var _next_level := 0


func _ready() -> void:
	_continue.pressed.connect(_on_continue)
	_restart.pressed.connect(_on_restart)
	_back.pressed.connect(_on_back)
	_continue.grab_focus()


func configure(settings: SokobanSettings, save: SokobanSave) -> void:
	var font_size := settings.font_size
	var count := settings.level_files().size()
	_backdrop.color = settings.bg_color
	PixelFont.apply(_title, font_size * 3)
	PixelFont.apply(_progress, font_size)
	PixelFont.apply(_hint, font_size)
	var buttons: Array[Button] = [_continue, _restart, _back]
	for button in buttons:
		button.add_theme_font_override("font", PixelFont.get_font())
		button.add_theme_font_size_override("font_size", font_size)
	_title.text = "SOKOBAN"
	_next_level = save.next_level()
	if not save.loaded:
		_progress.text = "PROGRESS UNREADABLE"
		_continue.text = "START  LEVEL 1"
		_next_level = 0
	elif _next_level >= count:
		_progress.text = "ALL %d LEVELS CLEARED" % count
		_continue.text = "PLAY AGAIN FROM 1"
		_next_level = 0
	else:
		_progress.text = "%d/%d CLEARED" % [_next_level, count]
		_continue.text = "CONTINUE  LEVEL %d" % (_next_level + 1)
	_hint.text = "ESC for the hub"


func _on_continue() -> void:
	level_chosen.emit(_next_level)


func _on_restart() -> void:
	level_chosen.emit(0)


func _on_back() -> void:
	back_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back_requested.emit()
