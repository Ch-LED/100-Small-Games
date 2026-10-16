class_name SudokuGenerator
extends RefCounted

## Deals puzzles, and the one thing that makes them puzzles: the uniqueness
## check. A grid with two solutions is not a puzzle, it is a guess.
##
## The search is plain backtracking with a most-constrained-cell-first rule,
## working on row/column/box bitmasks.
##
## Two details are load-bearing and both cost me a wrong version first time:
##
## 1. The work grid is `Array[int]`, not `PackedByteArray`. A Packed array is
##    copied on write, so a helper that fills one in is filling in its own
##    copy -- `full_solution` returned an empty grid for exactly that reason.
##    `Array` is a plain reference, so the grid and the three mask arrays share
##    one meaning across every recursion, exactly like the masks always did.
## 2. The inner loop never calls a helper. Row and column come from integer
##    division, the box and the bit count come from tables.
##
## Both cost a wrong version first time (DECISION_LOG 097).

const SIZE := SudokuBoard.SIZE
const CELL_COUNT := SudokuBoard.CELL_COUNT
const BOX := SudokuBoard.BOX
const ALL_DIGITS := SudokuBoard.ALL_DIGITS

## index -> box number. Nothing in the search may call SudokuBoard.box_of().
static var BOX_OF: PackedInt32Array = _make_box_of()
## Candidate mask -> how many digits it holds. Masks never exceed ALL_DIGITS, so
## the table is one entry longer than that and the inner loop never counts bits
## by hand.
static var POPCOUNT: PackedInt32Array = _make_popcount()


static func _make_box_of() -> PackedInt32Array:
	var table := PackedInt32Array()
	table.resize(CELL_COUNT)
	for index in CELL_COUNT:
		table[index] = SudokuBoard.box_of(index)
	return table


static func _make_popcount() -> PackedInt32Array:
	var table := PackedInt32Array()
	table.resize(ALL_DIGITS + 1)
	table[0] = 0
	for index in range(1, ALL_DIGITS + 1):
		table[index] = table[index >> 1] + (index & 1)
	return table


## Counts the solutions of `grid`, stopping once `limit` have been found.
## `limit = 2` answers "is it unique?" without ever needing the true count.
static func count_solutions(grid: PackedByteArray, limit: int) -> int:
	var work := _to_work(grid)
	var rows: Array[int] = []
	var cols: Array[int] = []
	var boxes: Array[int] = []
	if not _build_state(work, rows, cols, boxes):
		return 0
	return _count(work, rows, cols, boxes, limit)


## A finished, valid grid drawn at random. Which one is not important; that it
## is solvable without a second thought is.
static func full_solution(rng: RandomNumberGenerator) -> PackedByteArray:
	var work: Array[int] = []
	work.resize(CELL_COUNT)
	work.fill(0)
	var rows: Array[int] = []
	var cols: Array[int] = []
	var boxes: Array[int] = []
	_build_state(work, rows, cols, boxes)
	_fill(work, rows, cols, boxes, rng)
	return _from_work(work)


## A full grid with cells taken out, each removal kept only while the solution
## stays unique.
##
## `target_blanks` is a ceiling, not a promise: uniqueness is a hard constraint
## and it wins. The walk stops when the ceiling is met or when it runs out of
## cells to try. So a deal is never harder than asked for, and now and then it
## is a little easier -- which is the honest behaviour, since the alternative
## would be shipping a board with two answers.
static func generate(rng: RandomNumberGenerator, target_blanks: int) -> Dictionary:
	var solution := full_solution(rng)
	var puzzle := _to_work(solution)
	var rows: Array[int] = []
	var cols: Array[int] = []
	var boxes: Array[int] = []
	_build_state(puzzle, rows, cols, boxes)
	var order: Array[int] = []
	for index in CELL_COUNT:
		order.append(index)
	shuffle(order, rng)
	var blanks := 0
	for index in order:
		if blanks >= target_blanks:
			break
		var saved := puzzle[index]
		var bit := 1 << saved
		var row := index / SIZE
		var col := index % SIZE
		var box := BOX_OF[index]
		puzzle[index] = 0
		rows[row] &= ~bit
		cols[col] &= ~bit
		boxes[box] &= ~bit
		if _count(puzzle, rows, cols, boxes, 2) == 1:
			blanks += 1
		else:
			puzzle[index] = saved
			rows[row] |= bit
			cols[col] |= bit
			boxes[box] |= bit
	return {"puzzle": _from_work(puzzle), "solution": solution, "blanks": blanks}


static func shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for index in range(items.size() - 1, 0, -1):
		var swap_with := rng.randi_range(0, index)
		var held: Variant = items[index]
		items[index] = items[swap_with]
		items[swap_with] = held


## Fills the three mask arrays from the grid. False when the grid already
## contradicts itself -- a duplicate in some row, column or box means there is
## nothing left to solve.
static func _build_state(grid: Array[int], rows: Array[int], cols: Array[int],
		boxes: Array[int]) -> bool:
	rows.resize(SIZE)
	cols.resize(SIZE)
	boxes.resize(SIZE)
	rows.fill(0)
	cols.fill(0)
	boxes.fill(0)
	for index in CELL_COUNT:
		var digit := grid[index]
		if digit == 0:
			continue
		var bit := 1 << digit
		var row := index / SIZE
		var col := index % SIZE
		var box := BOX_OF[index]
		if (rows[row] | cols[col] | boxes[box]) & bit:
			return false
		rows[row] |= bit
		cols[col] |= bit
		boxes[box] |= bit
	return true


static func _count(grid: Array[int], rows: Array[int], cols: Array[int],
		boxes: Array[int], limit: int) -> int:
	var best := -1
	var best_mask := 0
	var best_count := SIZE + 1
	for index in CELL_COUNT:
		if grid[index] != 0:
			continue
		var mask := ALL_DIGITS & ~(rows[index / SIZE] | cols[index % SIZE] | boxes[BOX_OF[index]])
		var count := POPCOUNT[mask]
		if count == 0:
			return 0
		if count < best_count:
			best = index
			best_mask = mask
			best_count = count
			if count == 1:
				break
	if best == -1:
		return 1
	var row := best / SIZE
	var col := best % SIZE
	var box := BOX_OF[best]
	var found := 0
	for digit in range(1, SIZE + 1):
		var bit := 1 << digit
		if not (best_mask & bit):
			continue
		grid[best] = digit
		rows[row] |= bit
		cols[col] |= bit
		boxes[box] |= bit
		found += _count(grid, rows, cols, boxes, limit)
		grid[best] = 0
		rows[row] &= ~bit
		cols[col] &= ~bit
		boxes[box] &= ~bit
		if found >= limit:
			return found
	return found


static func _fill(grid: Array[int], rows: Array[int], cols: Array[int],
		boxes: Array[int], rng: RandomNumberGenerator) -> bool:
	var best := -1
	var best_mask := 0
	var best_count := SIZE + 1
	var tied: Array[int] = []
	for index in CELL_COUNT:
		if grid[index] != 0:
			continue
		var mask := ALL_DIGITS & ~(rows[index / SIZE] | cols[index % SIZE] | boxes[BOX_OF[index]])
		var count := POPCOUNT[mask]
		if count == 0:
			return false
		if count < best_count:
			best_count = count
			best = index
			best_mask = mask
			tied = [index]
		elif count == best_count:
			tied.append(index)
	if best == -1:
		return true
	# Among the equally constrained cells, pick at random, so two runs with
	# different seeds do not lay down the same grid.
	if tied.size() > 1:
		best = tied[rng.randi_range(0, tied.size() - 1)]
		best_mask = ALL_DIGITS & ~(rows[best / SIZE] | cols[best % SIZE] | boxes[BOX_OF[best]])
	var row := best / SIZE
	var col := best % SIZE
	var box := BOX_OF[best]
	var digits: Array[int] = []
	for digit in range(1, SIZE + 1):
		if best_mask & (1 << digit):
			digits.append(digit)
	shuffle(digits, rng)
	for digit in digits:
		var bit := 1 << digit
		grid[best] = digit
		rows[row] |= bit
		cols[col] |= bit
		boxes[box] |= bit
		if _fill(grid, rows, cols, boxes, rng):
			return true
		grid[best] = 0
		rows[row] &= ~bit
		cols[col] &= ~bit
		boxes[box] &= ~bit
	return false


static func _to_work(grid: PackedByteArray) -> Array[int]:
	var work: Array[int] = []
	work.resize(CELL_COUNT)
	for index in CELL_COUNT:
		work[index] = grid[index]
	return work


static func _from_work(work: Array[int]) -> PackedByteArray:
	var grid := PackedByteArray()
	grid.resize(CELL_COUNT)
	for index in CELL_COUNT:
		grid[index] = work[index]
	return grid
