class_name PipesRoot
extends Node

## Three screens -- menu, level, result -- swapped whole, the same shape as
## 10-marble-race through 13-sudoku. The root owns what outlives one level: the
## settings, which mode is being played, how far it has got, the records and
## the audio player.
##
## Two play scenes, not four. LINK has a board of its own; the other three play
## on a pipe grid and share one screen, so the split here is on what kind of
## board it is, not on how many modes there are (spec 3).

const MENU_SCENE := preload("res://14-pipes/scenes/menu.tscn")
const LINK_SCENE := preload("res://14-pipes/scenes/play.tscn")
const NET_SCENE := preload("res://14-pipes/scenes/play_net.tscn")
const RESULT_SCENE := preload("res://14-pipes/scenes/result.tscn")

@onready var _screens: Node = $ScreenHolder
@onready var _save: PipesSave = $Save
@onready var _audio: PipesAudio = $Audio

var _settings: PipesSettings
var _mode := PipesModes.LINK
var _level_index := 0


func _ready() -> void:
	_settings = PipesSettings.new()
	_show_menu()


func _show_menu() -> void:
	_tear_down()
	var menu: PipesMenu = MENU_SCENE.instantiate()
	_screens.add_child(menu)
	menu.configure(_settings, _save)
	menu.mode_chosen.connect(_start_run)
	menu.back_requested.connect(_back_to_hub)


func _start_run(mode: int, level_index: int) -> void:
	_mode = mode
	_level_index = maxi(0, level_index)
	_tear_down()
	if PipesModes.uses_net(mode):
		var net_play: PipesNetPlay = NET_SCENE.instantiate()
		_screens.add_child(net_play)
		net_play.solved.connect(_on_solved)
		net_play.menu_requested.connect(_show_menu)
		net_play.begin(_settings, _audio, _save, _level_index, mode)
		return
	var play: PipesPlay = LINK_SCENE.instantiate()
	_screens.add_child(play)
	play.solved.connect(_on_solved)
	play.menu_requested.connect(_show_menu)
	play.begin(_settings, _audio, _save, _level_index)


func _on_solved(elapsed_ms: int) -> void:
	_tear_down()
	var is_record := _save.record(_mode, _level_index, elapsed_ms)
	if is_record:
		_audio.play(PipesAudio.RECORD)
	var result: PipesResult = RESULT_SCENE.instantiate()
	_screens.add_child(result)
	result.configure(_settings, _mode, _level_index, elapsed_ms, is_record, _save)
	result.next_requested.connect(_next_level)
	result.menu_requested.connect(_show_menu)


func _next_level() -> void:
	_start_run(_mode, _level_index + 1)


## Removing before freeing matters: a node queued for deletion is still alive
## for the rest of the frame, and its signals would still reach handlers that
## no longer have a level to talk about.
func _tear_down() -> void:
	for child in _screens.get_children():
		_screens.remove_child(child)
		child.queue_free()
	get_tree().paused = false


func _back_to_hub() -> void:
	GameRouter.back_to_hub()
