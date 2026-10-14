class_name PinballMenu
extends Control
## Title, best score, and the way in.
##
## The way OUT goes back to the hub, not out of the application. Quitting the
## app belongs to the hub's own title screen; a game's job is to hand the player
## back. This screen shipped with a QUIT wired to get_tree().quit() and had to
## be fixed -- 10-marble-race's menu still carries the note from when the same
## thing happened to it, which is the copy worth reading before writing a menu
## in this project (DECISION_LOG 029).

signal start_requested
signal back_requested

@onready var _title: Label = $Center/Column/Title
@onready var _best: Label = $Center/Column/Best
@onready var _start: Button = $Center/Column/Start
@onready var _back: Button = $Center/Column/Back
@onready var _hint: Label = $Center/Column/Hint


func _ready() -> void:
	_start.pressed.connect(_on_start)
	_back.pressed.connect(_on_back)


func configure(font_size: int) -> void:
	PixelFont.apply(_title, font_size * 3)
	PixelFont.apply(_best, font_size)
	PixelFont.apply(_hint, font_size)
	var buttons: Array[Button] = [_start, _back]
	for button in buttons:
		button.add_theme_font_override("font", PixelFont.get_font())
		button.add_theme_font_size_override("font_size", font_size)


## `readable` false means the file was there and could not be trusted -- said
## out loud rather than quietly showing a zero, which would read as a real
## score nobody has beaten.
func set_best(score: int, readable: bool) -> void:
	_best.text = "BEST  %d" % score if readable else "BEST  --  (SAVE UNREADABLE)"


func _on_start() -> void:
	start_requested.emit()


func _on_back() -> void:
	back_requested.emit()


## Clicking the game's own name is not the only way in: space and enter work,
## which is the project's standing rule for anything mouse-driven.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fire") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		start_requested.emit()
