class_name BejeweledView
extends Control

## The board, drawn in one pass, plus the three animations the game needs:
## a swap, a clear, and a fall.
##
## Animation lives here rather than in the play screen because it is purely
## presentational -- it moves pixels, never data. The play screen decides what
## happened; the view decides what that looks like, and both can be reasoned
## about without the other (spec 3.1).

var _settings: BejeweledSettings
var _board: BejeweledBoard
## cell -> pixel offset, so a gem can be drawn away from its home while it
## travels. Empty except during an animation.
var _offsets: Dictionary = {}
## cell -> 0..1, for the shrink-and-fade on a clear.
var _fades: Dictionary = {}
var _selected := -1
var _cursor := -1
var _hint: Array[int] = []
var _ghost := false

signal cell_clicked(cell: int)
signal cell_hovered(cell: int)


func setup(settings: BejeweledSettings) -> void:
	_settings = settings
	queue_redraw()


func board_size() -> Vector2:
	if _settings == null or _board == null:
		return Vector2.ZERO
	return Vector2(_board.cols * _settings.cell_size, _board.rows * _settings.cell_size)


func refresh(board: BejeweledBoard, selected: int, cursor: int, hint: Array[int],
		ghost: bool) -> void:
	_board = board
	_selected = selected
	_cursor = cursor
	_hint = hint
	_ghost = ghost
	if board != null:
		custom_minimum_size = Vector2(board.cols * _settings.cell_size,
				board.rows * _settings.cell_size)
		size = custom_minimum_size
	queue_redraw()


# --- animations -------------------------------------------------------------

func animate_swap(first: int, second: int) -> void:
	var from_first := _pixel(second) - _pixel(first)
	var from_second := _pixel(first) - _pixel(second)
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		_offsets[first] = from_first * t
		_offsets[second] = from_second * t
		queue_redraw()
	, 0.0, 1.0, _settings.swap_time)
	await tween.finished
	_offsets.erase(first)
	_offsets.erase(second)
	queue_redraw()


func animate_clear(cells: Array[int]) -> void:
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		for cell in cells:
			_fades[cell] = 1.0 - t
		queue_redraw()
	, 0.0, 1.0, _settings.clear_time)
	await tween.finished
	for cell in cells:
		_fades.erase(cell)
	queue_redraw()


## `before` is the board as it was, so the cells that moved can be spotted by
## comparison rather than by the board reporting its own internals.
func animate_fall(before: PackedInt32Array, after: PackedInt32Array) -> void:
	var moved: Array[int] = []
	for cell in after.size():
		if cell < before.size() and before[cell] != after[cell]:
			moved.append(cell)
	if moved.is_empty():
		return
	var drop := Vector2(0.0, -_settings.cell_size)
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		for cell in moved:
			_offsets[cell] = drop * (1.0 - t)
		queue_redraw()
	, 0.0, 1.0, _settings.fall_time)
	await tween.finished
	for cell in moved:
		_offsets.erase(cell)
	queue_redraw()


# --- drawing ----------------------------------------------------------------

func _draw() -> void:
	if _settings == null or _board == null:
		return
	var cell := _settings.cell_size
	for index in _board.cell_count():
		var corner := Vector2(_board.col_of(index) * cell, _board.row_of(index) * cell)
		var checker := (_board.row_of(index) + _board.col_of(index)) % 2 == 0
		draw_rect(Rect2(corner, Vector2(cell, cell)),
				_settings.cell_color if checker else _settings.cell_alt_color, true)
	if _selected >= 0:
		_draw_cell_ring(_selected, cell, _settings.cursor_color, 3.0)
	if _cursor >= 0:
		_draw_cell_ring(_cursor, cell, _settings.cursor_color, 1.0)
	for pair in _hint:
		_draw_cell_ring(pair, cell, _settings.hint_color, 3.0)
	for index in _board.cell_count():
		var kind := _board.gem_at(index)
		if kind < 0:
			continue
		_draw_gem(index, kind, cell)


func _draw_cell_ring(index: int, cell: float, ink: Color, width: float) -> void:
	var corner := Vector2(_board.col_of(index) * cell, _board.row_of(index) * cell)
	draw_rect(Rect2(corner, Vector2(cell, cell)), ink, false, width)


func _draw_gem(index: int, kind: int, cell: float) -> void:
	var centre := _pixel(index) + Vector2(cell, cell) * 0.5
	var fade := float(_fades.get(index, 1.0))
	var radius := cell * (0.5 - _settings.gem_inset) * maxf(fade, 0.05)
	var ink := _settings.gem_color(kind)
	if fade < 1.0:
		ink.a = fade
	if _ghost and _selected == index:
		ink = _settings.super_color
	_draw_shape(kind, centre, radius, ink, cell)


## Six distinct outlines, so the board reads even when the colours do not --
## which is also what makes it playable without relying on colour alone.
func _draw_shape(kind: int, centre: Vector2, radius: float, ink: Color, cell: float) -> void:
	match kind % 6:
		0:
			draw_circle(centre, radius, ink)
		1:
			draw_rect(Rect2(centre - Vector2(radius, radius) * 0.85,
					Vector2(radius, radius) * 1.7), ink, true)
		2:
			draw_polygon(_polygon(centre, radius, 4, 0.0), PackedColorArray([ink]))
		3:
			draw_polygon(_polygon(centre, radius, 3, -PI / 2.0), PackedColorArray([ink]))
		4:
			draw_polygon(_polygon(centre, radius, 6, 0.0), PackedColorArray([ink]))
		_:
			var star := PackedVector2Array()
			for point in 10:
				var angle := -PI / 2.0 + TAU * float(point) / 10.0
				var reach := radius if point % 2 == 0 else radius * 0.45
				star.append(centre + Vector2(cos(angle), sin(angle)) * reach)
			draw_polygon(star, PackedColorArray([ink]))
	# A dark rim so a gem stands off the cell underneath it.
	draw_arc(centre, radius, 0.0, TAU, 24, Color(0.0, 0.0, 0.0, 0.35 * ink.a), 2.0, true)


static func _polygon(centre: Vector2, radius: float, sides: int, start: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for corner in sides:
		var angle := start + TAU * float(corner) / float(sides)
		out.append(centre + Vector2(cos(angle), sin(angle)) * radius)
	return out


func _pixel(index: int) -> Vector2:
	var home := Vector2(_board.col_of(index) * _settings.cell_size,
			_board.row_of(index) * _settings.cell_size)
	return home + (_offsets.get(index, Vector2.ZERO) as Vector2)


# --- mouse ------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if _board == null or _settings == null:
		return
	if event is InputEventMouseMotion:
		var cell := _cell_at((event as InputEventMouseMotion).position)
		if cell != _cursor:
			_cursor = cell
			cell_hovered.emit(cell)
		return
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
			return
		var cell := _cell_at(click.position)
		if cell >= 0:
			cell_clicked.emit(cell)


func _cell_at(screen_position: Vector2) -> int:
	var local := get_global_transform().affine_inverse() * screen_position
	var cell := _settings.cell_size
	var col := int(floor(local.x / cell))
	var row := int(floor(local.y / cell))
	if row < 0 or row >= _board.rows or col < 0 or col >= _board.cols:
		return -1
	return _board.index_of(row, col)
