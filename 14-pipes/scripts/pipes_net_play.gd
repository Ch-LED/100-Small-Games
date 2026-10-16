class_name PipesNetPlay
extends Control

## The three pipe modes: turn, shift a line, slide into a gap.
##
## One screen serves all three because they play on the same board and agree on
## what "joined" means. The only thing that branches is the verb -- what a
## press or a drag does to the grid -- so the branching is one `match` on press
## and one on drag, and everything else is shared (spec 6).

signal solved(elapsed_ms: int)
signal menu_requested

const PAUSE_SCENE := preload("res://14-pipes/scenes/pause_menu.tscn")
## A solved board is worth looking at before the card covers it.
const FINISH_DELAY := 0.7

@onready var _board_view: PipesNetView = $Board
@onready var _hud: PipesHud = $Hud
@onready var _overlay: PipesDebug = $Overlay
@onready var _pause_holder: Node = $PauseHolder

var _settings: PipesSettings
var _audio: PipesAudio
var _save: PipesSave
var _rng := RandomNumberGenerator.new()
var _net := PipesNet.new()
var _answer := PackedInt32Array()
var _mode := PipesModes.TURN
var _level_index := 0
var _hint_on := false
var _elapsed_ms := 0
var _finish_delay := 0.0
var _finished := false
var _last_clock_second := -1
## The piece the drag is carrying. It lags the pointer as soon as it hits
## something, so the pointer's own cell is not it.
var _held_cell := -1
var _history: Array = []


func begin(settings: PipesSettings, audio: PipesAudio, save: PipesSave,
		level_index: int, mode: int) -> void:
	_settings = settings
	_audio = audio
	_save = save
	_level_index = level_index
	_mode = mode
	_board_view.setup(settings)
	_hud.setup(settings)
	_overlay.setup(settings)
	# Guarded, because begin() may be called again on the same screen: a restart
	# rebuilds the board without rebuilding the node.
	if not _board_view.pressed.is_connected(_on_pressed):
		_board_view.pressed.connect(_on_pressed)
	if not _board_view.dragged.is_connected(_on_dragged):
		_board_view.dragged.connect(_on_dragged)
	if not _board_view.released.is_connected(_on_released):
		_board_view.released.connect(_on_released)
	_deal()
	_audio.play(PipesAudio.START)
	_refresh()


func _process(delta: float) -> void:
	if _settings == null:
		return
	if _finished:
		_finish_delay += delta
		if _finish_delay >= FINISH_DELAY:
			_finished = false
			solved.emit(_elapsed_ms)
		return
	_elapsed_ms += int(delta * 1000.0)
	var second := _elapsed_ms / 1000
	if second != _last_clock_second:
		_last_clock_second = second
		_refresh_hud()


func _unhandled_input(event: InputEvent) -> void:
	if _finished or _settings == null:
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
		_hint_on = not _hint_on
		_refresh()
		return
	if event.is_action_pressed("super_cheat_toggle"):
		_apply_answer()
		return
	if event.is_action_pressed(PipesInput.UNDO):
		if _undo():
			_audio.play(PipesAudio.CLEAR)
		_refresh()


# --- verbs -------------------------------------------------------------------

func _on_pressed(cell: int, secondary: bool) -> void:
	if _finished:
		return
	_push_history()
	match _mode:
		PipesModes.TURN:
			if _net.turn(cell, not secondary):
				_audio.play_draw(1)
				_refresh()
				_check_solved()
			else:
				_audio.play(PipesAudio.BLOCKED)
		_:
			_held_cell = cell if _net.has_piece(cell) else -1


func _on_dragged(from_cell: int, to_cell: int) -> void:
	if _finished:
		return
	match _mode:
		PipesModes.SHIFT:
			_shift_line(from_cell, to_cell)
		PipesModes.SLIDE:
			_slide_piece(from_cell, to_cell)
		_:
			pass


func _on_released() -> void:
	_held_cell = -1


## Dragging up or down walks the whole column one cell the way the hand went.
##
## Columns only, and sideways drags do nothing at all. Rows as well made this
## the hardest of the four by a distance -- every horizontal move undid work
## done three rows away -- and the mode is much better off as the gentler of
## the two sliding games (DECISION_LOG 101).
func _shift_line(from_cell: int, to_cell: int) -> void:
	if _net.row_of(from_cell) == _net.row_of(to_cell):
		return
	# A negative amount walks the contents one cell toward the high end.
	var moved := _net.shift_line(_net.col_of(from_cell), false,
			-1 if to_cell > from_cell else 1)
	if not moved:
		return
	_audio.play_draw(1)
	_refresh()
	_check_solved()


func _slide_piece(from_cell: int, to_cell: int) -> void:
	if _held_cell < 0:
		return
	var moved := _net.slide_step(_held_cell, _direction_between(from_cell, to_cell))
	if moved < 0:
		return
	_held_cell = moved
	_audio.play_draw(1)
	_refresh()
	_check_solved()


## Callers only ever hand over touching cells, so this is a four-way pick
## rather than a real direction calculation.
func _direction_between(from_cell: int, to_cell: int) -> int:
	if to_cell == from_cell - _net.cols:
		return PipesNet.NORTH
	if to_cell == from_cell + _net.cols:
		return PipesNet.SOUTH
	if to_cell == from_cell - 1:
		return PipesNet.WEST
	return PipesNet.EAST


## The one thing all three modes call progress: every opening faces another
## opening, and nothing opens onto the edge of the board.
func _check_solved() -> void:
	if _net.piece_count() == 0 or not _net.is_joined():
		return
	_finished = true
	_finish_delay = 0.0
	_hint_on = false
	_audio.play(PipesAudio.SOLVED)


## The `]` key: hand the whole board the answer. It breaks the one rule these
## three modes live by -- that progress is one turn, one row or one cell at a
## time (CONSTITUTION 八).
func _apply_answer() -> void:
	if _answer.size() != _net.cell_count():
		return
	_push_history()
	_net.pieces = _answer.duplicate()
	_hint_on = false
	_audio.play(PipesAudio.JOIN)
	_refresh()
	_check_solved()


# --- undo --------------------------------------------------------------------

func _push_history() -> void:
	_history.append(_net.pieces.duplicate())
	while _history.size() > 80:
		_history.pop_front()


func _undo() -> bool:
	if _history.is_empty():
		return false
	_net.pieces = _history.pop_back()
	_held_cell = -1
	return true


# --- setup -------------------------------------------------------------------

func _deal() -> void:
	_rng.randomize()
	var side := _settings.side_for(_level_index)
	var gaps := _settings.gaps_for(_level_index) if _mode == PipesModes.SLIDE else 0
	var steps := _settings.steps_for(_level_index)
	_net.setup(side, side)
	_answer = PipesNetGenerator.build(_rng, _net, gaps, PipesModes.shuffle_for(_mode), steps)
	if _answer.is_empty():
		# Never worth a failed level: deal a shallower wreck.
		_answer = PipesNetGenerator.build(_rng, _net, gaps, PipesModes.shuffle_for(_mode),
				maxi(4, steps / 2))
	_hint_on = false
	_elapsed_ms = 0
	_finish_delay = 0.0
	_finished = false
	_last_clock_second = -1
	_held_cell = -1
	_history = []
	_layout()


## Dead centre, measured from the grid rather than from the view. The view does
## not know its own size until refresh() hands it the board, and layout runs
## before that -- asking it there returned zero and parked the board's top-left
## corner in the middle of the window (DECISION_LOG 101).
func _layout() -> void:
	var board := Vector2(_net.cols * _settings.cell_size, _net.rows * _settings.cell_size)
	_board_view.position = (PipesSettings.FIELD - board) * 0.5


func _refresh() -> void:
	_board_view.refresh(_net, _answer, _hint_on)
	_refresh_hud()
	_refresh_overlay()


func _refresh_hud() -> void:
	var readout := "LOOSE %d   PIECES %d" % [_net.joined_count(), _net.piece_count()]
	_hud.refresh(_level_index, _elapsed_ms, PipesModes.name_of(_mode), readout)


func _refresh_overlay() -> void:
	if not _overlay.enabled:
		_overlay.set_lines(PackedStringArray())
		return
	var lines := PackedStringArray()
	lines.append("MODE %s  LEVEL %d" % [PipesModes.name_of(_mode), _level_index])
	lines.append("SIDE %d  PIECES %d  GAPS %d" % [_net.rows, _net.piece_count(),
			_net.cell_count() - _net.piece_count()])
	lines.append("LOOSE OPENINGS %d" % _net.joined_count())
	lines.append("JOINED %s" % ("yes" if _net.is_joined() else "no"))
	lines.append("UNDO %d" % _history.size())
	lines.append("HINT %d  ANSWER %d" % [1 if _hint_on else 0,
			1 if _answer.size() == _net.cell_count() else 0])
	var hover := _board_view.hovered_cell()
	if hover >= 0:
		lines.append("CURSOR r%d c%d  PIECE %d" % [_net.row_of(hover), _net.col_of(hover),
				_net.piece_at(hover)])
	else:
		lines.append("CURSOR off board")
	lines.append("BEST %s" % PipesSave.format_time(_save.best_for(_mode, _level_index)))
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


func _clear_pause() -> void:
	for child in _pause_holder.get_children():
		_pause_holder.remove_child(child)
		child.queue_free()
