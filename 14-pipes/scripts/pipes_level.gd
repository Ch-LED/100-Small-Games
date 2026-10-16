class_name PipesLevel
extends RefCounted

## The board's rules and the player's drawing, with no scene tree in sight so
## the assertions can drive it directly.
##
## A colour is correct when the line the player drew runs from one of its ends
## to the other; the board is solved when every colour is correct *and* every
## cell is covered. Coverage is tracked as a bitmask per cell rather than an
## owner id, because the super cheat lets lines cross -- a crossed cell belongs
## to two colours at once, and an owner id cannot say that (spec 4).
##
## `solution` is the answer the generator cut up. It is kept for the `[` key
## alone: nothing here ever checks the player against it, so a board solved some
## other way is a board solved (spec 4.2).

const NO_COLOR := -1
## How many steps back the undo key can walk.
const HISTORY_LIMIT := 60

var rows := 5
var cols := 5
var color_count := 0
var solution: Array[PackedInt32Array] = []
## Two ends per colour, in the order they were cut.
var ends: Array[PackedInt32Array] = []
## Bit `c` set means colour c covers this cell.
var occupancy := PackedInt64Array()
## What the player has drawn; `drawn[c]` is a chain of cells, possibly empty.
var drawn: Array = []

var _stroke_color := NO_COLOR
var _history: Array = []


func setup(dealt: Dictionary) -> void:
	rows = int(dealt["rows"])
	cols = int(dealt["cols"])
	solution = []
	ends = []
	for path in (dealt["paths"] as Array):
		var chain: PackedInt32Array = path
		solution.append(chain)
		ends.append(PackedInt32Array([chain[0], chain[chain.size() - 1]]))
	color_count = solution.size()
	occupancy = PackedInt64Array()
	occupancy.resize(rows * cols)
	occupancy.fill(0)
	drawn = []
	for color in color_count:
		drawn.append([] as Array[int])
	_stroke_color = NO_COLOR
	_history = []


static func index_of(row: int, col: int, cols: int) -> int:
	return row * cols + col


func row_of(cell: int) -> int:
	return cell / cols


func col_of(cell: int) -> int:
	return cell % cols


func cell_count() -> int:
	return rows * cols


func is_endpoint(cell: int, color: int) -> bool:
	var pair := ends[color]
	return pair[0] == cell or pair[1] == cell


func color_at(cell: int) -> int:
	var bits := occupancy[cell]
	if bits == 0:
		return NO_COLOR
	if bits & (bits - 1) != 0:
		return NO_COLOR
	return _bit_index(bits)


## True where two lines have been laid over each other -- only reachable with
## the super cheat on.
func is_crossing(cell: int) -> bool:
	var bits := occupancy[cell]
	return bits != 0 and (bits & (bits - 1)) != 0


func covers(cell: int, color: int) -> bool:
	return occupancy[cell] & (1 << color) != 0


## Every colour covering this cell, lowest first. One entry for an ordinary
## cell, two where lines were crossed.
func colors_at(cell: int) -> Array[int]:
	var out: Array[int] = []
	var bits := occupancy[cell]
	var color := 0
	while bits != 0:
		if bits & 1:
			out.append(color)
		bits >>= 1
		color += 1
	return out


func covered_count() -> int:
	var count := 0
	for cell in cell_count():
		if occupancy[cell] != 0:
			count += 1
	return count


## A colour is done when its chain runs between its own two ends. It may be
## longer than the generator's answer and take any route it likes.
func is_color_done(color: int) -> bool:
	var path: Array = drawn[color]
	if path.size() < 2:
		return false
	var pair := ends[color]
	var first: int = path[0]
	var last: int = path[path.size() - 1]
	return (first == pair[0] and last == pair[1]) or (first == pair[1] and last == pair[0])


func is_solved() -> bool:
	for color in color_count:
		if not is_color_done(color):
			return false
	return covered_count() == cell_count()


func done_count() -> int:
	var count := 0
	for color in color_count:
		if is_color_done(color):
			count += 1
	return count


# --- drawing -----------------------------------------------------------------

## Starts a stroke at `cell`. Only an end of `color` can start one, and
## starting over a colour throws away whatever it had -- dragging from an end
## means "let me redo this one", which is how the player expects to fix a line.
func begin_stroke(color: int, cell: int) -> bool:
	if color < 0 or color >= color_count or not is_endpoint(cell, color):
		return false
	_push_history()
	clear_color(color)
	_stroke_color = color
	var chain: Array[int] = [cell]
	drawn[color] = chain
	occupancy[cell] |= 1 << color
	return true


func is_stroking() -> bool:
	return _stroke_color != NO_COLOR


func stroke_color() -> int:
	return _stroke_color


## Extends the live stroke to `cell`, or trims back to it when the stroke
## already passes through. Returns true when something changed.
##
## `bridges` is the super cheat: with it on, a line may be laid over a colour
## that is already there. Without it the cell has to be free (spec 6.2).
func extend_stroke(cell: int, bridges: bool) -> bool:
	if _stroke_color == NO_COLOR:
		return false
	var color := _stroke_color
	var path: Array = drawn[color]
	var head: int = path[path.size() - 1]
	if cell == head:
		return false
	var existing := path.find(cell)
	if existing >= 0:
		# Dragging back over the line shortens it, which is the gesture every
		# player already has in their hands.
		for step in range(path.size() - 1, existing, -1):
			_release(color, path[step])
			path.remove_at(step)
		return true
	if not _touching(head, cell):
		return false
	if is_endpoint(cell, color):
		if cell == path[0]:
			return false
	elif covers(cell, color):
		return false
	elif occupancy[cell] != 0:
		# Somebody else is already here. Only the super cheat lets a line be
		# laid over it, and even then it may not run over a dot -- an end
		# belongs to one colour and must stay legible.
		if not bridges or is_any_endpoint(cell):
			return false
	path.append(cell)
	occupancy[cell] |= 1 << color
	return true


func end_stroke() -> void:
	if _stroke_color == NO_COLOR:
		return
	var color := _stroke_color
	_stroke_color = NO_COLOR
	# A stroke that never reached the far end is still kept: it is a half-drawn
	# line the player can pick up again, not a mistake to be thrown away.
	if (drawn[color] as Array).size() < 2:
		clear_color(color)


func clear_color(color: int) -> bool:
	if color < 0 or color >= color_count:
		return false
	var path: Array = drawn[color]
	if path.is_empty():
		return false
	for cell in path:
		_release(color, cell)
	var empty: Array[int] = []
	drawn[color] = empty
	if _stroke_color == color:
		_stroke_color = NO_COLOR
	return true


func clear_all() -> void:
	for color in color_count:
		clear_color(color)
	_history = []


## The one thing undo has to put back: which cells each colour covers.
func push_undo() -> void:
	_push_history()


func undo() -> bool:
	if _history.is_empty():
		return false
	var state: Array = _history.pop_back()
	for color in color_count:
		drawn[color] = (state[color] as Array[int]).duplicate()
	_rebuild_occupancy()
	_stroke_color = NO_COLOR
	return true


func can_undo() -> bool:
	return not _history.is_empty()


# --- internals ---------------------------------------------------------------

func _push_history() -> void:
	var state: Array = []
	for color in color_count:
		state.append((drawn[color] as Array[int]).duplicate())
	_history.append(state)
	while _history.size() > HISTORY_LIMIT:
		_history.pop_front()


func _rebuild_occupancy() -> void:
	occupancy.fill(0)
	for color in color_count:
		for cell in (drawn[color] as Array[int]):
			occupancy[cell] |= 1 << color


func _release(color: int, cell: int) -> void:
	occupancy[cell] &= ~(1 << color)


func _touching(first: int, second: int) -> bool:
	var gap := absi(first - second)
	if gap == cols:
		return true
	return gap == 1 and row_of(first) == row_of(second)


func is_any_endpoint(cell: int) -> bool:
	for color in color_count:
		if is_endpoint(cell, color):
			return true
	return false


static func _bit_index(bits: int) -> int:
	var index := 0
	var remaining := bits
	while remaining & 1 == 0:
		remaining >>= 1
		index += 1
	return index
