class_name LightsOutGrid
extends RefCounted
## The board as plain data: 25 bits, one per light. Deliberately not a Node, so
## the rules and the solver can be asserted without instantiating anything.
##
## The state is a single int rather than an array because the whole puzzle is
## linear over GF(2): "press a cell" is XOR with a fixed mask, which makes both
## "press twice cancels" and the solver fall straight out.

const SIZE := 5
const CELLS := SIZE * SIZE
const SOLVED := 0

var bits := SOLVED


func reset() -> void:
	bits = SOLVED


func index_of(row: int, col: int) -> int:
	return row * SIZE + col


func is_inside(row: int, col: int) -> bool:
	return row >= 0 and row < SIZE and col >= 0 and col < SIZE


func get_cell(row: int, col: int) -> bool:
	if not is_inside(row, col):
		return false
	return ((bits >> index_of(row, col)) & 1) == 1


func set_cell(row: int, col: int, on: bool) -> void:
	if not is_inside(row, col):
		return
	var bit := 1 << index_of(row, col)
	if on:
		bits |= bit
	else:
		bits &= ~bit


## Which bits one press flips: the cell itself plus its four orthogonal
## neighbours, with anything off the board simply not existing. This is the only
## place that decides what a press does — press() and the solver both use it.
static func press_mask(row: int, col: int) -> int:
	var offsets: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	]
	var mask := 0
	for offset in offsets:
		var r := row + offset.y
		var c := col + offset.x
		if r >= 0 and r < SIZE and c >= 0 and c < SIZE:
			mask |= 1 << (r * SIZE + c)
	return mask


func press(row: int, col: int) -> void:
	if not is_inside(row, col):
		return
	bits ^= press_mask(row, col)


func lit_count() -> int:
	var count := 0
	for i in CELLS:
		if (bits >> i) & 1:
			count += 1
	return count


func is_solved() -> bool:
	return bits == SOLVED


func snapshot() -> int:
	return bits


## Builds a solvable puzzle: press `press_count` DISTINCT cells from the solved
## state. Distinct matters — pressing one cell twice cancels itself out, which
## would quietly hand back an easier board than asked for. Because a press is
## its own inverse, anything built this way can be undone.
func scramble(rng: RandomNumberGenerator, press_count: int) -> void:
	bits = SOLVED
	var candidates: Array[Vector2i] = []
	for row in SIZE:
		for col in SIZE:
			candidates.append(Vector2i(col, row))
	var wanted: int = mini(press_count, candidates.size())
	for i in wanted:
		var pick := rng.randi_range(0, candidates.size() - 1)
		var cell: Vector2i = candidates[pick]
		candidates.remove_at(pick)
		press(cell.y, cell.x)


## Light chasing, run on a copy so the board itself is left alone.
##
## Try each of the 2^SIZE ways to press the top row; for each, chase downwards —
## wherever the row above is still lit, press the cell below it. The bottom row
## then decides whether that first-row choice was right. Keep the shortest
## working one.
##
## For the standard 5x5 board the coefficient matrix is full rank, so exactly
## one first-row choice works and the answer is unique; the assertions lean on
## that. Returns the cell indices to press, ascending.
func optimal_solution() -> Array[int]:
	var best: Array[int] = []
	for pattern in (1 << SIZE):
		var work := bits
		var presses: Array[int] = []
		for col in SIZE:
			if (pattern >> col) & 1:
				work ^= press_mask(0, col)
				presses.append(index_of(0, col))
		for row in range(1, SIZE):
			for col in SIZE:
				if (work >> index_of(row - 1, col)) & 1:
					work ^= press_mask(row, col)
					presses.append(index_of(row, col))
		if work != SOLVED:
			continue
		if best.is_empty() or presses.size() < best.size():
			best = presses
	return best
