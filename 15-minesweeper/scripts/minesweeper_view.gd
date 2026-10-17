class_name MinesweeperView
extends Control

## The board, drawn in one pass, and the mouse.
##
## A cell is a rectangle, a glyph and possibly a mark, so there is nothing for
## a node per cell to hold -- one `_draw` covers even the 16x30 board (spec 3.1).
## The view owns no rules; it reports which cell was clicked and the play screen
## tells the board about it.

signal cell_left(cell: int)
signal cell_right(cell: int)
signal cell_hovered(cell: int)

var _settings: MinesweeperSettings
var _board: MinesweeperBoard
var _hovered := -1
var _cursor := -1
## The `[` key: opening a cell will not detonate it.
var _safe_mode := false
## The `]` key: the mines a single number proves. Not the whole answer -- the
## reasoning the player was about to do anyway, and no more.
var _peek := false
var _deduced := PackedByteArray()
## Set once the game is over, so the whole board is shown.
var _finished := false


func setup(settings: MinesweeperSettings) -> void:
	_settings = settings
	queue_redraw()


func hovered_cell() -> int:
	return _hovered


func board_size() -> Vector2:
	if _settings == null or _board == null:
		return Vector2.ZERO
	return Vector2(_board.cols * _settings.cell_size, _board.rows * _settings.cell_size)


func refresh(board: MinesweeperBoard, cursor: int, safe_mode: bool, peek: bool,
		finished: bool) -> void:
	_board = board
	_cursor = cursor
	_safe_mode = safe_mode
	_peek = peek
	_finished = finished
	# Deducing is a scan of the whole board, so it happens when something asks
	# for it rather than on every redraw.
	_deduced = board.deducible_mines() if peek and board != null else PackedByteArray()
	if board != null:
		custom_minimum_size = Vector2(board.cols * _settings.cell_size,
				board.rows * _settings.cell_size)
		size = custom_minimum_size
	queue_redraw()


# --- drawing -----------------------------------------------------------------

func _draw() -> void:
	if _settings == null or _board == null:
		return
	var cell := _settings.cell_size
	for index in _board.cell_count():
		var corner := Vector2(_board.col_of(index) * cell, _board.row_of(index) * cell)
		_draw_cell(index, corner, cell)
	if _cursor >= 0:
		_draw_cursor(cell)


func _draw_cell(index: int, corner: Vector2, cell: float) -> void:
	var rect := Rect2(corner, Vector2(cell, cell))
	if _board.is_revealed(index):
		draw_rect(rect, _settings.open_color, true)
		if _board.has_mine(index):
			draw_circle(corner + Vector2(cell, cell) * 0.5, cell * 0.26, _settings.mine_color)
		else:
			_draw_number(index, corner, cell)
		return

	draw_rect(rect, _settings.hidden_color, true)
	# A lit top-left edge: the cell reads as a tile lying on the floor rather
	# than a hole in it, which is half of what makes an unopened cell obvious.
	var edge := cell * _settings.edge_scale
	draw_line(corner, corner + Vector2(cell, 0.0), _settings.hidden_edge, edge)
	draw_line(corner, corner + Vector2(0.0, cell), _settings.hidden_edge, edge)

	# Once the game is over every mine is shown; while it is running the `]`
	# key shows only the ones a single number proves.
	if _finished:
		if _board.has_mine(index):
			draw_circle(corner + Vector2(cell, cell) * 0.5, cell * 0.26, _settings.mine_color)
	elif _peek and index < _deduced.size() and _deduced[index] != 0:
		draw_circle(corner + Vector2(cell, cell) * 0.5, cell * 0.26, _settings.super_color)

	var mark := _board.flags[index]
	if mark == MinesweeperBoard.Flag.MARK:
		var ink := _settings.flag_color
		if _finished and not _board.has_mine(index):
			ink = _settings.wrong_flag_color
		_draw_flag(corner, cell, ink)
	elif mark == MinesweeperBoard.Flag.QUESTION:
		_draw_glyph("?", corner, cell, _settings.dim_text)

	if _board.exploded == index:
		draw_rect(rect, Color(_settings.flag_color, 0.55), true)
		draw_circle(corner + Vector2(cell, cell) * 0.5, cell * 0.26, _settings.mine_color)


func _draw_number(index: int, corner: Vector2, cell: float) -> void:
	var count := _board.adjacent_at(index)
	if count <= 0:
		return
	var font_size := maxi(8, int(cell * 0.62))
	var font := PixelFont.get_font()
	var text := str(count)
	var extent := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var ascent := font.get_ascent(font_size)
	var descent := font.get_descent(font_size)
	var position := corner + Vector2((cell - extent.x) * 0.5,
			(cell - (ascent + descent)) * 0.5 + ascent)
	draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
			_settings.number_color(count))


func _draw_flag(corner: Vector2, cell: float, ink: Color) -> void:
	var pole_x := corner.x + cell * 0.36
	var top := corner.y + cell * 0.24
	var bottom := corner.y + cell * 0.76
	draw_line(Vector2(pole_x, top), Vector2(pole_x, bottom), ink, maxf(1.0, cell * 0.06))
	draw_polygon(PackedVector2Array([
		Vector2(pole_x, top),
		Vector2(corner.x + cell * 0.72, top + cell * 0.14),
		Vector2(pole_x, top + cell * 0.30),
	]), PackedColorArray([ink]))


func _draw_glyph(text: String, corner: Vector2, cell: float, ink: Color) -> void:
	var font_size := maxi(8, int(cell * 0.6))
	var font := PixelFont.get_font()
	var extent := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var ascent := font.get_ascent(font_size)
	var descent := font.get_descent(font_size)
	draw_string(font, corner + Vector2((cell - extent.x) * 0.5,
			(cell - (ascent + descent)) * 0.5 + ascent), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)


func _draw_cursor(cell: float) -> void:
	var col := _board.col_of(_cursor)
	var row := _board.row_of(_cursor)
	draw_rect(Rect2(Vector2(col, row) * cell, Vector2(cell, cell)),
			_settings.cursor_color, false, 2.0)


# --- mouse -------------------------------------------------------------------

## Handled here rather than in `_gui_input` so a click that lands a pixel
## outside the grid still arrives and can be ignored deliberately.
func _input(event: InputEvent) -> void:
	if _board == null or _settings == null:
		return
	if event is InputEventMouseMotion:
		var cell := _cell_at((event as InputEventMouseMotion).position)
		if cell != _hovered:
			_hovered = cell
			cell_hovered.emit(cell)
		return
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if not click.pressed:
			return
		var cell := _cell_at(click.position)
		if cell < 0:
			return
		if click.button_index == MOUSE_BUTTON_LEFT:
			cell_left.emit(cell)
		elif click.button_index == MOUSE_BUTTON_RIGHT:
			cell_right.emit(cell)


func _cell_at(screen_position: Vector2) -> int:
	# Control has no to_local -- that belongs to the 2D and 3D nodes.
	var local := get_global_transform().affine_inverse() * screen_position
	var cell := _settings.cell_size
	var col := int(floor(local.x / cell))
	var row := int(floor(local.y / cell))
	if row < 0 or row >= _board.rows or col < 0 or col >= _board.cols:
		return -1
	return _board.index_of(row, col)
