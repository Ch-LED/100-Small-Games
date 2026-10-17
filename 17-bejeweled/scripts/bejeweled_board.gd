class_name BejeweledBoard
extends RefCounted

## The grid and nothing else: which gem sits where, what a swap does, what falls.
##
## Pure logic, so the assertions drive it directly. The one rule that shapes
## everything here: **a gem is never placed so that it already matches**. The
## opening board is dealt that way, and every refill obeys it as far as it can
## -- a refill that happens to complete a line is a cascade, and cascades are
## the point, so on refill the rule is relaxed (spec 4.2).

const EMPTY := -1

var rows := 8
var cols := 8
var kinds := 6
## One gem kind per cell, or EMPTY.
var cells := PackedInt32Array()


func setup(rows_in: int, cols_in: int, kinds_in: int) -> void:
	rows = rows_in
	cols = cols_in
	kinds = maxi(3, kinds_in)
	cells = PackedInt32Array()
	cells.resize(cell_count())
	cells.fill(EMPTY)


func cell_count() -> int:
	return rows * cols


func index_of(row: int, col: int) -> int:
	return row * cols + col


func row_of(cell: int) -> int:
	return cell / cols


func col_of(cell: int) -> int:
	return cell % cols


func gem_at(cell: int) -> int:
	if cell < 0 or cell >= cell_count():
		return EMPTY
	return cells[cell]


func set_gem(cell: int, kind: int) -> void:
	cells[cell] = kind


func is_empty(cell: int) -> bool:
	return gem_at(cell) == EMPTY


# --- dealing ----------------------------------------------------------------

## Fills the board at random, never completing a line as it goes. The board
## therefore opens quiet -- no free points, no cascade before the player has
## touched anything.
##
## Retries until the result has at least one legal swap. A board with no move
## is not a puzzle, and the player would have to sit and wait for a reshuffle
## they did not ask for.
func deal(rng: RandomNumberGenerator, attempts: int = 20) -> bool:
	for _attempt in attempts:
		cells.fill(EMPTY)
		for row in rows:
			for col in cols:
				set_gem(index_of(row, col), _safe_kind(row, col, rng))
		if has_move():
			return true
	return false


## A kind that will not complete a line of three when dropped at (row, col),
## given only what is already to its left and above -- the two directions that
## are filled in by the time this cell is reached.
func _safe_kind(row: int, col: int, rng: RandomNumberGenerator) -> int:
	var banned := {}
	if col >= 2:
		var left := cells[index_of(row, col - 1)]
		if left >= 0 and left == cells[index_of(row, col - 2)]:
			banned[left] = true
	if row >= 2:
		var up := cells[index_of(row - 1, col)]
		if up >= 0 and up == cells[index_of(row - 2, col)]:
			banned[up] = true
	var allowed: Array[int] = []
	for kind in kinds:
		if not banned.has(kind):
			allowed.append(kind)
	if allowed.is_empty():
		return rng.randi_range(0, kinds - 1)
	return allowed[rng.randi_range(0, allowed.size() - 1)]


# --- swapping ---------------------------------------------------------------

func are_adjacent(first: int, second: int) -> bool:
	if first < 0 or second < 0 or first >= cell_count() or second >= cell_count():
		return false
	var row_gap := absi(row_of(first) - row_of(second))
	var col_gap := absi(col_of(first) - col_of(second))
	return row_gap + col_gap == 1


## Exchanges two cells. It does not care whether they touch -- adjacency is the
## play screen's rule, and the `]` cheat is exactly the case where it is not.
func swap(first: int, second: int) -> void:
	if first < 0 or second < 0 or first >= cell_count() or second >= cell_count():
		return
	var held := cells[first]
	cells[first] = cells[second]
	cells[second] = held


## True when swapping these two would complete a line. This is what decides
## whether a player's swap is kept or bounced back.
func swap_makes_match(first: int, second: int) -> bool:
	swap(first, second)
	var any := not matched_cells().is_empty()
	swap(first, second)
	return any


# --- matching ---------------------------------------------------------------

## Every cell that belongs to a horizontal or vertical run of three or more.
## Returns the cell indices; runs that cross are reported as one set, which is
## what a player sees anyway.
func matched_cells() -> Array[int]:
	var marked := PackedByteArray()
	marked.resize(cell_count())
	marked.fill(0)
	for row in rows:
		_mark_runs(marked, row, true)
	for col in cols:
		_mark_runs(marked, col, false)
	var out: Array[int] = []
	for cell in cell_count():
		if marked[cell] != 0:
			out.append(cell)
	return out


func _mark_runs(marked: PackedByteArray, line: int, horizontal: bool) -> void:
	var length := cols if horizontal else rows
	var start := 0
	for step in range(1, length + 1):
		var same := step < length and _line_gem(line, step, horizontal) >= 0 \
				and _line_gem(line, step, horizontal) == _line_gem(line, start, horizontal)
		if same:
			continue
		if step - start >= 3:
			for fill in range(start, step):
				marked[_line_cell(line, fill, horizontal)] = 1
		start = step


func _line_gem(line: int, step: int, horizontal: bool) -> int:
	return cells[index_of(line, step) if horizontal else index_of(step, line)]


func _line_cell(line: int, step: int, horizontal: bool) -> int:
	return index_of(line, step) if horizontal else index_of(step, line)


# --- falling ----------------------------------------------------------------

## Pulls every gem down into the gaps and refills the top of each column.
## Returns how many cells changed, which is how the play screen knows whether
## another cascade pass is worth running.
func apply_gravity(rng: RandomNumberGenerator) -> int:
	var moved := 0
	for col in cols:
		var write := rows - 1
		for row in range(rows - 1, -1, -1):
			var kind := cells[index_of(row, col)]
			if kind < 0:
				continue
			if write != row:
				cells[index_of(write, col)] = kind
				cells[index_of(row, col)] = EMPTY
				moved += 1
			write -= 1
		for row in range(write, -1, -1):
			cells[index_of(row, col)] = rng.randi_range(0, kinds - 1)
			moved += 1
	return moved


func clear(cells_to_clear: Array[int]) -> void:
	for cell in cells_to_clear:
		if cell >= 0 and cell < cell_count():
			cells[cell] = EMPTY


# --- playability ------------------------------------------------------------

## True when at least one swap of two touching gems would score.
func has_move() -> bool:
	for row in rows:
		for col in cols:
			var cell := index_of(row, col)
			if col + 1 < cols and swap_makes_match(cell, index_of(row, col + 1)):
				return true
			if row + 1 < rows and swap_makes_match(cell, index_of(row + 1, col)):
				return true
	return false


## One legal swap, for the `[` hint: the first one found, scanning the board in
## the order a player would.
func find_move() -> Array[int]:
	for row in rows:
		for col in cols:
			var cell := index_of(row, col)
			if col + 1 < cols and swap_makes_match(cell, index_of(row, col + 1)):
				return [cell, index_of(row, col + 1)]
			if row + 1 < rows and swap_makes_match(cell, index_of(row + 1, col)):
				return [cell, index_of(row + 1, col)]
	return []
