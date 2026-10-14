class_name TetrisMenu
extends Control

## Title, the two records, and the two ways in.
##
## The way out goes back to the hub, never out of the application: quitting
## belongs to the hub's own title screen, and a game's job is to hand the
## player back (CONSTITUTION 一, DECISION_LOG 029).

signal mode_chosen(mode: int)
signal back_requested

@onready var _backdrop: ColorRect = $Backdrop
@onready var _title: Label = $Center/Column/Title
@onready var _marathon: Button = $Center/Column/Marathon
@onready var _marathon_best: Label = $Center/Column/MarathonBest
@onready var _sprint: Button = $Center/Column/Sprint
@onready var _sprint_best: Label = $Center/Column/SprintBest
@onready var _tutorial: Button = $Center/Column/Tutorial
@onready var _back: Button = $Center/Column/Back
@onready var _hint: Label = $Center/Column/Hint


func _ready() -> void:
	_marathon.pressed.connect(_on_marathon)
	_sprint.pressed.connect(_on_sprint)
	_tutorial.pressed.connect(_on_tutorial)
	_back.pressed.connect(_on_back)
	_marathon.grab_focus()


## `readable` false means the file was there and could not be trusted -- said
## out loud rather than quietly showing a zero, which would read as a real
## record nobody has beaten (spec 11).
func configure(settings: TetrisSettings, best_score: int, best_time_ms: int, readable: bool) -> void:
	var size := settings.font_size
	_backdrop.color = settings.board_bg
	PixelFont.apply(_title, size * 3)
	PixelFont.apply(_marathon_best, size)
	PixelFont.apply(_sprint_best, size)
	PixelFont.apply(_hint, size)
	var buttons: Array[Button] = [_marathon, _sprint, _tutorial, _back]
	for button in buttons:
		button.add_theme_font_override("font", PixelFont.get_font())
		button.add_theme_font_size_override("font_size", size)
	_title.text = "TETRIS"
	_hint.text = "ENTER to start   /   ESC for the hub"
	if readable:
		_marathon_best.text = "BEST  %d" % best_score
		_sprint_best.text = "FASTEST  %s" % TetrisSave.format_time(best_time_ms)
	else:
		_marathon_best.text = "BEST  --  (SAVE UNREADABLE)"
		_sprint_best.text = "FASTEST  --"


func _on_marathon() -> void:
	mode_chosen.emit(TetrisPlay.Mode.MARATHON)


func _on_sprint() -> void:
	mode_chosen.emit(TetrisPlay.Mode.SPRINT)


func _on_tutorial() -> void:
	mode_chosen.emit(TetrisPlay.Mode.TUTORIAL)


func _on_back() -> void:
	back_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back_requested.emit()
