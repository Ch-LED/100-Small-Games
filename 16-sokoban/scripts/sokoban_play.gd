class_name SokobanPlay
extends Control

## One level, from the first step to the last box home.
##
## Two cheats, each answering the thing that actually goes wrong in Sokoban:
## a box wedged in a corner is finished (`[` lets it be dragged back), and a
## box with no way around it blocks the route (`]` walks through it). Neither
## touches the shapes of the level (spec 5).

signal finished(moves: int, pushes: int)
signal menu_requested

const PAUSE_SCENE := preload("res://16-sokoban/scenes/pause_menu.tscn")
## A solved board is worth a beat before the card covers it.
const FINISH_DELAY := 0.65

@onready var _board_view: SokobanView = $Board
@onready var _hud: SokobanHud = $Hud
@onready var _overlay: SokobanDebug = $Overlay
@onready var _pause_holder: Node = $PauseHolder

var _settings: SokobanSettings
var _audio: SokobanAudio
var _save: SokobanSave
var _level := SokobanLevel.new()
var _level_index := 0
var _level_files := PackedStringArray()
var _pull_mode := false
var _ghost := false
var _finished := false
var _finish_delay := 0.0
var _reported := false


func begin(settings: SokobanSettings, audio: SokobanAudio, save: SokobanSave,
		level_index: int) -> void:
	_settings = settings
	_audio = audio
	_save = save
	_level_files = settings.level_files()
	_level_index = clampi(level_index, 0, maxi(0, _level_files.size() - 1))
	_board_view.setup(settings)
	_hud.setup(settings)
	_overlay.setup(settings)
	_deal()
	_audio.play(SokobanAudio.START)
	_refresh()


func _process(delta: float) -> void:
	if _settings == null or not _finished or _reported:
		return
	_finish_delay += delta
	if _finish_delay >= FINISH_DELAY:
		_reported = true
		finished.emit(_level.moves, _level.pushes)


func _unhandled_input(event: InputEvent) -> void:
	if _settings == null:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_open_pause()
		return
	if event.is_action_pressed("debug_toggle"):
		_overlay.enabled = not _overlay.enabled
		_refresh_overlay()
		return
	if _finished:
		return
	if event.is_action_pressed("cheat_toggle"):
		_pull_mode = not _pull_mode
		_refresh()
		return
	if event.is_action_pressed("super_cheat_toggle"):
		_ghost = not _ghost
		_refresh()
		return
	if event.is_action_pressed(SokobanInput.UNDO):
		if _level.undo():
			_audio.play(SokobanAudio.UNDO)
			_refresh()
		return
	if event.is_action_pressed(SokobanInput.RESTART):
		_restart_level()
		return
	if event.is_action_pressed(SokobanInput.UP):
		_move(Vector2i(0, -1))
	elif event.is_action_pressed(SokobanInput.DOWN):
		_move(Vector2i(0, 1))
	elif event.is_action_pressed(SokobanInput.LEFT):
		_move(Vector2i(-1, 0))
	elif event.is_action_pressed(SokobanInput.RIGHT):
		_move(Vector2i(1, 0))


# --- moves -------------------------------------------------------------------

func _move(direction: Vector2i) -> void:
	var boxes_before := _level.boxes_on_goals()
	var result := 0
	if _ghost:
		result = _level.move_ghost(direction)
	elif _pull_mode and Input.is_action_pressed("key_x"):
		result = _level.pull(direction)
	else:
		result = _level.move(direction)
	if result == 0:
		_audio.play(SokobanAudio.BLOCKED)
		return
	if result == 2:
		_audio.play(SokobanAudio.PUSH)
	else:
		_audio.play(SokobanAudio.STEP)
	if _level.boxes_on_goals() > boxes_before:
		_audio.play(SokobanAudio.PLACED)
	_refresh()
	if _level.is_won():
		_finished = true
		_finish_delay = 0.0
		_audio.play(SokobanAudio.WIN)


func _restart_level() -> void:
	_level.restart()
	_finished = false
	_finish_delay = 0.0
	_reported = false
	_refresh()
	_audio.play(SokobanAudio.START)


# --- setup -------------------------------------------------------------------

func _deal() -> void:
	_finished = false
	_finish_delay = 0.0
	_reported = false
	_pull_mode = false
	_ghost = false
	_level = SokobanLevel.new()
	if _level_files.is_empty():
		push_error("sokoban: no levels found")
		return
	var text := FileAccess.get_file_as_string(_level_files[_level_index])
	if not _level.load_from_text(text):
		push_error("sokoban: cannot read %s" % _level_files[_level_index])
		return
	_layout()


## Dead centre, measured from the level rather than from the view: the view
## does not know its own size until refresh() hands it the board
## (DECISION_LOG 101).
func _layout() -> void:
	var board := Vector2(_level.cols * _settings.cell_size, _level.rows * _settings.cell_size)
	_board_view.position = (SokobanSettings.FIELD - board) * 0.5


func _refresh() -> void:
	_board_view.refresh(_level, _ghost)
	_hud.refresh(_level_index, _level.moves, _level.pushes, _level.boxes_on_goals(),
			_level.box_count(), _level_files.size())
	_refresh_overlay()


func _refresh_overlay() -> void:
	if not _overlay.enabled:
		_overlay.set_lines(PackedStringArray())
		return
	var lines := PackedStringArray()
	lines.append("LEVEL %d/%d  %dx%d" % [_level_index + 1, _level_files.size(),
			_level.cols, _level.rows])
	lines.append("MOVES %d  PUSHES %d  UNDO %d" % [_level.moves, _level.pushes,
			1 if _level.can_undo() else 0])
	lines.append("BOXES %d  HOME %d" % [_level.box_count(), _level.boxes_on_goals()])
	lines.append("STUCK %d" % _level.stuck_boxes())
	lines.append("PLAYER r%d c%d" % [_level.row_of(_level.player), _level.col_of(_level.player)])
	lines.append("PULL %d  GHOST %d" % [1 if _pull_mode else 0, 1 if _ghost else 0])
	var best := _save.best_for(_level_index)
	lines.append("BEST %s" % ("--" if best <= 0 else "%d moves" % best))
	_overlay.set_lines(lines)


# --- pause -------------------------------------------------------------------

func _open_pause() -> void:
	get_tree().paused = true
	var menu: SokobanPauseMenu = PAUSE_SCENE.instantiate()
	_pause_holder.add_child(menu)
	menu.configure(_settings)
	menu.resume_requested.connect(_close_pause)
	menu.restart_requested.connect(_restart_from_pause)
	menu.menu_requested.connect(_to_menu)


func _close_pause() -> void:
	_clear_pause()
	get_tree().paused = false


func _restart_from_pause() -> void:
	_clear_pause()
	get_tree().paused = false
	_restart_level()


func _to_menu() -> void:
	_clear_pause()
	get_tree().paused = false
	menu_requested.emit()


func _clear_pause() -> void:
	for child in _pause_holder.get_children():
		_pause_holder.remove_child(child)
		child.queue_free()
