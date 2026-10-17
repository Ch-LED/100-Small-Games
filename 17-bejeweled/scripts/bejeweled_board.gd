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

## A gem can carry a charge, earned by making a longer line. It is still a gem
## of its own colour -- the charge only decides what happens when it is cleared
## (DECISION_LOG 109).
enum Special { NONE, BOMB, LIGHTNING }

var rows := 8
var cols := 8
var kinds := 6
## One gem kind per cell, or EMPTY.
var cells := PackedInt32Array()
## One `Special` per cell.
var special := PackedByteArray()


func setup(rows_in: int, cols_in: int, kinds_in: int) -> void:
	rows = rows_in
	cols = cols_in
	kinds = maxi(3, kinds_in)
	cells = PackedInt32Array()
	cells.resize(cell_count())
	cells.fill(EMPTY)
	special = PackedByteArray()
	special.resize(cell_count())
	special.fill(Special.NONE)


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


## The runs themselves, not just the cells in them: a run of four earns a
## charge and a run of five earns a bigger one, which needs the length and the
## direction, not a set.
func matched_runs() -> Array[Dictionary]:
	var runs: Array[Dictionary] = []
	for row in rows:
		_collect_runs(runs, row, true)
	for col in cols:
		_collect_runs(runs, col, false)
	return runs


func _collect_runs(runs: Array[Dictionary], line: int, horizontal: bool) -> void:
	var length := cols if horizontal else rows
	var start := 0
	for step in range(1, length + 1):
		var same := step < length and _line_gem(line, step, horizontal) >= 0 \
				and _line_gem(line, step, horizontal) == _line_gem(line, start, horizontal)
		if same:
			continue
		if step - start >= 3:
			var run: Array[int] = []
			for fill in range(start, step):
				run.append(_line_cell(line, fill, horizontal))
			runs.append({"cells": run, "horizontal": horizontal})
		start = step


## What a run is worth as a charge, if anything.
static func reward_for(length: int) -> int:
	if length >= 5:
		return Special.LIGHTNING
	if length >= 4:
		return Special.BOMB
	return Special.NONE


## The charges a clear should leave behind: one per long run, planted in the
## middle of that run, keeping its colour. A cell claimed by two runs gets one
## charge, not two.
func pending_rewards() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var used := {}
	for run in matched_runs():
		var run_cells: Array = run["cells"]
		var charge := reward_for(run_cells.size())
		if charge == Special.NONE:
			continue
		var middle: int = run_cells[run_cells.size() / 2]
		if used.has(middle):
			continue
		used[middle] = true
		out.append({"cell": middle, "special": charge, "kind": gem_at(middle)})
	return out


func set_special(cell: int, charge: int) -> void:
	if cell >= 0 and cell < cell_count():
		special[cell] = charge


## Grows a set of cells into everything a chain of charges would take with it:
## a bomb takes its neighbours, a lightning takes its row and column, and a
## charge caught in either goes off in turn. Without this the charges would
## only ever be decoration.
func expand_specials(start: Array[int]) -> Array[int]:
	var in_set := {}
	for cell in start:
		in_set[cell] = true
	var processed := {}
	var queue: Array[int] = start.duplicate()
	while not queue.is_empty():
		var cell: int = queue.pop_back()
		if processed.has(cell):
			continue
		processed[cell] = true
		var charge := special[cell]
		if charge == Special.NONE:
			continue
		for other in _blast(cell, charge):
			if in_set.has(other):
				continue
			in_set[other] = true
			queue.append(other)
	var out: Array[int] = []
	for cell in in_set:
		out.append(cell)
	return out


func _blast(cell: int, charge: int) -> Array[int]:
	var out: Array[int] = []
	if charge == Special.BOMB:
		var row := row_of(cell)
		var col := col_of(cell)
		for row_step in range(-1, 2):
			for col_step in range(-1, 2):
				var other_row := row + row_step
				var other_col := col + col_step
				if other_row >= 0 and other_row < rows and other_col >= 0 \
						and other_col < cols:
					out.append(index_of(other_row, other_col))
	elif charge == Special.LIGHTNING:
		for step in cols:
			out.append(index_of(row_of(cell), step))
		for step in rows:
			out.append(index_of(step, col_of(cell)))
	return out


func _line_gem(line: int, step: int, horizontal: bool) -> int:
	return cells[index_of(line, step) if horizontal else index_of(step, line)]


func _line_cell(line: int, step: int, horizontal: bool) -> int:
	return index_of(line, step) if horizontal else index_of(step, line)


# --- falling ----------------------------------------------------------------

## Every gem that moved this pass, as (from, to). The view needs this to slide
## a gem the distance it actually fell -- starting it one row above its new
## home made a three-row drop look like a gem appearing out of thin air
## (DECISION_LOG 109).
var last_moves: Array[Vector2i] = []
## Cells that were refilled from the top of the board.
var last_spawns: Array[int] = []


## Pulls every gem down into the gaps and refills the top of each column.
## Returns how many cells changed, which is how the play screen knows whether
## another cascade pass is worth running.
func apply_gravity(rng: RandomNumberGenerator) -> int:
	var moved := 0
	last_moves.clear()
	last_spawns.clear()
	for col in cols:
		var write := rows - 1
		for row in range(rows - 1, -1, -1):
			var kind := cells[index_of(row, col)]
			if kind < 0:
				continue
			if write != row:
				cells[index_of(write, col)] = kind
				special[index_of(write, col)] = special[index_of(row, col)]
				cells[index_of(row, col)] = EMPTY
				special[index_of(row, col)] = Special.NONE
				last_moves.append(Vector2i(index_of(row, col), index_of(write, col)))
				moved += 1
			write -= 1
		for row in range(write, -1, -1):
			cells[index_of(row, col)] = rng.randi_range(0, kinds - 1)
			special[index_of(row, col)] = Special.NONE
			last_spawns.append(index_of(row, col))
			moved += 1
	return moved


func clear(cells_to_clear: Array[int]) -> void:
	for cell in cells_to_clear:
		if cell >= 0 and cell < cell_count():
			cells[cell] = EMPTY
			special[cell] = Special.NONE


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
