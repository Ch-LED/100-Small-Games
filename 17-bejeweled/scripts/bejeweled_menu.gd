class_name BejeweledMenu
extends Control

## Title, the best score, and the way in.

signal start_requested
signal back_requested

@onready var _backdrop: ColorRect = $Backdrop
@onready var _title: Label = $Center/Column/Title
@onready var _best: Label = $Center/Column/Best
@onready var _start: Button = $Center/Column/Start
@onready var _back: Button = $Center/Column/Back
@onready var _hint: Label = $Center/Column/Hint


func _ready() -> void:
	_start.pressed.connect(_on_start)
	_back.pressed.connect(_on_back)
	_start.grab_focus()


func configure(settings: BejeweledSettings, save: BejeweledSave) -> void:
	var font_size := settings.font_size
	_backdrop.color = settings.bg_color
	PixelFont.apply(_title, font_size * 3)
	PixelFont.apply(_best, font_size)
	PixelFont.apply(_hint, font_size)
	var buttons: Array[Button] = [_start, _back]
	for button in buttons:
		button.add_theme_font_override("font", PixelFont.get_font())
		button.add_theme_font_size_override("font_size", font_size)
	_title.text = "GEMS"
	if save.loaded:
		_best.text = "BEST  %d" % save.best_score
	else:
		_best.text = "BEST  --  (SAVE UNREADABLE)"
	_start.text = "PLAY  %d SECONDS" % settings.round_seconds
	_hint.text = "ESC for the hub"


func _on_start() -> void:
	start_requested.emit()


func _on_back() -> void:
	back_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back_requested.emit()
