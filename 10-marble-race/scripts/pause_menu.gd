class_name MarblePauseMenu
extends CanvasLayer
## Three ways out of a level, and no fourth. The tree is paused while this is
## up, so nothing behind it keeps running — and this node is set to keep
## processing anyway, because a menu that pauses with everything else is a menu
## nothing can press.

signal resume_pressed
signal restart_pressed
signal levels_pressed

@onready var _title: Label = $Panel/Title
@onready var _resume: Button = $Panel/Resume
@onready var _restart: Button = $Panel/Restart
@onready var _levels: Button = $Panel/Levels


func configure(settings: Dictionary) -> void:
	var size := int(settings.hud.font_size)
	PixelFont.apply(_title, size * 3)
	for button in [_resume, _restart, _levels]:
		button.add_theme_font_override("font", PixelFont.get_font())
		button.add_theme_font_size_override("font_size", size * 2)


func _ready() -> void:
	_resume.pressed.connect(func() -> void: resume_pressed.emit())
	_restart.pressed.connect(func() -> void: restart_pressed.emit())
	_levels.pressed.connect(func() -> void: levels_pressed.emit())
	_resume.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		resume_pressed.emit()
