class_name PipesBoardView
extends Control

## The grid, drawn in one pass, and the mouse.
##
## Unlike 13-sudoku this board needs no node per cell: a cell here is a
## rectangle, a few line segments and possibly a dot, all of which one `_draw`
## produces in a single pass. The view owns no rules -- it reports which cell
## the mouse is on and the play screen tells the level about it (spec 3.1).

signal cell_pressed(cell: int)
signal cell_dragged(cell: int)
signal cell_released

var _settings: PipesSettings
var _level: PipesLevel
var _hovered := -1
## The colour the `[` key is showing the answer for, or -1.
var _hint_color := -1
var _last_dragged := -1


func setup(settings: PipesSettings) -> void:
	_settings = settings
	queue_redraw()


## Which cell the mouse was last over, or -1. The play screen needs it for the
## key that acts on "whatever is under the pointer".
func hovered_cell() -> int:
	return _hovered


func board_size() -> Vector2:
	if _settings == null or _level == null:
		return Vector2.ZERO
	return Vector2(_level.cols * _settings.cell_size, _level.rows * _settings.cell_size)


## `hovered` is the view's own business -- it is whatever cell the mouse was
## last over, and the play screen has no reason to know it.
func refresh(level: PipesLevel, hint_color: int) -> void:
	_level = level
	_hint_color = hint_color
	if level != null:
		custom_minimum_size = Vector2(level.cols * _settings.cell_size,
				level.rows * _settings.cell_size)
		size = custom_minimum_size
	queue_redraw()


# --- drawing -----------------------------------------------------------------

func _draw() -> void:
	if _settings == null or _level == null:
		return
	var cell := _settings.cell_size
	draw_rect(Rect2(Vector2.ZERO, board_size()), _settings.empty_color, true)
	_draw_grid(cell)
	_draw_lines(cell)
	_draw_hint(cell)
	_draw_ends(cell)
	_draw_hover(cell)


func _draw_grid(cell: float) -> void:
	var extent := board_size()
	for col in range(1, _level.cols):
		var x := col * cell
		draw_line(Vector2(x, 0.0), Vector2(x, extent.y), _settings.grid_color, 1.0)
	for row in range(1, _level.rows):
		var y := row * cell
		draw_line(Vector2(0.0, y), Vector2(extent.x, y), _settings.grid_color, 1.0)


## Every drawn colour as a chain of segments. Walking the chain rather than
## asking each cell who its neighbours are keeps a crossing honest: a line that
## has been laid over another still draws only its own turns.
func _draw_lines(cell: float) -> void:
	var width := cell * _settings.line_width
	var half := cell * 0.5
	for color in _level.color_count:
		var path: Array = _level.drawn[color]
		if path.size() < 2:
			continue
		var ink := _settings.color_for(color)
		for step in range(1, path.size()):
			draw_line(_centre(path[step - 1], cell, half), _centre(path[step], cell, half),
					ink, width, true)
		# A disc at every cell centre, the line's own colour and its own width,
		# so a corner is a bend rather than a notch. The two end cells get one
		# as well, which is what rounds the ends off.
		for step in path.size():
			draw_circle(_centre(path[step], cell, half), width * 0.5, ink)


## Where two lines lie over each other, a small tile of the bridge colour sits
## on top so the crossing reads as a crossing and not as a bad colour.
func _draw_crossings(cell: float) -> void:
	var half := cell * 0.5
	var extent := cell * 0.30
	for index in _level.cell_count():
		if not _level.is_crossing(index):
			continue
		var centre := _centre(index, cell, half)
		draw_rect(Rect2(centre - Vector2(extent, extent) * 0.5, Vector2(extent, extent)),
				_settings.bridge_color, true)


func _draw_ends(cell: float) -> void:
	var half := cell * 0.5
	for color in _level.color_count:
		var ink := _settings.color_for(color)
		var joined := _level.is_color_done(color)
		var radius := cell * (0.5 * (_settings.joined_dot_scale if joined
				else _settings.dot_scale))
		for cell_index in _level.ends[color]:
			var centre := _centre(cell_index, cell, half)
			draw_circle(centre, radius, ink)
			if joined:
				# Hollow once the line has arrived: present, and clearly spent.
				draw_circle(centre, radius * 0.55, _settings.empty_color)
	_draw_crossings(cell)


func _draw_hint(cell: float) -> void:
	if _hint_color < 0 or _hint_color >= _level.color_count:
		return
	var half := cell * 0.5
	var chain := _level.solution[_hint_color]
	var ink := _settings.hint_color
	ink.a = 0.75
	for step in range(1, chain.size()):
		draw_line(_centre(chain[step - 1], cell, half), _centre(chain[step], cell, half),
				ink, cell * _settings.line_width * 0.8, true)
	for cell_index in _level.ends[_hint_color]:
		draw_arc(_centre(cell_index, cell, half), cell * 0.55, 0.0, TAU, 24, ink, 2.0, true)


func _draw_hover(cell: float) -> void:
	if _hovered < 0:
		return
	var col := _level.col_of(_hovered)
	var row := _level.row_of(_hovered)
	draw_rect(Rect2(Vector2(col, row) * cell, Vector2(cell, cell)),
			_settings.cursor_color, false, 3.0)


func _centre(index: int, cell: float, half: float) -> Vector2:
	return Vector2(_level.col_of(index) * cell + half, _level.row_of(index) * cell + half)


# --- mouse -------------------------------------------------------------------

## Handled here rather than in `_gui_input` because a drag spends most of its
## time outside the board: it has to keep being reported, and letting go off the
## edge still has to end the stroke.
func _input(event: InputEvent) -> void:
	if _level == null or _settings == null:
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var cell := _cell_at(motion.position)
		if cell != _hovered:
			_hovered = cell
			queue_redraw()
		if cell >= 0 and cell != _last_dragged and motion.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_last_dragged = cell
			cell_dragged.emit(cell)
		return
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index != MOUSE_BUTTON_LEFT:
			return
		var cell := _cell_at(click.position)
		if click.pressed:
			if cell < 0:
				return
			_last_dragged = cell
			cell_pressed.emit(cell)
		else:
			_last_dragged = -1
			cell_released.emit()


func _cell_at(screen_position: Vector2) -> int:
	# Control has no to_local -- that belongs to the 2D and 3D nodes. The global
	# transform's inverse is the same thing.
	var local := get_global_transform().affine_inverse() * screen_position
	var cell := _settings.cell_size
	var col := int(floor(local.x / cell))
	var row := int(floor(local.y / cell))
	if row < 0 or row >= _level.rows or col < 0 or col >= _level.cols:
		return -1
	return row * _level.cols + col
