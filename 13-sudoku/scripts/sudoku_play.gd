class_name SudokuPlay
extends Control

## A single puzzle, from deal to solve.
##
## Everything a run needs lives here: the board, the cursor, the three
## switches, the clock. The root only hears `solved` and decides what a record
## is worth -- the same split as 11-pinball and 12-tetris (spec 5).

signal solved(elapsed_ms: int, mistakes: int)
signal menu_requested

const PAUSE_SCENE := preload("res://13-sudoku/scenes/pause_menu.tscn")

@onready var _board_view: SudokuView = $Board
@onready var _hud: SudokuHud = $Hud
@onready var _overlay: SudokuDebug = $Overlay
@onready var _pause_holder: Node = $PauseHolder

var _settings: SudokuSettings
var _audio: SudokuAudio
var _save: SudokuSave
var _rng := RandomNumberGenerator.new()
var _board := SudokuBoard.new()
var _solution := PackedByteArray()
var _auto_filled := PackedByteArray()
var _cursor := 0
var _difficulty := 0
var _pencil := false
var _hints := false
var _auto_solve := false
var _mistakes := 0
var _elapsed_ms := 0
var _dealt_blanks := 0
var _finished := false
var _last_clock_second := -1


func begin(settings: SudokuSettings, audio: SudokuAudio, save: SudokuSave,
		difficulty: int) -> void:
	_settings = settings
	_audio = audio
	_save = save
	_difficulty = difficulty
	_board_view.setup(settings)
	_hud.setup(settings)
	_overlay.setup(settings)
	_board_view.cell_clicked.connect(_on_cell_clicked)
	_layout()
	_deal()
	_audio.play(SudokuAudio.START)
	_refresh()


func _process(delta: float) -> void:
	if _finished:
		return
	_elapsed_ms += int(delta * 1000.0)
	# The clock only needs redrawing when its visible digits change; the rest of
	# the board is redrawn on input only.
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
		_hints = not _hints
		_refresh()
		return
	if event.is_action_pressed("super_cheat_toggle"):
		_auto_solve = not _auto_solve
		if _auto_solve:
			_fill_cursor_from_solution()
		_refresh()
		return
	if event.is_action_pressed(SudokuInput.PENCIL):
		_pencil = not _pencil
		_refresh_hud()
		return
	if event.is_action_pressed(SudokuInput.ERASE):
		_erase()
		return
	for digit in range(1, SudokuBoard.SIZE + 1):
		if event.is_action_pressed(SudokuInput.digit_action(digit)):
			_enter(digit)
			return
	if event.is_action_pressed(SudokuInput.UP):
		_move(-1, 0)
	elif event.is_action_pressed(SudokuInput.DOWN):
		_move(1, 0)
	elif event.is_action_pressed(SudokuInput.LEFT):
		_move(0, -1)
	elif event.is_action_pressed(SudokuInput.RIGHT):
		_move(0, 1)


## Places a digit, or pencils it when the pencil switch is on. A dealt digit is
## not the player's to overwrite, and the refusal is audible rather than silent.
func _enter(digit: int) -> void:
	if _board.is_given(_cursor):
		_audio.play(SudokuAudio.CLASH)
		return
	if _pencil:
		if _board.toggle_note(_cursor, digit):
			_audio.play(SudokuAudio.NOTE)
			_refresh_board()
		return
	if not _board.place(_cursor, digit):
		return
	_auto_filled[_cursor] = 0
	# The board only ever blames a digit that repeats in its row, column or box
	# -- it never consults the solution, so a wrong digit that happens to fit is
	# not called out (spec 5.3).
	if _board.conflicts()[_cursor] != 0:
		_mistakes += 1
		_audio.play(SudokuAudio.CLASH)
	else:
		_audio.play_fill(digit)
	_refresh()
	_check_solved()


func _erase() -> void:
	if not _board.erase(_cursor):
		return
	_auto_filled[_cursor] = 0
	_audio.play(SudokuAudio.ERASE)
	_refresh()


func _move(row_step: int, col_step: int) -> void:
	var row := clampi(SudokuBoard.row_of(_cursor) + row_step, 0, SudokuBoard.SIZE - 1)
	var col := clampi(SudokuBoard.col_of(_cursor) + col_step, 0, SudokuBoard.SIZE - 1)
	_set_cursor(SudokuBoard.index_of(row, col))


func _set_cursor(index: int) -> void:
	_cursor = index
	if _auto_solve:
		_fill_cursor_from_solution()
	_refresh()


## The super cheat: whatever cell the cursor lands on, the answer is written
## into it. The constraint it breaks is "you have to work it out" -- the board
## still has to be filled and it still has to be consistent, but the thinking
## is gone (CONSTITUTION 八).
func _fill_cursor_from_solution() -> void:
	if _board.is_given(_cursor):
		return
	_board.place(_cursor, _solution[_cursor])
	_auto_filled[_cursor] = 1


func _check_solved() -> void:
	if not _board.is_complete():
		return
	_finished = true
	_audio.play(SudokuAudio.COMPLETE)
	solved.emit(_elapsed_ms, _mistakes)


func _deal() -> void:
	_rng.randomize()
	var dealt := SudokuGenerator.generate(_rng, _settings.blanks_for(_difficulty))
	_board.load_puzzle(dealt["puzzle"])
	_solution = dealt["solution"]
	_dealt_blanks = int(dealt["blanks"])
	_auto_filled = PackedByteArray()
	_auto_filled.resize(SudokuBoard.CELL_COUNT)
	_auto_filled.fill(0)
	_cursor = _first_blank()
	_mistakes = 0
	_elapsed_ms = 0
	_last_clock_second = -1
	_finished = false


func _first_blank() -> int:
	for index in SudokuBoard.CELL_COUNT:
		if _board.is_blank(index):
			return index
	return 0


func _layout() -> void:
	var side := _settings.board_side()
	_board_view.position = Vector2(
			(SudokuSettings.FIELD.x - side) * 0.5,
			(SudokuSettings.FIELD.y - side) * 0.5 + 20.0)


func _on_cell_clicked(index: int, pencil: bool) -> void:
	_set_cursor(index)
	if pencil:
		_pencil = not _pencil
		_refresh_hud()


func _refresh() -> void:
	_refresh_board()
	_refresh_hud()
	_refresh_overlay()


func _refresh_board() -> void:
	_board_view.refresh(_board, _cursor, _hints, _auto_filled)


func _refresh_hud() -> void:
	_hud.refresh(_settings.difficulty_name(_difficulty), _elapsed_ms,
			_board.blank_count(), _pencil, _hints, _auto_solve)


func _refresh_overlay() -> void:
	if not _overlay.enabled:
		_overlay.set_lines(PackedStringArray())
		return
	var wrong := 0
	for index in SudokuBoard.CELL_COUNT:
		if not _board.is_given(index) and not _board.is_blank(index):
			if _board.value_at(index) != _solution[index]:
				wrong += 1
	var cursor_candidates := 0
	if _board.is_blank(_cursor):
		cursor_candidates = _board.candidate_count(_cursor)
	var lines := PackedStringArray()
	lines.append("BEST  %s" % SudokuSave.format_time(_save.best_for(_difficulty)))
	lines.append("DIFF  %d" % _difficulty)
	lines.append("TARGET %d  DEALT %d" % [_settings.blanks_for(_difficulty), _dealt_blanks])
	lines.append("GIVEN %d  BLANK %d" % [SudokuBoard.CELL_COUNT - _dealt_blanks,
			_board.blank_count()])
	lines.append("CONFLICT %d  WRONG %d" % [_board.conflict_count(), wrong])
	lines.append("CURSOR r%d c%d" % [SudokuBoard.row_of(_cursor), SudokuBoard.col_of(_cursor)])
	lines.append("CAND %d  MISTAKES %d" % [cursor_candidates, _mistakes])
	_overlay.set_lines(lines)


func _open_pause() -> void:
	get_tree().paused = true
	var menu: SudokuPauseMenu = PAUSE_SCENE.instantiate()
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
	_audio.play(SudokuAudio.START)


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
