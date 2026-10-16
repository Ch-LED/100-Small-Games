class_name SudokuView
extends Control

## The 81 cells, laid out by hand, plus the mouse.
##
## The cells are built here rather than listed in the scene: 81 of them plus
## their state would be a scene file nobody can read, and they are all the same
## node anyway (spec 3.1). The view owns nothing -- `refresh()` is handed the
## board and the cursor, and pushes both into the cells.

signal cell_clicked(index: int, pencil: bool)

var _settings: SudokuSettings
var _cells: Array[SudokuCell] = []


func setup(settings: SudokuSettings) -> void:
	_settings = settings
	var side := settings.board_side()
	custom_minimum_size = Vector2(side, side)
	size = Vector2(side, side)
	for index in SudokuBoard.CELL_COUNT:
		var cell := SudokuCell.new()
		cell.index = index
		cell.custom_minimum_size = Vector2(settings.cell_size, settings.cell_size)
		cell.size = Vector2(settings.cell_size, settings.cell_size)
		cell.position = Vector2(
				SudokuBoard.col_of(index) * settings.cell_size,
				SudokuBoard.row_of(index) * settings.cell_size)
		cell.set_palette(settings)
		add_child(cell)
		_cells.append(cell)
	queue_redraw()


## `auto_filled` is one byte per cell, non-zero where the super cheat wrote the
## digit. Empty when there is nothing to mark.
func refresh(board: SudokuBoard, cursor: int, show_hints: bool,
		auto_filled: PackedByteArray) -> void:
	if _cells.is_empty():
		return
	var conflicts := board.conflicts()
	var cursor_row := SudokuBoard.row_of(cursor)
	var cursor_col := SudokuBoard.col_of(cursor)
	var cursor_box := SudokuBoard.box_of(cursor)
	var marking := auto_filled.size() == SudokuBoard.CELL_COUNT
	for index in SudokuBoard.CELL_COUNT:
		var digit := board.value_at(index)
		var hints := 0
		if show_hints and digit == 0:
			hints = board.candidates_at(index)
		_cells[index].set_state({
			"digit": digit,
			"given": board.is_given(index),
			"conflict": conflicts[index] != 0,
			"cursor": index == cursor,
			"peer": _shares_unit(index, cursor_row, cursor_col, cursor_box),
			"super": marking and auto_filled[index] != 0,
			"notes": board.notes[index],
			"hints": hints,
		})


## True for every cell the cursor's row, column or box runs through. It is a
## reading aid -- it never says whether the contents are right.
static func _shares_unit(index: int, cursor_row: int, cursor_col: int, cursor_box: int) -> bool:
	if SudokuBoard.row_of(index) == cursor_row:
		return true
	if SudokuBoard.col_of(index) == cursor_col:
		return true
	return SudokuBoard.box_of(index) == cursor_box


func _draw() -> void:
	if _settings == null:
		return
	draw_rect(Rect2(Vector2.ZERO, Vector2(_settings.board_side(), _settings.board_side())),
			_settings.board_bg, true)


## Left click selects, right click pencils. The mouse is a shortcut for the
## keyboard, not a second way to play (spec 9).
func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	var click := event as InputEventMouseButton
	if click.button_index != MOUSE_BUTTON_LEFT and click.button_index != MOUSE_BUTTON_RIGHT:
		return
	var col := int(click.position.x / _settings.cell_size)
	var row := int(click.position.y / _settings.cell_size)
	if row < 0 or row >= SudokuBoard.SIZE or col < 0 or col >= SudokuBoard.SIZE:
		return
	accept_event()
	cell_clicked.emit(SudokuBoard.index_of(row, col), click.button_index == MOUSE_BUTTON_RIGHT)
