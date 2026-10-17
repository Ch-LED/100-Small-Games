class_name MinesweeperBoard
extends RefCounted

## The board and nothing else: where the mines are, what has been uncovered,
## what is flagged. No scene tree, no signals, so the assertions drive it
## directly.
##
## **Mines are placed on the first click**, not when the board is dealt. That
## is what makes the first click safe by construction rather than by luck, and
## it makes the opening move useful: the nine cells around it are guaranteed
## clear, so the first click always opens something (spec 4.1).

enum Flag { NONE, MARK, QUESTION }

## Typed, or `offset.y` cannot be inferred at the call sites.
const NEIGHBOURS: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1, 0), Vector2i(1, 0),
	Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
]

var rows := 9
var cols := 9
var mine_count := 10

var mines := PackedByteArray()
var revealed := PackedByteArray()
var flags := PackedByteArray()
## How many mines touch each cell. Meaningless until `seeded`.
var adjacent := PackedByteArray()

var seeded := false
## Index of the mine that ended the game, or -1.
var exploded := -1


func setup(rows_in: int, cols_in: int, mines_in: int) -> void:
	rows = rows_in
	cols = cols_in
	mine_count = mines_in
	mines = PackedByteArray()
	revealed = PackedByteArray()
	flags = PackedByteArray()
	adjacent = PackedByteArray()
	mines.resize(cell_count())
	revealed.resize(cell_count())
	flags.resize(cell_count())
	adjacent.resize(cell_count())
	mines.fill(0)
	revealed.fill(0)
	flags.fill(0)
	adjacent.fill(0)
	seeded = false
	exploded = -1


func cell_count() -> int:
	return rows * cols


func index_of(row: int, col: int) -> int:
	return row * cols + col


func row_of(cell: int) -> int:
	return cell / cols


func col_of(cell: int) -> int:
	return cell % cols


func in_bounds(row: int, col: int) -> bool:
	return row >= 0 and row < rows and col >= 0 and col < cols


func has_mine(cell: int) -> bool:
	return mines[cell] != 0


func is_revealed(cell: int) -> bool:
	return revealed[cell] != 0


## Places the mines, keeping `safe_cell` and everything touching it clear.
##
## Returns false when the board is too small to hold the mines away from the
## safe area -- only possible on a hand-made board, never on a real level.
func seed(rng: RandomNumberGenerator, safe_cell: int) -> bool:
	var cleared := {}
	cleared[safe_cell] = true
	for offset in NEIGHBOURS:
		var row := row_of(safe_cell) + offset.y
		var col := col_of(safe_cell) + offset.x
		if in_bounds(row, col):
			cleared[index_of(row, col)] = true
	var open: Array[int] = []
	for cell in cell_count():
		if not cleared.has(cell):
			open.append(cell)
	if open.size() < mine_count:
		return false
	for step in range(open.size() - 1, 0, -1):
		var swap_with := rng.randi_range(0, step)
		var held: int = open[step]
		open[step] = open[swap_with]
		open[swap_with] = held
	for step in mine_count:
		mines[open[step]] = 1
	_recount()
	seeded = true
	return true


func _recount() -> void:
	for cell in cell_count():
		if mines[cell] != 0:
			adjacent[cell] = 0
			continue
		var count := 0
		for neighbour in neighbours_of(cell):
			if mines[neighbour] != 0:
				count += 1
		adjacent[cell] = count


func neighbours_of(cell: int) -> Array[int]:
	var out: Array[int] = []
	var row := row_of(cell)
	var col := col_of(cell)
	for offset in NEIGHBOURS:
		if in_bounds(row + offset.y, col + offset.x):
			out.append(index_of(row + offset.y, col + offset.x))
	return out


# --- moves -------------------------------------------------------------------

## Uncovers `cell`. Returns how many cells this opened, or -1 when it was a
## mine. A cell that is already open, or flagged, opens nothing and returns 0.
func reveal(cell: int) -> int:
	if exploded >= 0 or cell < 0 or cell >= cell_count():
		return 0
	if revealed[cell] != 0 or flags[cell] == Flag.MARK:
		return 0
	if not seeded:
		# The play screen seeds before the first reveal; this is only a guard,
		# and it must not look like a mine (-1 means "you stepped on one").
		return 0
	if mines[cell] != 0:
		exploded = cell
		return -1
	return _flood(cell)


## Opening a cell with no adjacent mines opens its neighbours too, and theirs,
## and so on -- the cascade every player expects. Flags stop it: a flag is a
## player saying "not this way", and the cascade respects that.
func _flood(start: int) -> int:
	var opened := 0
	var queue: Array[int] = [start]
	while not queue.is_empty():
		var cell: int = queue.pop_front()
		if revealed[cell] != 0 or flags[cell] == Flag.MARK:
			continue
		revealed[cell] = 1
		opened += 1
		if adjacent[cell] != 0:
			continue
		for neighbour in neighbours_of(cell):
			if revealed[neighbour] == 0 and flags[neighbour] != Flag.MARK:
				queue.append(neighbour)
	return opened


## Cycles a cell's mark: none -> flag -> question -> none. An open cell takes no
## marks -- marking something you can already see would be noise.
func toggle_flag(cell: int) -> bool:
	if exploded >= 0 or cell < 0 or cell >= cell_count() or revealed[cell] != 0:
		return false
	flags[cell] = (flags[cell] + 1) % 3
	return true


## The classic chord: an open number whose neighbouring flags already equal the
## number opens all its other neighbours at once. It is how a player who has
## worked a region out clears it in one click.
##
## Returns the number of cells opened, or -1 when one of them was a mine.
func chord(cell: int) -> int:
	if exploded >= 0 or cell < 0 or cell >= cell_count():
		return 0
	if revealed[cell] == 0 or adjacent[cell] == 0:
		return 0
	var marks := 0
	for neighbour in neighbours_of(cell):
		if flags[neighbour] == Flag.MARK:
			marks += 1
	if marks != adjacent[cell]:
		return 0
	var opened := 0
	for neighbour in neighbours_of(cell):
		if revealed[neighbour] != 0 or flags[neighbour] == Flag.MARK:
			continue
		if mines[neighbour] != 0:
			exploded = neighbour
			return -1
		opened += _flood(neighbour)
	return opened


func revealed_count() -> int:
	var count := 0
	for cell in cell_count():
		if revealed[cell] != 0:
			count += 1
	return count


func flag_count() -> int:
	var count := 0
	for cell in cell_count():
		if flags[cell] == Flag.MARK:
			count += 1
	return count


## Every safe cell uncovered. The win condition never asks whether the flags
## are right -- flags are the player's notes, not the game's bookkeeping.
##
## Stated as "no safe cell is still hidden" rather than as a count, because the
## `[` cheat lets a mine be opened without ending the run: a count would then
## run past the target and the board could never be won at all.
func is_won() -> bool:
	if exploded >= 0:
		return false
	for cell in cell_count():
		if mines[cell] == 0 and revealed[cell] == 0:
			return false
	return true


func is_lost() -> bool:
	return exploded >= 0


## The cells a single number proves to be mines: a number whose remaining count
## is exactly the number of cells still hidden around it, so every one of them
## must be a mine.
##
## This is what the `]` cheat shows. It deliberately stops at one step of
## reasoning -- the player still has to find the safe cells and do the rest,
## it just spares them the arithmetic they were about to do anyway
## (DECISION_LOG 106).
func deducible_mines() -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(cell_count())
	out.fill(0)
	if not seeded or exploded >= 0:
		return out
	for cell in cell_count():
		if revealed[cell] == 0 or adjacent[cell] == 0:
			continue
		var marked := 0
		var hidden: Array[int] = []
		for neighbour in neighbours_of(cell):
			if flags[neighbour] == Flag.MARK:
				marked += 1
			elif revealed[neighbour] == 0:
				hidden.append(neighbour)
		if hidden.is_empty():
			continue
		if adjacent[cell] - marked == hidden.size():
			for hidden_cell in hidden:
				out[hidden_cell] = 1
	return out


## What the player has uncovered so far, for the debug overlay.
func mine_at(cell: int) -> bool:
	return mines[cell] != 0


func adjacent_at(cell: int) -> int:
	return adjacent[cell]
