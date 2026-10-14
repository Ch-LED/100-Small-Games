class_name TetrisRoot
extends Node

## Three screens -- menu, run, result -- swapped whole, the same shape as
## 10-marble-race and 11-pinball. The root owns what outlives a single run:
## the settings, the mode, the records and the audio player.

const MENU_SCENE := preload("res://12-tetris/scenes/menu.tscn")
const PLAY_SCENE := preload("res://12-tetris/scenes/play.tscn")
const RESULT_SCENE := preload("res://12-tetris/scenes/result.tscn")
const TUTORIAL_SCENE := preload("res://12-tetris/scenes/tutorial.tscn")

@onready var _screens: Node = $ScreenHolder
@onready var _save: TetrisSave = $Save
@onready var _audio: TetrisAudio = $Audio

var _settings: TetrisSettings
var _mode: int = TetrisPlay.Mode.MARATHON


func _ready() -> void:
	_settings = TetrisSettings.new()
	_show_menu()


func _show_menu() -> void:
	_tear_down()
	var menu: TetrisMenu = MENU_SCENE.instantiate()
	_screens.add_child(menu)
	menu.configure(_settings, _save.best_score, _save.best_sprint_ms, _save.loaded)
	menu.mode_chosen.connect(_start_run)
	menu.back_requested.connect(_back_to_hub)


func _start_run(mode: int) -> void:
	_mode = mode
	_tear_down()
	if mode == TetrisPlay.Mode.TUTORIAL:
		_start_tutorial()
		return
	var play: TetrisPlay = PLAY_SCENE.instantiate()
	_screens.add_child(play)
	play.finished.connect(_on_run_finished)
	play.restart_requested.connect(_on_restart)
	play.menu_requested.connect(_show_menu)
	play.begin(_settings, _mode, _audio)


func _on_run_finished(outcome: int, score: int, lines: int, elapsed_ms: int) -> void:
	_tear_down()
	var is_record := false
	if _mode == TetrisPlay.Mode.SPRINT:
		is_record = _save.record_sprint(elapsed_ms)
	else:
		is_record = _save.record_marathon(score)
	_audio.play(TetrisAudio.RECORD if is_record else TetrisAudio.TOPOUT)
	var result: TetrisResult = RESULT_SCENE.instantiate()
	_screens.add_child(result)
	result.configure(_settings, _mode, outcome, score, lines, elapsed_ms, is_record, _save)
	result.again_requested.connect(_on_restart)
	result.menu_requested.connect(_show_menu)


## The tutorial keeps no records, so it hands back to the menu when it is done
## rather than to a result card.
func _start_tutorial() -> void:
	var tutorial: TetrisTutorial = TUTORIAL_SCENE.instantiate()
	_screens.add_child(tutorial)
	tutorial.finished.connect(_show_menu)
	tutorial.quit_requested.connect(_show_menu)
	tutorial.begin(_settings, _audio)


func _on_restart() -> void:
	_start_run(_mode)


## Removing before freeing matters: a node that has been queued for deletion is
## still alive for the rest of the frame, and its signals would still reach
## handlers that no longer have a run to talk about.
func _tear_down() -> void:
	for child in _screens.get_children():
		_screens.remove_child(child)
		child.queue_free()
	get_tree().paused = false


func _back_to_hub() -> void:
	GameRouter.back_to_hub()
