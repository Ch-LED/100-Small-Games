class_name PipesNetView
extends Control

## The pipe board -- turning, shifting, sliding all share this one view.
##
## A piece is a hub with a stub toward each side it opens onto. A stub that
## faces another stub is drawn in the bright colour and a loose one in the
## plain colour, so the board says how far along it is without a counter.
##
## The view owns no rules. It reports what the mouse did -- press, drag to a
## touching cell, release -- and the play screen decides what that means, which
## is the only thing that differs between the three modes (spec 3.1).

signal pressed(cell: int, secondary: bool)
signal dragged(from_cell: int, to_cell: int)
signal released

var _settings: PipesSettings
var _net: PipesNet
var _hovered := -1
## The answer to draw for the `[` key, or empty when it is off.
var _answer := PackedInt32Array()
var _hint_on := false
var _drag_cell := -1


func setup(settings: PipesSettings) -> void:
	_settings = settings
	queue_redraw()


func hovered_cell() -> int:
	return _hovered


func board_size() -> Vector2:
	if _settings == null or _net == null:
		return Vector2.ZERO
	return Vector2(_net.cols * _settings.cell_size, _net.rows * _settings.cell_size)


func refresh(net: PipesNet, answer: PackedInt32Array, hint_on: bool) -> void:
	_net = net
	_answer = answer
	_hint_on = hint_on
	if net != null:
		custom_minimum_size = Vector2(net.cols * _settings.cell_size,
				net.rows * _settings.cell_size)
		size = custom_minimum_size
	queue_redraw()


# --- drawing -----------------------------------------------------------------

func _draw() -> void:
	if _settings == null or _net == null:
		return
	var cell := _settings.cell_size
	draw_rect(Rect2(Vector2.ZERO, board_size()), _settings.empty_color, true)
	_draw_grid(cell)
	_draw_hint(cell)
	_draw_pieces(cell)
	_draw_hover(cell)


func _draw_grid(cell: float) -> void:
	var extent := board_size()
	for col in range(1, _net.cols):
		draw_line(Vector2(col * cell, 0.0), Vector2(col * cell, extent.y),
				_settings.grid_color, 1.0)
	for row in range(1, _net.rows):
		draw_line(Vector2(0.0, row * cell), Vector2(extent.x, row * cell),
				_settings.grid_color, 1.0)


## The `[` key: the generator's own answer, drawn faintly underneath so the
## board can be read against it. Exact, not a guess -- the answer was built
## first and the board was wrecked from it (spec 6.3).
func _draw_hint(cell: float) -> void:
	if not _hint_on or _answer.size() != _net.cell_count():
		return
	var ink := _settings.hint_color
	ink.a = 0.35
	_draw_masks(_answer, cell, ink, ink)


func _draw_pieces(cell: float) -> void:
	_draw_masks(_net.pieces, cell, _settings.pipe_color, _settings.joined_pipe_color)


## Masks share one drawing pass so the hint and the board cannot drift apart in
## how they render a piece.
func _draw_masks(masks: PackedInt32Array, cell: float, plain: Color, joined: Color) -> void:
	var half := cell * 0.5
	var width := cell * _settings.pipe_width
	# Half the width, so the hub's diameter is exactly the pipe's -- a corner
	# then reads as a bend in the pipe and not as a lump sitting on it.
	var hub := width * 0.5
	for index in masks.size():
		var mask := masks[index]
		if mask == PipesNet.EMPTY:
			continue
		var centre := Vector2(_net.col_of(index) * cell + half, _net.row_of(index) * cell + half)
		for side in PipesNet.SIDES:
			if mask & side == 0:
				continue
			var ink := joined if _mouth_fits(index, side) else plain
			draw_line(centre, centre + _outward(side, half), ink, width, true)
		draw_circle(centre, hub, plain if not _all_mouths_fit(index) else joined)


func _mouth_fits(cell: int, side: int) -> bool:
	var other := _net.neighbour(cell, side)
	if other < 0:
		return false
	var other_mask := _net.piece_at(other)
	if other_mask == PipesNet.EMPTY:
		return false
	return other_mask & (PipesNet.OPPOSITE[side] as int) != 0


func _all_mouths_fit(cell: int) -> bool:
	var mask := _net.piece_at(cell)
	for side in PipesNet.SIDES:
		if mask & side != 0 and not _mouth_fits(cell, side):
			return false
	return true


static func _outward(side: int, half: float) -> Vector2:
	match side:
		PipesNet.NORTH:
			return Vector2(0.0, -half)
		PipesNet.EAST:
			return Vector2(half, 0.0)
		PipesNet.SOUTH:
			return Vector2(0.0, half)
		_:
			return Vector2(-half, 0.0)


## Very faint: it has to say which cell the pointer is on without competing
## with the pipes, which are the only thing worth looking at.
func _draw_hover(cell: float) -> void:
	if _hovered < 0 or _net == null:
		return
	var rect := Rect2(Vector2(_net.col_of(_hovered), _net.row_of(_hovered)) * cell,
			Vector2(cell, cell))
	var ink := _settings.cursor_color
	ink.a = float(_settings.hover_alpha) / 255.0
	if _net.piece_at(_hovered) == PipesNet.EMPTY:
		ink.a = minf(1.0, ink.a * 3.0)
		draw_rect(rect, ink, false, 2.0)
	else:
		draw_rect(rect, ink, true)


# --- mouse -------------------------------------------------------------------

## Handled here rather than in `_gui_input` so a drag that leaves the board
## keeps being reported -- sliding a piece toward the edge is a normal move.
func _input(event: InputEvent) -> void:
	if _net == null or _settings == null:
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var cell := _cell_at(motion.position)
		if cell != _hovered:
			_hovered = cell
			queue_redraw()
		if _drag_cell >= 0 and cell >= 0 and cell != _drag_cell and _touching(_drag_cell, cell):
			var from := _drag_cell
			_drag_cell = cell
			dragged.emit(from, cell)
		elif _drag_cell >= 0 and cell == _drag_cell:
			pass
		return
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index != MOUSE_BUTTON_LEFT and click.button_index != MOUSE_BUTTON_RIGHT:
			return
		var cell := _cell_at(click.position)
		if click.pressed:
			if cell < 0:
				return
			_drag_cell = cell
			pressed.emit(cell, click.button_index == MOUSE_BUTTON_RIGHT)
		else:
			_drag_cell = -1
			released.emit()


func _touching(first: int, second: int) -> bool:
	var row_gap := absi(_net.row_of(first) - _net.row_of(second))
	var col_gap := absi(_net.col_of(first) - _net.col_of(second))
	return row_gap + col_gap == 1


func _cell_at(screen_position: Vector2) -> int:
	# Control has no to_local -- that belongs to the 2D and 3D nodes.
	var local := get_global_transform().affine_inverse() * screen_position
	var cell := _settings.cell_size
	var col := int(floor(local.x / cell))
	var row := int(floor(local.y / cell))
	if row < 0 or row >= _net.rows or col < 0 or col >= _net.cols:
		return -1
	return _net.index_of(row, col)
