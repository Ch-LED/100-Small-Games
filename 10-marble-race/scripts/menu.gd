class_name MarbleMenu
extends Control
## Title screen. Same shape as 00-hub's: a title, one way in, one way out, and
## nothing else competing for attention.
##
## The one way out goes back to the hub, and it is reachable with the mouse as
## well as Esc. It used to be a QUIT button wired to quit_app(), which meant the
## only mouse-reachable way off this screen shut the whole application down —
## quitting the app belongs to the hub (00-hub's title screen has it), and a
## game's job is to hand the player back.

signal start_pressed
signal back_pressed

@onready var _title: Label = $Title
@onready var _start: Button = $Start
@onready var _back: Button = $Back


func configure(settings: Dictionary) -> void:
	var size := int(settings.hud.font_size)
	PixelFont.apply(_title, size * 4)
	for button in [_start, _back]:
		button.add_theme_font_override("font", PixelFont.get_font())
		button.add_theme_font_size_override("font_size", size * 2)


func _ready() -> void:
	_start.pressed.connect(func() -> void: start_pressed.emit())
	_back.pressed.connect(func() -> void: back_pressed.emit())
	_start.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		back_pressed.emit()
