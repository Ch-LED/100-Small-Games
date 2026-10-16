class_name SudokuMenu
extends Control

## Difficulty, the fastest solve for each, and the way out.
##
## The way out goes back to the hub, never out of the application: quitting
## belongs to the hub's own title screen, and a game's job is to hand the
## player back (CONSTITUTION 一, DECISION_LOG 029).

signal difficulty_chosen(difficulty: int)
signal back_requested

@onready var _backdrop: ColorRect = $Backdrop
@onready var _title: Label = $Center/Column/Title
@onready var _easy: Button = $Center/Column/Easy
@onready var _easy_best: Label = $Center/Column/EasyBest
@onready var _normal: Button = $Center/Column/Normal
@onready var _normal_best: Label = $Center/Column/NormalBest
@onready var _hard: Button = $Center/Column/Hard
@onready var _hard_best: Label = $Center/Column/HardBest
@onready var _back: Button = $Center/Column/Back
@onready var _hint: Label = $Center/Column/Hint


func _ready() -> void:
	_easy.pressed.connect(_on_difficulty.bind(0))
	_normal.pressed.connect(_on_difficulty.bind(1))
	_hard.pressed.connect(_on_difficulty.bind(2))
	_back.pressed.connect(_on_back)
	_easy.grab_focus()


## `readable` false means the file was there and could not be trusted -- said
## out loud rather than quietly showing a dash, which would read as "nobody has
## ever finished this" (spec 11).
func configure(settings: SudokuSettings, save: SudokuSave) -> void:
	var font_size := settings.font_size
	_backdrop.color = settings.bg_color
	PixelFont.apply(_title, font_size * 3)
	PixelFont.apply(_easy_best, font_size)
	PixelFont.apply(_normal_best, font_size)
	PixelFont.apply(_hard_best, font_size)
	PixelFont.apply(_hint, font_size)
	var buttons: Array[Button] = [_easy, _normal, _hard, _back]
	for button in buttons:
		button.add_theme_font_override("font", PixelFont.get_font())
		button.add_theme_font_size_override("font_size", font_size)
	_title.text = "SUDOKU"
	var rows: Array[Array] = [[_easy, _easy_best, 0], [_normal, _normal_best, 1],
			[_hard, _hard_best, 2]]
	for row in rows:
		var button: Button = row[0]
		var best: Label = row[1]
		var difficulty: int = row[2]
		button.text = settings.difficulty_name(difficulty)
		if difficulty >= settings.difficulty_count():
			button.visible = false
			best.visible = false
			continue
		best.text = "BEST  %s" % SudokuSave.format_time(save.best_for(difficulty))
		if not save.loaded:
			best.text = "BEST  --  (SAVE UNREADABLE)"
	_hint.text = "ENTER to start   /   ESC for the hub"
	_back.text = "BACK TO HUB"


func _on_difficulty(difficulty: int) -> void:
	difficulty_chosen.emit(difficulty)


func _on_back() -> void:
	back_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back_requested.emit()
