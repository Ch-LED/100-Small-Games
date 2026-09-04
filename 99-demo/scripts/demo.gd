extends Control
## Minimal template game: shows a solid screen and returns to the hub.
## Copy this folder structure as the skeleton for a new real game.

@onready var _back_button: Button = $Center/VBox/BackButton


func _ready() -> void:
	_back_button.pressed.connect(func(): GameRouter.back_to_hub())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		GameRouter.back_to_hub()
