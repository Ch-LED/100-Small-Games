extends Control
## Root of hub.tscn: shows one of the two screens based on GameRouter.landing
## and bridges their navigation requests.

@onready var _title_screen: Control = $TitleScreen
@onready var _grid_screen: Control = $GridScreen


func _ready() -> void:
	_title_screen.request_start.connect(func(): show_screen("grid"))
	_grid_screen.request_back_to_title.connect(func(): show_screen("title"))
	show_screen(GameRouter.landing)


func show_screen(which: String) -> void:
	GameRouter.landing = which
	_title_screen.visible = which == "title"
	_grid_screen.visible = which == "grid"
