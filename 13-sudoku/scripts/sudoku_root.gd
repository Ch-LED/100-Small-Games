class_name SudokuRoot
extends Node

## Three screens -- menu, puzzle, result -- swapped whole, the same shape as
## 10-marble-race, 11-pinball and 12-tetris. The root owns what outlives one
## puzzle: the settings, the difficulty, the records and the audio player.

const MENU_SCENE := preload("res://13-sudoku/scenes/menu.tscn")
const PLAY_SCENE := preload("res://13-sudoku/scenes/play.tscn")
const RESULT_SCENE := preload("res://13-sudoku/scenes/result.tscn")

@onready var _screens: Node = $ScreenHolder
@onready var _save: SudokuSave = $Save
@onready var _audio: SudokuAudio = $Audio

var _settings: SudokuSettings
var _difficulty := 0


func _ready() -> void:
	_settings = SudokuSettings.new()
	_show_menu()


func _show_menu() -> void:
	_tear_down()
	var menu: SudokuMenu = MENU_SCENE.instantiate()
	_screens.add_child(menu)
	menu.configure(_settings, _save)
	menu.difficulty_chosen.connect(_start_run)
	menu.back_requested.connect(_back_to_hub)


func _start_run(difficulty: int) -> void:
	_difficulty = difficulty
	_tear_down()
	var play: SudokuPlay = PLAY_SCENE.instantiate()
	_screens.add_child(play)
	play.solved.connect(_on_solved)
	play.menu_requested.connect(_show_menu)
	play.begin(_settings, _audio, _save, difficulty)


func _on_solved(elapsed_ms: int, mistakes: int) -> void:
	_tear_down()
	var is_record := _save.record(_difficulty, elapsed_ms)
	if is_record:
		_audio.play(SudokuAudio.RECORD)
	var result: SudokuResult = RESULT_SCENE.instantiate()
	_screens.add_child(result)
	result.configure(_settings, _difficulty, elapsed_ms, mistakes, is_record, _save)
	result.again_requested.connect(_restart)
	result.menu_requested.connect(_show_menu)


func _restart() -> void:
	_start_run(_difficulty)


## Removing before freeing matters: a node queued for deletion is still alive
## for the rest of the frame, and its signals would still reach handlers that
## no longer have a puzzle to talk about.
func _tear_down() -> void:
	for child in _screens.get_children():
		_screens.remove_child(child)
		child.queue_free()
	get_tree().paused = false


func _back_to_hub() -> void:
	GameRouter.back_to_hub()
