class_name MarbleMenu
extends Control
## Title screen. Same shape as 00-hub's: a title, one way in, one way out, and
## nothing else competing for attention.

signal start_pressed
signal quit_pressed
signal back_pressed

@onready var _title: Label = $Title
@onready var _start: Button = $Start
@onready var _quit: Button = $Quit


func configure(settings: Dictionary) -> void:
	var size := int(settings.hud.font_size)
	PixelFont.apply(_title, size * 4)
	for button in [_start, _quit]:
		button.add_theme_font_override("font", PixelFont.get_font())
		button.add_theme_font_size_override("font_size", size * 2)


func _ready() -> void:
	_start.pressed.connect(func() -> void: start_pressed.emit())
	_quit.pressed.connect(func() -> void: quit_pressed.emit())
	_start.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		back_pressed.emit()
