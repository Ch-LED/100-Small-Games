extends Control
## Title screen: logo, start, fullscreen toggle and quit. Emits request_start
## when the player begins; screen switching is handled by hub_root.

signal request_start

@onready var _start_button: Button = $Center/VBox/StartButton
@onready var _fullscreen_button: Button = $Center/VBox/SubButtons/FullscreenButton
@onready var _quit_button: Button = $Center/VBox/SubButtons/QuitButton


func _ready() -> void:
	_start_button.pressed.connect(func(): request_start.emit())
	_fullscreen_button.pressed.connect(_toggle_fullscreen)
	_quit_button.pressed.connect(func(): GameRouter.quit_app())


func _toggle_fullscreen() -> void:
	var ds := DisplayServer
	if ds.window_get_mode() == ds.WINDOW_MODE_FULLSCREEN:
		ds.window_set_mode(ds.WINDOW_MODE_WINDOWED)
	else:
		ds.window_set_mode(ds.WINDOW_MODE_FULLSCREEN)
