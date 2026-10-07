extends Control
## Root of hub.tscn: shows one of the two screens based on GameRouter.landing
## and bridges their navigation requests.

@onready var _title_screen: Control = $TitleScreen
@onready var _grid_screen: Control = $GridScreen


func _ready() -> void:
	# In exported builds an *instanced* Control scene root comes back with its
	# anchors reset to the top-left (grid_screen did, title_screen did not),
	# which collapsed the desktop to 0x0 with everything drawn off-screen.
	# Pin both screens to the hub here rather than trusting the sub-scene.
	# See DECISION_LOG 019.
	_title_screen.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	_grid_screen.set_anchors_preset(Control.PRESET_FULL_RECT, true)

	_title_screen.request_start.connect(func(): show_screen("grid"))
	_grid_screen.request_back_to_title.connect(func(): show_screen("title"))
	show_screen(GameRouter.landing)


func show_screen(which: String) -> void:
	GameRouter.landing = which
	_title_screen.visible = which == "title"
	_grid_screen.visible = which == "grid"
