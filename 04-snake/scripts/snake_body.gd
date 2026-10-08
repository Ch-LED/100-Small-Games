class_name SnakeBody
extends Node2D
## The snake: cell data (index 0 is the head), the step rules, and a pool of
## segment nodes used to draw it. It knows nothing about food, score or audio —
## the controller drives it and reads the result.

enum Death { NONE, WALL, SELF }

const SEGMENT_SCENE := preload("res://04-snake/scenes/segment.tscn")

var death_reason: int = Death.NONE

var _cells: Array[Vector2i] = []
var _segments: Array[SnakeSegment] = []

var _direction := SnakeGrid.DIR_RIGHT
var _desired := SnakeGrid.DIR_NONE
var _grow_pending := 0
var _alive := false

var _side := 40.0
var _inset := 3.0
var _body_color := Color("57D97B")
var _head_color := Color("C8F56A")
var _dead_color := Color("E0433A")
var _dead_tint := false

## Off = hitting the board edge kills; on = the snake wraps to the far side.
var wrap_edges := false


func configure(side: float, inset: float, body_color: Color, head_color: Color,
		dead_color: Color, wrap: bool) -> void:
	_side = side
	_inset = inset
	_body_color = body_color
	_head_color = head_color
	_dead_color = dead_color
	wrap_edges = wrap


## Starts a fresh run. `cells` is head-first; `dir` is the heading.
func reset(cells: Array[Vector2i], dir: Vector2i) -> void:
	_cells = cells.duplicate()
	_direction = dir if dir != SnakeGrid.DIR_NONE else SnakeGrid.DIR_RIGHT
	_desired = SnakeGrid.DIR_NONE
	_grow_pending = 0
	_alive = true
	_dead_tint = false
	death_reason = Death.NONE
	_ensure_segments()
	_refresh()


# --- queries ----------------------------------------------------------------

func head_cell() -> Vector2i:
	return _cells[0] if not _cells.is_empty() else Vector2i.ZERO


func cells() -> Array[Vector2i]:
	return _cells


func length() -> int:
	return _cells.size()


func direction() -> Vector2i:
	return _direction


func occupies(cell: Vector2i) -> bool:
	return _cells.has(cell)


## Where the head lands stepping `dir`, with edge wrapping applied.
func step_target(dir: Vector2i) -> Vector2i:
	var cell := head_cell() + dir
	if not SnakeGrid.in_bounds(cell) and wrap_edges:
		return SnakeGrid.wrap(cell)
	return cell


## Whether entering `cell` would be fatal under the current rules. Mirrors the
## real step check exactly, so the debug overlay never lies.
func would_die_entering(cell: Vector2i) -> bool:
	if not SnakeGrid.in_bounds(cell):
		return not wrap_edges
	return _hits_body(cell)


# --- commands ---------------------------------------------------------------

## Records a turn intent. Reversing straight back onto the neck is dropped.
func queue_direction(dir: Vector2i) -> void:
	if dir == SnakeGrid.DIR_NONE or not _alive:
		return
	if SnakeGrid.is_opposite(dir, _direction):
		return
	_desired = dir


func grow(count: int) -> void:
	_grow_pending += maxi(0, count)


func set_dead_tint(enabled: bool) -> void:
	_dead_tint = enabled
	_refresh()


## Advances one grid step. Returns false if this step killed the snake.
func advance() -> bool:
	if not _alive:
		return false
	if _desired != SnakeGrid.DIR_NONE:
		_direction = _desired
		_desired = SnakeGrid.DIR_NONE

	var next := head_cell() + _direction
	if not SnakeGrid.in_bounds(next):
		if wrap_edges:
			next = SnakeGrid.wrap(next)
		else:
			return _die(Death.WALL)
	if _hits_body(next):
		return _die(Death.SELF)

	_cells.insert(0, next)
	if _grow_pending > 0:
		_grow_pending -= 1
	else:
		_cells.pop_back()
	_refresh()
	return true


# --- internals --------------------------------------------------------------

## The tail vacates its cell on this step unless the snake is growing, so it is
## not an obstacle (classic "head may follow the tail" rule).
func _hits_body(cell: Vector2i) -> bool:
	var count := _cells.size()
	if _grow_pending == 0:
		count -= 1
	for i in count:
		if _cells[i] == cell:
			return true
	return false


func _die(reason: int) -> bool:
	death_reason = reason
	_alive = false
	return false


func _ensure_segments() -> void:
	while _segments.size() < _cells.size():
		var segment: SnakeSegment = SEGMENT_SCENE.instantiate()
		add_child(segment)
		segment.configure(_side, _inset, _body_color)
		_segments.append(segment)


func _refresh() -> void:
	_ensure_segments()
	for i in _segments.size():
		var segment := _segments[i]
		if i >= _cells.size():
			segment.visible = false
			continue
		segment.visible = true
		segment.position = SnakeGrid.cell_center(_cells[i])
		if _dead_tint:
			segment.set_color(_dead_color)
		elif i == 0:
			segment.set_color(_head_color)
		else:
			segment.set_color(_body_color)
