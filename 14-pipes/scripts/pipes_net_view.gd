class_name PipesNetView
extends Control

## The pipe board -- turning, shifting, sliding all share this one view.
##
## A piece is a hub with a stub toward each side it opens onto. A piece whose
## every opening faces something is drawn bright; one with a loose opening
## stays in its own colour, so a lit pipe always means a joined one. On boards
## with several colours the piece is drawn in its cell's colour, and the loose
## ones are simply not brightened -- colour survives, progress is still read at
## a glance (spec 4.3).
##
## The view owns no rules. It reports what the mouse did -- press, drag to a
## touching cell, release -- and the play screen decides what that means.

signal pressed(cell: int, secondary: bool)
signal dragged(from_cell: int, to_cell: int)
signal released

var _settings: PipesSettings
var _net: PipesNet
var _hovered := -1
var _answer := PackedInt32Array()
var _hint_on := false
var _drag_cell := -1
## The column the keyboard is working on, or -1 in the modes that have none.
var _selected_col := -1

## Water arrives at a piece a little after it arrives at the piece feeding it,
## so a run that has just come together lights up from the source outward. It
## is a reading aid and nothing more: it changes no cell, and the solve is
## decided before any of it plays (DECISION_LOG 103).
const FLOW_STEP := 0.045
const FLOW_FADE := 0.35
var _flow_delay := PackedFloat32Array()
var _flow_clock := 0.0
var _flowing := false


func setup(settings: PipesSettings) -> void:
	_settings = settings
	queue_redraw()


func hovered_cell() -> int:
	return _hovered


func board_size() -> Vector2:
	if _settings == null or _net == null:
		return Vector2.ZERO
	return Vector2(_net.cols * _settings.cell_size, _net.rows * _settings.cell_size)


func refresh(net: PipesNet, answer: PackedInt32Array, hint_on: bool,
		selected_col: int = -1) -> void:
	_net = net
	_answer = answer
	_hint_on = hint_on
	_selected_col = selected_col
	if net != null:
		custom_minimum_size = Vector2(net.cols * _settings.cell_size,
				net.rows * _settings.cell_size)
		size = custom_minimum_size
	queue_redraw()


# --- water -------------------------------------------------------------------

## Walks the joined pipe outward from every source and notes when the water
## reaches each cell. Called when a move joins something new, so the light
## sweeps along the run the player just completed.
func start_flow(net: PipesNet) -> void:
	if net == null:
		return
	var total := net.cell_count()
	_flow_delay = PackedFloat32Array()
	_flow_delay.resize(total)
	_flow_delay.fill(-1.0)
	var queue: Array[int] = []
	for cell in total:
		if net.sources[cell] != 0:
			_flow_delay[cell] = 0.0
			queue.append(cell)
	while not queue.is_empty():
		var cell: int = queue.pop_front()
		for side in PipesNet.SIDES:
			if not net.mouth_fits(cell, side):
				continue
			var other := net.neighbour(cell, side)
			if other < 0 or _flow_delay[other] >= 0.0:
				continue
			_flow_delay[other] = _flow_delay[cell] + FLOW_STEP
			queue.append(other)
	_flow_clock = 0.0
	_flowing = true
	set_process(true)


func _process(delta: float) -> void:
	if not _flowing:
		return
	_flow_clock += delta
	queue_redraw()
	var latest := 0.0
	for delay in _flow_delay:
		latest = maxf(latest, delay)
	if _flow_clock > latest + FLOW_FADE + 0.1:
		_flowing = false
		set_process(false)


## How bright the water is at this cell right now: zero before it arrives,
## peaking as it passes, gone once it has moved on.
func _flow_amount(cell: int) -> float:
	if not _flowing or cell >= _flow_delay.size():
		return 0.0
	var start := _flow_delay[cell]
	if start < 0.0:
		return 0.0
	var age := _flow_clock - start
	if age < 0.0 or age > FLOW_FADE:
		return 0.0
	return 1.0 - age / FLOW_FADE


# --- drawing -----------------------------------------------------------------

func _draw() -> void:
	if _settings == null or _net == null:
		return
	var cell := _settings.cell_size
	draw_rect(Rect2(Vector2.ZERO, board_size()), _settings.empty_color, true)
	_draw_column_wash(cell)
	_draw_grid(cell)
	_draw_column_arrows(cell)
	_draw_hint(cell)
	_draw_pieces(cell)
	_draw_hover(cell)


## The selected column is washed in colour rather than outlined. An outline was
## tried first and vanished among the pipes (DECISION_LOG 102).
func _draw_column_wash(cell: float) -> void:
	if _selected_col < 0 or _selected_col >= _net.cols:
		return
	var ink := _settings.col_highlight_color
	ink.a = _settings.col_highlight_alpha
	draw_rect(Rect2(Vector2(_selected_col * cell, 0.0),
			Vector2(cell, _net.rows * cell)), ink, true)


## One pair of triangles per column, above and below the board: the only thing
## on screen that says a column can be rolled. The selected column's pair takes
## the highlight colour so the keyboard has something to aim at.
func _draw_column_arrows(cell: float) -> void:
	if _selected_col < 0:
		return
	var bottom := _net.rows * cell
	for col in _net.cols:
		var ink := _settings.arrow_color
		if col == _selected_col:
			ink = _settings.col_highlight_color
		var centre_x := col * cell + cell * 0.5
		draw_polygon(PackedVector2Array([
			Vector2(centre_x, -cell * 0.30),
			Vector2(centre_x - cell * 0.17, -cell * 0.06),
			Vector2(centre_x + cell * 0.17, -cell * 0.06),
		]), PackedColorArray([ink]))
		draw_polygon(PackedVector2Array([
			Vector2(centre_x, bottom + cell * 0.30),
			Vector2(centre_x - cell * 0.17, bottom + cell * 0.06),
			Vector2(centre_x + cell * 0.17, bottom + cell * 0.06),
		]), PackedColorArray([ink]))


func _draw_grid(cell: float) -> void:
	var extent := board_size()
	for col in range(1, _net.cols):
		draw_line(Vector2(col * cell, 0.0), Vector2(col * cell, extent.y),
				_settings.grid_color, 1.0)
	for row in range(1, _net.rows):
		draw_line(Vector2(0.0, row * cell), Vector2(extent.x, row * cell),
				_settings.grid_color, 1.0)


## The `[` key: the generator's own answer, drawn faintly underneath. Exact,
## not a guess -- the answer was built first and the board was wrecked from it.
func _draw_hint(cell: float) -> void:
	if not _hint_on or _answer.size() != _net.cell_count():
		return
	var ink := _settings.hint_color
	ink.a = 0.30
	var half := cell * 0.5
	var width := cell * _settings.pipe_width * 0.8
	for index in _answer.size():
		var bits := PipesNet.openings(_answer[index])
		if bits == 0:
			continue
		var centre := Vector2(_net.col_of(index) * cell + half, _net.row_of(index) * cell + half)
		for side in PipesNet.SIDES:
			if bits & side != 0:
				draw_line(centre, centre + _outward(side, half), ink, width, true)


func _draw_pieces(cell: float) -> void:
	var half := cell * 0.5
	var width := cell * _settings.pipe_width
	var hub := width * 0.5
	var multi := _net.color_count() > 1
	for index in _net.cell_count():
		var mask := _net.pieces[index]
		if mask == PipesNet.EMPTY:
			continue
		var centre := Vector2(_net.col_of(index) * cell + half, _net.row_of(index) * cell + half)
		if PipesNet.openings(mask) == 0:
			# A pipe-less block, or a wall. A wall is darker and reads as fixed.
			var block := _settings.pinned_pipe_color if _net.pinned[index] != 0 \
					else _settings.blank_color
			draw_rect(Rect2(centre - Vector2(half, half) * 0.84, Vector2(cell, cell) * 0.84),
					block, true)
			continue
		# The pipe is not coloured -- the water is. A piece stays in the plain
		# metal colour until water reaches it, and only then does it show the
		# colour of the run it belongs to (DECISION_LOG 104).
		var ink := _settings.pipe_color
		if _net.piece_is_joined(index):
			ink = _settings.color_for(maxi(0, _net.colors[index])) if multi \
					else _settings.joined_pipe_color
		var water := _flow_amount(index)
		if water > 0.0:
			ink = ink.lerp(_settings.hint_color.lightened(0.4), water * 0.8)
		for side in PipesNet.SIDES:
			if PipesNet.channel_a(mask) & side != 0:
				draw_line(centre, centre + _outward(side, half), ink, width, true)
		if PipesNet.is_overpass(mask):
			# The second channel is drawn thinner and darker so a crossing reads
			# as two runs passing each other, not as one fat junction.
			var second := ink.darkened(0.30)
			for side in PipesNet.SIDES:
				if PipesNet.channel_b(mask) & side != 0:
					draw_line(centre, centre + _outward(side, half), second, width * 0.66, true)
		draw_circle(centre, hub, ink)
		if _net.pinned[index] != 0:
			draw_arc(centre, hub * 1.5, 0.0, TAU, 16, _settings.pinned_pipe_color, 2.0, true)


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
	if _net.has_piece(_hovered):
		draw_rect(rect, ink, true)
	else:
		ink.a = minf(1.0, ink.a * 3.0)
		draw_rect(rect, ink, false, 2.0)


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
