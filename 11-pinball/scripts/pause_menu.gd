class_name PinballPauseMenu
extends CanvasLayer
## Esc during a ball.
##
## The layer is set to run while the tree is paused, and the tree IS really
## paused -- a menu that pauses along with the game is a menu nobody can press
## (10-marble-race's lesson, kept).

signal resume_requested
signal restart_requested
signal quit_to_menu_requested

@onready var _title: Label = $Center/Column/Title
@onready var _resume: Button = $Center/Column/Resume
@onready var _restart: Button = $Center/Column/Restart
@onready var _quit: Button = $Center/Column/Quit


func _ready() -> void:
	_resume.pressed.connect(_on_resume)
	_restart.pressed.connect(_on_restart)
	_quit.pressed.connect(_on_quit)


func configure(font_size: int) -> void:
	PixelFont.apply(_title, font_size * 2)
	var buttons: Array[Button] = [_resume, _restart, _quit]
	for button in buttons:
		button.add_theme_font_override("font", PixelFont.get_font())
		button.add_theme_font_size_override("font_size", font_size)


func show_menu() -> void:
	visible = true
	get_tree().paused = true
	_resume.grab_focus()


func hide_menu() -> void:
	visible = false
	get_tree().paused = false


## Only while it is up: this layer keeps processing during a pause, which is the
## whole point of it, but it should not be answering for the game the rest of
## the time.
func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		resume_requested.emit()


func _on_resume() -> void:
	resume_requested.emit()


func _on_restart() -> void:
	restart_requested.emit()


func _on_quit() -> void:
	quit_to_menu_requested.emit()
