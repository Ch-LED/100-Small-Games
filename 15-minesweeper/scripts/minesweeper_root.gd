class_name MinesweeperRoot
extends Node

## Three screens -- menu, board, result -- swapped whole, the same shape as
## 10-marble-race through 14-pipes. The root owns what outlives one board: the
## settings, the difficulty, the records and the audio player.

const MENU_SCENE := preload("res://15-minesweeper/scenes/menu.tscn")
const PLAY_SCENE := preload("res://15-minesweeper/scenes/play.tscn")
const RESULT_SCENE := preload("res://15-minesweeper/scenes/result.tscn")

@onready var _screens: Node = $ScreenHolder
@onready var _save: MinesweeperSave = $Save
@onready var _audio: MinesweeperAudio = $Audio

var _settings: MinesweeperSettings
var _level := 0


func _ready() -> void:
	_settings = MinesweeperSettings.new()
	_show_menu()


func _show_menu() -> void:
	_tear_down()
	var menu: MinesweeperMenu = MENU_SCENE.instantiate()
	_screens.add_child(menu)
	menu.configure(_settings, _save)
	menu.level_chosen.connect(_start_run)
	menu.back_requested.connect(_back_to_hub)


func _start_run(level: int) -> void:
	_level = maxi(0, level)
	_tear_down()
	var play: MinesweeperPlay = PLAY_SCENE.instantiate()
	_screens.add_child(play)
	play.finished.connect(_on_finished)
	play.menu_requested.connect(_show_menu)
	play.begin(_settings, _audio, _save, _level)


func _on_finished(won: bool, elapsed_ms: int) -> void:
	_tear_down()
	var is_record := false
	if won:
		is_record = _save.record(_level, elapsed_ms)
		_audio.play(MinesweeperAudio.RECORD if is_record else MinesweeperAudio.WIN)
	var result: MinesweeperResult = RESULT_SCENE.instantiate()
	_screens.add_child(result)
	result.configure(_settings, _level, won, elapsed_ms, is_record, _save)
	result.again_requested.connect(_restart)
	result.menu_requested.connect(_show_menu)


func _restart() -> void:
	_start_run(_level)


## Removing before freeing matters: a node queued for deletion is still alive
## for the rest of the frame, and its signals would still reach handlers that
## no longer have a board to talk about.
func _tear_down() -> void:
	for child in _screens.get_children():
		_screens.remove_child(child)
		child.queue_free()
	get_tree().paused = false


func _back_to_hub() -> void:
	GameRouter.back_to_hub()
