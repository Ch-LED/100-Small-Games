class_name SokobanPauseMenu
extends CanvasLayer

signal resume_requested
signal restart_requested
signal menu_requested

@onready var _resume: Button = $Center/Column/Resume
@onready var _restart: Button = $Center/Column/Restart
@onready var _menu: Button = $Center/Column/Menu


func _ready() -> void:
	_resume.pressed.connect(_on_resume)
	_restart.pressed.connect(_on_restart)
	_menu.pressed.connect(_on_menu)
	_resume.grab_focus()


func configure(settings: SokobanSettings) -> void:
	var font_size := settings.font_size
	var buttons: Array[Button] = [_resume, _restart, _menu]
	for button in buttons:
		button.add_theme_font_override("font", PixelFont.get_font())
		button.add_theme_font_size_override("font_size", font_size)


func _on_resume() -> void:
	resume_requested.emit()


func _on_restart() -> void:
	restart_requested.emit()


func _on_menu() -> void:
	menu_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		resume_requested.emit()
