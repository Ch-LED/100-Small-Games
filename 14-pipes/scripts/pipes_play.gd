class_name PipesPlay
extends Control

## A single level, from deal to joined.
##
## Everything a run needs lives here: the level, the clock, the two cheats and
## the undo stack. The root only hears `solved` and decides what a record is
## worth -- the same split as 11-pinball and 12-tetris (spec 6).

signal solved(elapsed_ms: int)
signal menu_requested

const PAUSE_SCENE := preload("res://14-pipes/scenes/pause_menu.tscn")
## A solved board is worth looking at before the card covers it.
const FINISH_DELAY := 0.7

@onready var _board_view: PipesBoardView = $Board
@onready var _hud: PipesHud = $Hud
@onready var _overlay: PipesDebug = $Overlay
@onready var _pause_holder: Node = $PauseHolder

var _settings: PipesSettings
var _audio: PipesAudio
var _save: PipesSave
var _rng := RandomNumberGenerator.new()
var _level := PipesLevel.new()
var _level_index := 0
var _hint_color := -1
var _bridges := false
var _elapsed_ms := 0
var _finish_delay := 0.0
var _finished := false
var _last_clock_second := -1
var _draw_step := 0
var _hovered := -1


func begin(settings: PipesSettings, audio: PipesAudio, save: PipesSave,
		level_index: int) -> void:
	_settings = settings
	_audio = audio
	_save = save
	_level_index = level_index
	_board_view.setup(settings)
	_hud.setup(settings)
	_overlay.setup(settings)
	# Guarded, because begin() may be called again on the same screen: a restart
	# rebuilds the board without rebuilding the node.
	if not _board_view.cell_pressed.is_connected(_on_cell_pressed):
		_board_view.cell_pressed.connect(_on_cell_pressed)
	if not _board_view.cell_dragged.is_connected(_on_cell_dragged):
		_board_view.cell_dragged.connect(_on_cell_dragged)
	if not _board_view.cell_released.is_connected(_on_cell_released):
		_board_view.cell_released.connect(_on_cell_released)
	_deal()
	_audio.play(PipesAudio.START)
	_refresh()


func _process(delta: float) -> void:
	# The root calls begin() in the same frame it adds this node, so there is
	# normally no tick without a level. This is here so a frame arriving early
	# reports nothing rather than reading an unset board.
	if _settings == null:
		return
	if _finished:
		_finish_delay += delta
		if _finish_delay >= FINISH_DELAY:
			_finished = false
			solved.emit(_elapsed_ms)
		return
	_elapsed_ms += int(delta * 1000.0)
	# The clock only needs redrawing when its visible digits change; the board
	# is redrawn on input only.
	var second := _elapsed_ms / 1000
	if second != _last_clock_second:
		_last_clock_second = second
		_refresh_hud()


func _unhandled_input(event: InputEvent) -> void:
	if _finished:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_open_pause()
		return
	if event.is_action_pressed("debug_toggle"):
		_overlay.enabled = not _overlay.enabled
		_refresh_overlay()
		return
	if event.is_action_pressed("cheat_toggle"):
		_cycle_hint()
		_refresh()
		return
	if event.is_action_pressed("super_cheat_toggle"):
		_bridges = not _bridges
		_refresh()
		return
	if event.is_action_pressed(PipesInput.UNDO):
		if _level.undo():
			_audio.play(PipesAudio.CLEAR)
			_hint_color = -1
		_refresh()
		return
	if event.is_action_pressed(PipesInput.ERASE):
		_erase_under_mouse()
		return


# --- strokes -----------------------------------------------------------------

func _on_cell_pressed(cell: int) -> void:
	if _finished:
		return
	var color := _endpoint_color_at(cell)
	if color < 0:
		return
	_level.begin_stroke(color, cell)
	_draw_step = 0
	_hint_color = -1
	_refresh()


func _on_cell_dragged(cell: int) -> void:
	if _finished or not _level.is_stroking():
		return
	if not _level.extend_stroke(cell, _bridges):
		return
	_draw_step += 1
	_audio.play_draw(_draw_step)
	_refresh()
	_check_solved()


func _on_cell_released() -> void:
	if not _level.is_stroking():
		return
	var color := _level.stroke_color()
	_level.end_stroke()
	if _level.is_color_done(color):
		_audio.play(PipesAudio.JOIN)
	_refresh()


func _endpoint_color_at(cell: int) -> int:
	for color in _level.color_count:
		if _level.is_endpoint(cell, color):
			return color
	return -1


## Backspace takes the colour under the mouse off the board. A crossed cell
## belongs to two colours, so the one it takes is the first of them -- erase
## again and the other goes too.
func _erase_under_mouse() -> void:
	var color := -1
	if _level.is_stroking():
		color = _level.stroke_color()
	else:
		var cell := _board_view.hovered_cell()
		if cell >= 0:
			var colors := _level.colors_at(cell)
			if not colors.is_empty():
				color = colors[0]
	if color < 0:
		_audio.play(PipesAudio.BLOCKED)
		return
	if _level.clear_color(color):
		_audio.play(PipesAudio.CLEAR)
		_hint_color = -1
		_refresh()


## The `[` key: shows the generator's answer for one colour at a time, stepping
## through the ones still open. The answer is the deal itself, so it is exact
## rather than a heuristic (spec 6.3).
func _cycle_hint() -> void:
	var count := _level.color_count
	var start := _hint_color + 1
	for step in count:
		var candidate := (start + step) % count
		if not _level.is_color_done(candidate):
			_hint_color = candidate
			return
	_hint_color = -1


func _check_solved() -> void:
	if not _level.is_solved():
		return
	_finished = true
	_finish_delay = 0.0
	_hint_color = -1
	_audio.play(PipesAudio.SOLVED)


# --- setup -------------------------------------------------------------------

func _deal() -> void:
	_rng.randomize()
	var side := _settings.side_for(_level_index)
	var pairs := _settings.pairs_for(_level_index)
	var dealt := PipesGenerator.generate(_rng, side, side, pairs, _settings.min_run, side * 2)
	if dealt.is_empty():
		# Rare, and never worth a failed level: ask for fewer colours.
		dealt = PipesGenerator.generate(_rng, side, side, maxi(3, pairs - 2),
				_settings.min_run, side * 2)
	_level.setup(dealt)
	_hint_color = -1
	_bridges = false
	_elapsed_ms = 0
	_finish_delay = 0.0
	_finished = false
	_last_clock_second = -1
	_draw_step = 0
	_layout()


## Dead centre, measured from the level rather than from the view. The view
## does not know its own size until refresh() hands it the board, and layout
## runs before that -- asking it there returned zero and parked the board's
## top-left corner in the middle of the window (DECISION_LOG 101).
func _layout() -> void:
	var board := Vector2(_level.cols * _settings.cell_size, _level.rows * _settings.cell_size)
	_board_view.position = (PipesSettings.FIELD - board) * 0.5


func _refresh() -> void:
	_board_view.refresh(_level, _hint_color)
	_refresh_hud()
	_refresh_overlay()


func _refresh_hud() -> void:
	_hud.refresh(_level_index, _elapsed_ms, PipesModes.name_of(PipesModes.LINK),
			"JOINED %d/%d   FILLED %d/%d" % [_level.done_count(), _level.color_count,
			_level.covered_count(), _level.cell_count()])


func _refresh_overlay() -> void:
	_hovered = _board_view.hovered_cell()
	if not _overlay.enabled:
		_overlay.set_lines(PackedStringArray())
		return
	var lines := PackedStringArray()
	lines.append("LEVEL %d  SIDE %d  COLORS %d" % [_level_index, _level.rows,
			_level.color_count])
	lines.append("JOINED %d/%d" % [_level.done_count(), _level.color_count])
	lines.append("FILLED %d/%d" % [_level.covered_count(), _level.cell_count()])
	lines.append("UNDO %d" % (1 if _level.can_undo() else 0))
	lines.append("HINT %d  BRIDGES %d" % [_hint_color, 1 if _bridges else 0])
	if _hovered >= 0:
		lines.append("CURSOR r%d c%d" % [_level.row_of(_hovered), _level.col_of(_hovered)])
		lines.append("OWNER %d  CROSS %d" % [_level.color_at(_hovered),
				1 if _level.is_crossing(_hovered) else 0])
	else:
		lines.append("CURSOR off board")
	lines.append("BEST %s" % PipesSave.format_time(
			_save.best_for(PipesModes.LINK, _level_index)))
	_overlay.set_lines(lines)


# --- pause -------------------------------------------------------------------

func _open_pause() -> void:
	get_tree().paused = true
	var menu: PipesPauseMenu = PAUSE_SCENE.instantiate()
	_pause_holder.add_child(menu)
	menu.configure(_settings)
	menu.resume_requested.connect(_close_pause)
	menu.restart_requested.connect(_restart)
	menu.menu_requested.connect(_to_menu)


func _close_pause() -> void:
	_clear_pause()
	get_tree().paused = false


func _restart() -> void:
	_clear_pause()
	get_tree().paused = false
	_deal()
	_refresh()
	_audio.play(PipesAudio.START)


func _to_menu() -> void:
	_clear_pause()
	get_tree().paused = false
	menu_requested.emit()


## Removing before freeing matters: a node queued for deletion is still alive
## for the rest of the frame (12-tetris learned this the hard way).
func _clear_pause() -> void:
	for child in _pause_holder.get_children():
		_pause_holder.remove_child(child)
		child.queue_free()
