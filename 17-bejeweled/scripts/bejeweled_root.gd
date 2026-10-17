class_name BejeweledRoot
extends Node

## Three screens -- menu, round, result -- swapped whole, the same shape as
## 10-marble-race through 16-sokoban.

const MENU_SCENE := preload("res://17-bejeweled/scenes/menu.tscn")
const PLAY_SCENE := preload("res://17-bejeweled/scenes/play.tscn")
const RESULT_SCENE := preload("res://17-bejeweled/scenes/result.tscn")

@onready var _screens: Node = $ScreenHolder
@onready var _save: BejeweledSave = $Save
@onready var _audio: BejeweledAudio = $Audio

var _settings: BejeweledSettings


func _ready() -> void:
	_settings = BejeweledSettings.new()
	_show_menu()


func _show_menu() -> void:
	_tear_down()
	var menu: BejeweledMenu = MENU_SCENE.instantiate()
	_screens.add_child(menu)
	menu.configure(_settings, _save)
	menu.start_requested.connect(_start_round)
	menu.back_requested.connect(_back_to_hub)


func _start_round() -> void:
	_tear_down()
	var play: BejeweledPlay = PLAY_SCENE.instantiate()
	_screens.add_child(play)
	play.finished.connect(_on_finished)
	play.menu_requested.connect(_show_menu)
	play.begin(_settings, _audio, _save)


func _on_finished(score: int) -> void:
	_tear_down()
	var is_record := _save.record(score)
	if is_record:
		_audio.play(BejeweledAudio.RECORD)
	var result: BejeweledResult = RESULT_SCENE.instantiate()
	_screens.add_child(result)
	result.configure(_settings, score, is_record, _save)
	result.again_requested.connect(_start_round)
	result.menu_requested.connect(_show_menu)


func _tear_down() -> void:
	for child in _screens.get_children():
		_screens.remove_child(child)
		child.queue_free()
	get_tree().paused = false


func _back_to_hub() -> void:
	GameRouter.back_to_hub()
