class_name MarbleRaceRoot
extends Node
## Owns the screens and the only switch between them. 00-hub does the same job
## one level up, for the games themselves: a title, a list, and the thing you
## came for.
##
## The root is a plain Node rather than a Control because it holds a 2D menu
## and a 3D level at different times, and neither of them should have to be
## told what the other one is.

const MENU := "res://10-marble-race/scenes/menu.tscn"
const LEVEL_SELECT := "res://10-marble-race/scenes/level_select.tscn"
const FALLBACK_TRACK := "res://10-marble-race/scenes/race.tscn"

@onready var _stage: Node = $Stage

var _cfg: Dictionary = {}
var _index: RaceTrackIndex
var _save: MarbleSave


func _ready() -> void:
	_cfg = RaceSettings.load_all()
	_index = RaceTrackIndex.load_index()
	_save = MarbleSave.load_from_disk()
	show_menu()


func show_menu() -> void:
	# Entered first, configured second: a screen's configure() runs against
	# @onready references, and those only resolve once the node is in the tree.
	var screen: MarbleMenu = _clear_and_instantiate(MENU)
	_stage.add_child(screen)
	screen.configure(_cfg)
	screen.start_pressed.connect(show_level_select)
	screen.quit_pressed.connect(GameRouter.quit_app)
	screen.back_pressed.connect(GameRouter.back_to_hub)


func show_level_select() -> void:
	var screen: MarbleLevelSelect = _clear_and_instantiate(LEVEL_SELECT)
	_stage.add_child(screen)
	screen.configure(_index, _save, _cfg)
	screen.track_chosen.connect(show_race)
	screen.back_pressed.connect(show_menu)


func show_race(track_id: String) -> void:
	var screen: Node = _clear_and_instantiate(_scene_for(track_id))
	# Set before the node enters the tree: _ready() runs on add_child, and a
	# level that has already started does not want to be told which track it is.
	screen.set("track_id", track_id)
	screen.set("best_time", _save.best(track_id))
	screen.connect("finished", _on_finished)
	screen.connect("back_pressed", show_level_select)
	_stage.add_child(screen)


func _on_finished(track_id: String, seconds: float) -> void:
	if _save.record(track_id, seconds):
		print("MarbleRace: best on %s is now %s"
				% [track_id, MarbleSave.format(seconds)])


func _scene_for(track_id: String) -> String:
	for track in _index.tracks:
		if track.id == track_id:
			return track.scene_path
	push_error("MarbleRaceRoot: %s is not in the index" % track_id)
	return FALLBACK_TRACK


## Screens are swapped, not hidden and shown. A screen that has been freed
## cannot carry state into the next one, and nothing here is expensive enough
## to be worth keeping alive between visits.
func _clear_and_instantiate(path: String) -> Node:
	for child in _stage.get_children():
		_stage.remove_child(child)
		child.queue_free()
	return load(path).instantiate()
