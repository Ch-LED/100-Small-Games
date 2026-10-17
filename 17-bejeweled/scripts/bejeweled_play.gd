class_name BejeweledPlay
extends Control

## One timed round: swap gems, score lines, keep the board alive.
##
## The round is written as a coroutine. Every step of a turn -- the swap, each
## cascade's clear, each fall -- is awaited in order, so "one thing at a time"
## falls out of the shape of the code instead of needing a state machine. A
## `_busy` flag keeps a second click from starting a second turn on top of the
## first.

signal finished(score: int)
signal menu_requested

const PAUSE_SCENE := preload("res://17-bejeweled/scenes/pause_menu.tscn")
const FINISH_DELAY := 0.9

@onready var _board_view: BejeweledView = $Board
@onready var _hud: BejeweledHud = $Hud
@onready var _overlay: BejeweledDebug = $Overlay
@onready var _pause_holder: Node = $PauseHolder

var _settings: BejeweledSettings
var _audio: BejeweledAudio
var _save: BejeweledSave
var _rng := RandomNumberGenerator.new()
var _board := BejeweledBoard.new()
var _selected := -1
var _cursor := 0
var _score := 0
var _remaining := 0.0
var _busy := false
var _over := false
var _finish_delay := 0.0
var _reported := false
var _hint: Array[int] = []
var _ghost := false


func begin(settings: BejeweledSettings, audio: BejeweledAudio, save: BejeweledSave) -> void:
	_settings = settings
	_audio = audio
	_save = save
	_board_view.setup(settings)
	_hud.setup(settings)
	_overlay.setup(settings)
	if not _board_view.cell_clicked.is_connected(_on_cell_clicked):
		_board_view.cell_clicked.connect(_on_cell_clicked)
	if not _board_view.cell_hovered.is_connected(_on_cell_hovered):
		_board_view.cell_hovered.connect(_on_cell_hovered)
	_deal()
	_audio.play(BejeweledAudio.START)
	_refresh()


func _process(delta: float) -> void:
	if _settings == null:
		return
	if _over:
		if _reported:
			return
		_finish_delay += delta
		if _finish_delay >= FINISH_DELAY:
			_reported = true
			finished.emit(_score)
		return
	_remaining -= delta
	if _remaining <= 0.0:
		_remaining = 0.0
		_over = true
		_audio.play(BejeweledAudio.OVER)
	_refresh_hud()


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
	if _over:
		return
	if event.is_action_pressed("cheat_toggle"):
		_hint = _board.find_move()
		_refresh()
		_audio.play(BejeweledAudio.CASCADE)
		return
	if event.is_action_pressed("super_cheat_toggle"):
		_ghost = not _ghost
		_refresh()
		return
	if event.is_action_pressed(BejeweledInput.LEFT):
		_move_cursor(0, -1)
	elif event.is_action_pressed(BejeweledInput.RIGHT):
		_move_cursor(0, 1)
	elif event.is_action_pressed(BejeweledInput.UP):
		_move_cursor(-1, 0)
	elif event.is_action_pressed(BejeweledInput.DOWN):
		_move_cursor(1, 0)
	elif event.is_action_pressed(BejeweledInput.SELECT):
		_on_cell_clicked(_cursor)


# --- the turn ----------------------------------------------------------------

func _on_cell_clicked(cell: int) -> void:
	if _busy or _over or cell < 0:
		return
	_cursor = cell
	if _selected < 0:
		_selected = cell
		_refresh()
		return
	if cell == _selected:
		_selected = -1
		_refresh()
		return
	# Adjacency is the rule; the `]` cheat is the one case where it is lifted.
	if not _ghost and not _board.are_adjacent(_selected, cell):
		_selected = cell
		_refresh()
		return
	var first := _selected
	_selected = -1
	_hint.clear()
	_take_turn(first, cell)


func _take_turn(first: int, second: int) -> void:
	_busy = true
	_board.swap(first, second)
	_refresh()
	await _board_view.animate_swap(first, second)
	if _board.matched_cells().is_empty():
		if _ghost:
			# Under the `]` cheat a swap does not have to score: the player is
			# rearranging the board, and a move that happens to make nothing is
			# still a move they meant to make (DECISION_LOG 109).
			_busy = false
			return
		# Nothing came of it: put them back, and make the refusal audible so
		# the player knows the swap was seen and turned down, not missed.
		_board.swap(first, second)
		_audio.play(BejeweledAudio.REJECT)
		_refresh()
		await _board_view.animate_swap(first, second)
		_busy = false
		return
	_audio.play(BejeweledAudio.SWAP)
	await _resolve_cascades()
	_busy = false


func _resolve_cascades() -> void:
	var cascade := 0
	while not _over:
		var matched := _board.matched_cells()
		if matched.is_empty():
			break
		cascade += 1
		# Charges earned this pass are decided before anything is cleared, so
		# they are planted where the run was, not where the board fell to.
		var rewards := _board.pending_rewards()
		# A charge caught in this clear goes off too, and the set grows with it.
		var clearing := _board.expand_specials(matched)
		_score += clearing.size() * _settings.per_gem * cascade
		_audio.play_clear(cascade)
		await _board_view.animate_clear(clearing)
		_board.clear(clearing)
		for reward in rewards:
			_board.set_gem(int(reward["cell"]), int(reward["kind"]))
			_board.set_special(int(reward["cell"]), int(reward["special"]))
			_audio.play(BejeweledAudio.CASCADE)
		_board.apply_gravity(_rng)
		_refresh()
		await _board_view.animate_fall(_board.last_moves, _board.last_spawns)
	# A board with no move is a dead end; deal a fresh one rather than leave
	# the player staring at it.
	if not _board.has_move():
		_board.deal(_rng)
		_refresh()


# --- setup -------------------------------------------------------------------

func _deal() -> void:
	_rng.randomize()
	_board.setup(_settings.rows, _settings.cols, _settings.kinds)
	_board.deal(_rng)
	_selected = -1
	_cursor = _board.index_of(_board.rows / 2, _board.cols / 2)
	_score = 0
	_remaining = float(_settings.round_seconds)
	_busy = false
	_over = false
	_finish_delay = 0.0
	_reported = false
	_hint.clear()
	_ghost = false
	_layout()


## Dead centre, measured from the board rather than from the view
## (DECISION_LOG 101).
func _layout() -> void:
	var board := Vector2(_board.cols * _settings.cell_size, _board.rows * _settings.cell_size)
	_board_view.position = (BejeweledSettings.FIELD - board) * 0.5


func _move_cursor(row_step: int, col_step: int) -> void:
	var row := clampi(_board.row_of(_cursor) + row_step, 0, _board.rows - 1)
	var col := clampi(_board.col_of(_cursor) + col_step, 0, _board.cols - 1)
	_cursor = _board.index_of(row, col)
	_refresh()


func _on_cell_hovered(cell: int) -> void:
	if cell >= 0:
		_cursor = cell
		_refresh_board()


func _refresh() -> void:
	_refresh_board()
	_refresh_hud()
	_refresh_overlay()


func _refresh_board() -> void:
	_board_view.refresh(_board, _selected, _cursor, _hint, _ghost)


func _refresh_hud() -> void:
	_hud.refresh(_score, _remaining, _save.best_score)


func _refresh_overlay() -> void:
	if not _overlay.enabled:
		_overlay.set_lines(PackedStringArray())
		return
	var lines := PackedStringArray()
	lines.append("SCORE %d  TIME %.1f" % [_score, _remaining])
	lines.append("SEL %d  CURSOR r%d c%d" % [_selected, _board.row_of(_cursor),
			_board.col_of(_cursor)])
	lines.append("MATCHED %d" % _board.matched_cells().size())
	lines.append("HAS MOVE %d" % (1 if _board.has_move() else 0))
	lines.append("HINT %d  GHOST %d" % [_hint.size(), 1 if _ghost else 0])
	lines.append("KINDS %d  GRID %dx%d" % [_settings.kinds, _board.rows, _board.cols])
	lines.append("BEST %d" % _save.best_score)
	_overlay.set_lines(lines)


# --- pause -------------------------------------------------------------------

func _open_pause() -> void:
	if _over:
		return
	get_tree().paused = true
	var menu: BejeweledPauseMenu = PAUSE_SCENE.instantiate()
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
	_audio.play(BejeweledAudio.START)


func _to_menu() -> void:
	_clear_pause()
	get_tree().paused = false
	menu_requested.emit()


func _clear_pause() -> void:
	for child in _pause_holder.get_children():
		_pause_holder.remove_child(child)
		child.queue_free()
