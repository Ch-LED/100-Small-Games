class_name MinesweeperPlay
extends Control

## A single board, from the first click to the last safe cell.
##
## Mines are placed on that first click, not before it -- see `MinesweeperBoard.seed`.
## The play screen is what decides that the first click is the seeding click,
## and it is also what starts the clock, which is why neither of those lives in
## the board (spec 5).

signal finished(won: bool, elapsed_ms: int)
signal menu_requested

const PAUSE_SCENE := preload("res://15-minesweeper/scenes/pause_menu.tscn")
## A finished board is worth a look before the card covers it.
const FINISH_DELAY := 0.8

@onready var _board_view: MinesweeperView = $Board
@onready var _hud: MinesweeperHud = $Hud
@onready var _overlay: MinesweeperDebug = $Overlay
@onready var _pause_holder: Node = $PauseHolder

var _settings: MinesweeperSettings
var _audio: MinesweeperAudio
var _save: MinesweeperSave
var _rng := RandomNumberGenerator.new()
var _board := MinesweeperBoard.new()
var _level := 0
var _cursor := 0
var _safe_mode := false
var _peek := false
var _elapsed_ms := 0
var _timing := false
var _over := false
var _won := false
var _finish_delay := 0.0
var _last_clock_second := -1
var _reported := false


func begin(settings: MinesweeperSettings, audio: MinesweeperAudio, save: MinesweeperSave,
		level: int) -> void:
	_settings = settings
	_audio = audio
	_save = save
	_level = level
	_board_view.setup(settings)
	_hud.setup(settings)
	_overlay.setup(settings)
	if not _board_view.cell_left.is_connected(_on_cell_left):
		_board_view.cell_left.connect(_on_cell_left)
	if not _board_view.cell_right.is_connected(_on_cell_right):
		_board_view.cell_right.connect(_on_cell_right)
	if not _board_view.cell_hovered.is_connected(_on_cell_hovered):
		_board_view.cell_hovered.connect(_on_cell_hovered)
	_deal()
	_audio.play(MinesweeperAudio.START)
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
			finished.emit(_won, _elapsed_ms)
		return
	if not _timing:
		return
	_elapsed_ms += int(delta * 1000.0)
	var second := _elapsed_ms / 1000
	if second != _last_clock_second:
		_last_clock_second = second
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
		_safe_mode = not _safe_mode
		_refresh()
		return
	if event.is_action_pressed("super_cheat_toggle"):
		_peek = not _peek
		_refresh()
		return
	if event.is_action_pressed(MinesweeperInput.LEFT):
		_move_cursor(0, -1)
	elif event.is_action_pressed(MinesweeperInput.RIGHT):
		_move_cursor(0, 1)
	elif event.is_action_pressed(MinesweeperInput.UP):
		_move_cursor(-1, 0)
	elif event.is_action_pressed(MinesweeperInput.DOWN):
		_move_cursor(1, 0)
	elif event.is_action_pressed(MinesweeperInput.OPEN):
		_on_cell_left(_cursor)
	elif event.is_action_pressed(MinesweeperInput.FLAG):
		_on_cell_right(_cursor)


# --- moves -------------------------------------------------------------------

func _on_cell_left(cell: int) -> void:
	if _over or cell < 0:
		return
	_cursor = cell
	if not _board.seeded:
		# The first click both places the mines and starts the clock.
		if not _board.seed(_rng, cell):
			return
		_timing = true
		_last_clock_second = -1
	if _board.is_revealed(cell):
		# The chord: an open number whose flags already match opens the rest.
		var chained := _board.chord(cell)
		if chained > 0:
			_audio.play(MinesweeperAudio.OPEN)
			_after_move()
		return
	var opened := _board.reveal(cell)
	if opened == -1:
		if _safe_mode:
			# The `[` cheat: the mine opens like any other cell and the run
			# carries on. It is shown as a mine, so it still teaches.
			_board.exploded = -1
			_board.revealed[cell] = 1
			_audio.play(MinesweeperAudio.OPEN)
			_after_move()
			return
		_over = true
		_won = false
		_audio.play(MinesweeperAudio.BOOM)
		_refresh()
		return
	if opened > 0:
		_audio.play(MinesweeperAudio.OPEN)
		_after_move()


func _on_cell_right(cell: int) -> void:
	if _over or cell < 0:
		return
	_cursor = cell
	if not _board.toggle_flag(cell):
		return
	var flagged := _board.flags[cell] == MinesweeperBoard.Flag.MARK
	_audio.play(MinesweeperAudio.FLAG if flagged else MinesweeperAudio.UNFLAG)
	_refresh()


func _after_move() -> void:
	_refresh()
	if _board.is_won():
		_over = true
		_won = true
		_audio.play(MinesweeperAudio.WIN)


func _on_cell_hovered(cell: int) -> void:
	if cell >= 0:
		_cursor = cell
		_refresh_board_redraw()


func _move_cursor(row_step: int, col_step: int) -> void:
	var row := clampi(_board.row_of(_cursor) + row_step, 0, _board.rows - 1)
	var col := clampi(_board.col_of(_cursor) + col_step, 0, _board.cols - 1)
	_cursor = _board.index_of(row, col)
	_refresh_board_redraw()


# --- setup -------------------------------------------------------------------

func _deal() -> void:
	_rng.randomize()
	_board.setup(_settings.rows_for(_level), _settings.cols_for(_level),
			_settings.mines_for(_level))
	_cursor = _board.index_of(_board.rows / 2, _board.cols / 2)
	_safe_mode = false
	_peek = false
	_elapsed_ms = 0
	_timing = false
	_over = false
	_won = false
	_finish_delay = 0.0
	_last_clock_second = -1
	_reported = false
	_layout()


## Dead centre, measured from the board rather than from the view: the view
## does not know its own size until refresh() hands it the board, and layout
## runs before that (DECISION_LOG 101).
func _layout() -> void:
	var board := Vector2(_board.cols * _settings.cell_size, _board.rows * _settings.cell_size)
	_board_view.position = (MinesweeperSettings.FIELD - board) * 0.5


func _refresh_board_redraw() -> void:
	_board_view.refresh(_board, _cursor, _safe_mode, _peek, _over)


func _refresh() -> void:
	_refresh_board_redraw()
	_refresh_hud()
	_refresh_overlay()


func _refresh_hud() -> void:
	_hud.refresh(_level, _board.mine_count - _board.flag_count(), _elapsed_ms)


func _refresh_overlay() -> void:
	if not _overlay.enabled:
		_overlay.set_lines(PackedStringArray())
		return
	var lines := PackedStringArray()
	lines.append("LEVEL %d %s  %dx%d" % [_level, _settings.level_name(_level),
			_board.rows, _board.cols])
	lines.append("MINES %d  FLAGS %d" % [_board.mine_count, _board.flag_count()])
	lines.append("OPEN %d/%d" % [_board.revealed_count(),
			_board.cell_count() - _board.mine_count])
	lines.append("SEEDED %d  OVER %d  WON %d" % [1 if _board.seeded else 0,
			1 if _over else 0, 1 if _won else 0])
	lines.append("SAFE %d  PEEK %d" % [1 if _safe_mode else 0, 1 if _peek else 0])
	lines.append("CURSOR r%d c%d" % [_board.row_of(_cursor), _board.col_of(_cursor)])
	if _board.seeded:
		lines.append("HERE mine %d adjacent %d" % [
				1 if _board.mine_at(_cursor) else 0, _board.adjacent_at(_cursor)])
	else:
		lines.append("HERE not seeded")
	lines.append("BEST %s" % MinesweeperSave.format_time(_save.best_for(_level)))
	_overlay.set_lines(lines)


# --- pause -------------------------------------------------------------------

func _open_pause() -> void:
	get_tree().paused = true
	var menu: MinesweeperPauseMenu = PAUSE_SCENE.instantiate()
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
	_audio.play(MinesweeperAudio.START)


func _to_menu() -> void:
	_clear_pause()
	get_tree().paused = false
	menu_requested.emit()


func _clear_pause() -> void:
	for child in _pause_holder.get_children():
		_pause_holder.remove_child(child)
		child.queue_free()
