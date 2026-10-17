class_name SokobanRoot
extends Node

## Three screens -- menu, level, result -- swapped whole, the same shape as
## 10-marble-race through 15-minesweeper.

const MENU_SCENE := preload("res://16-sokoban/scenes/menu.tscn")
const PLAY_SCENE := preload("res://16-sokoban/scenes/play.tscn")
const RESULT_SCENE := preload("res://16-sokoban/scenes/result.tscn")

@onready var _screens: Node = $ScreenHolder
@onready var _save: SokobanSave = $Save
@onready var _audio: SokobanAudio = $Audio

var _settings: SokobanSettings
var _level_index := 0


func _ready() -> void:
	_settings = SokobanSettings.new()
	_show_menu()


func _show_menu() -> void:
	_tear_down()
	var menu: SokobanMenu = MENU_SCENE.instantiate()
	_screens.add_child(menu)
	menu.configure(_settings, _save)
	menu.level_chosen.connect(_start_run)
	menu.back_requested.connect(_back_to_hub)


func _start_run(level_index: int) -> void:
	var count := _settings.level_files().size()
	_level_index = clampi(level_index, 0, maxi(0, count - 1))
	_tear_down()
	var play: SokobanPlay = PLAY_SCENE.instantiate()
	_screens.add_child(play)
	play.finished.connect(_on_finished)
	play.menu_requested.connect(_show_menu)
	play.begin(_settings, _audio, _save, _level_index)


func _on_finished(moves: int, _pushes: int) -> void:
	_tear_down()
	var is_record := _save.record(_level_index, moves)
	if is_record:
		_audio.play(SokobanAudio.RECORD)
	var has_next := _level_index + 1 < _settings.level_files().size()
	var result: SokobanResult = RESULT_SCENE.instantiate()
	_screens.add_child(result)
	result.configure(_settings, _level_index, moves, is_record, has_next, _save)
	result.next_requested.connect(_next_level)
	result.menu_requested.connect(_show_menu)


func _next_level() -> void:
	_start_run(_level_index + 1)


func _tear_down() -> void:
	for child in _screens.get_children():
		_screens.remove_child(child)
		child.queue_free()
	get_tree().paused = false


func _back_to_hub() -> void:
	GameRouter.back_to_hub()
