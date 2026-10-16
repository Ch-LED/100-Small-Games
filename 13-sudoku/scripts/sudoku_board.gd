class_name SudokuBoard
extends RefCounted

## The puzzle state and nothing else: which cells were dealt, what the player
## has entered, and the pencil marks. No scene tree, no signals, so the
## assertions can drive it directly (spec 4).
##
## `given` is written once when a puzzle is dealt and never touched again --
## that is what makes a dealt digit unerasable, and it is the only rule this
## class enforces. Everything else (a digit repeating in a row, a wrong digit)
## is recorded, not forbidden: conflict reporting lives in `conflicts()`.

const SIZE := 9
const CELL_COUNT := 81
const BOX := 3
## One bit per digit, digit d using bit d -- so the mask spans bits 1 through 9
## and bit 0 is never used. The obvious-looking 0x1FF (bits 0..8) is wrong: it
## leaves digit 9 unreachable, and a row that can only ever hold eight digits
## can never be filled (DECISION_LOG 097).
const ALL_DIGITS := 0x3FE

## 0 means empty.
var given := PackedByteArray()
var values := PackedByteArray()
## Pencil marks; bit `digit` set means that digit is pencilled in.
var notes := PackedInt32Array()


func _init() -> void:
	clear()


func clear() -> void:
	given.resize(CELL_COUNT)
	values.resize(CELL_COUNT)
	notes.resize(CELL_COUNT)
	given.fill(0)
	values.fill(0)
	notes.fill(0)


static func index_of(row: int, col: int) -> int:
	return row * SIZE + col


static func row_of(index: int) -> int:
	return index / SIZE


static func col_of(index: int) -> int:
	return index % SIZE


static func box_of(index: int) -> int:
	return (row_of(index) / BOX) * BOX + col_of(index) / BOX


## Deals a puzzle. `puzzle` is 81 digits, 0 for a blank.
func load_puzzle(puzzle: PackedByteArray) -> void:
	clear()
	for index in CELL_COUNT:
		var digit := puzzle[index] if index < puzzle.size() else 0
		given[index] = digit
		values[index] = digit


func is_given(index: int) -> bool:
	return given[index] != 0


func is_blank(index: int) -> bool:
	return values[index] == 0


func value_at(index: int) -> int:
	return values[index]


func filled_count() -> int:
	var count := 0
	for index in CELL_COUNT:
		if values[index] != 0:
			count += 1
	return count


func blank_count() -> int:
	return CELL_COUNT - filled_count()


## Player entries only. A dealt digit is not theirs to move or remove, so this
## refuses and says so rather than silently doing nothing.
func place(index: int, digit: int) -> bool:
	if digit < 1 or digit > SIZE or is_given(index):
		return false
	values[index] = digit
	notes[index] = 0
	return true


func erase(index: int) -> bool:
	if is_given(index):
		return false
	if values[index] == 0 and notes[index] == 0:
		return false
	values[index] = 0
	notes[index] = 0
	return true


func toggle_note(index: int, digit: int) -> bool:
	if digit < 1 or digit > SIZE or is_given(index) or values[index] != 0:
		return false
	notes[index] ^= 1 << digit
	return true


## The digits already placed in the same row, column and box, as one mask.
func used_mask(index: int) -> int:
	var mask := 0
	var row := row_of(index)
	var col := col_of(index)
	for step in SIZE:
		mask |= _bit(values[index_of(row, step)])
		mask |= _bit(values[index_of(step, col)])
	var box_row := (row / BOX) * BOX
	var box_col := (col / BOX) * BOX
	for row_step in BOX:
		for col_step in BOX:
			mask |= _bit(values[index_of(box_row + row_step, box_col + col_step)])
	return mask


## What could legally go here, ignoring whether it is the right answer.
func candidates_at(index: int) -> int:
	if values[index] != 0:
		return 0
	return ALL_DIGITS & ~used_mask(index)


func candidate_count(index: int) -> int:
	var mask := candidates_at(index)
	var count := 0
	while mask:
		mask &= mask - 1
		count += 1
	return count


## One byte per cell: non-zero where this cell's digit repeats inside its row,
## column or box. Only ever blames cells the board actually contradicts -- it
## never compares against the solution, so a wrong-but-not-yet-duplicated digit
## stays quiet (spec 5.3).
func conflicts() -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(CELL_COUNT)
	out.fill(0)
	for unit in SIZE:
		_mark_duplicates(out, _row_cells(unit))
		_mark_duplicates(out, _col_cells(unit))
		_mark_duplicates(out, _box_cells(unit))
	return out


func conflict_count() -> int:
	var out := conflicts()
	var count := 0
	for index in CELL_COUNT:
		count += out[index]
	return count


func has_conflicts() -> bool:
	return conflict_count() > 0


## Solved means every cell filled and nothing repeated anywhere. It does not
## mean "matches the generator's solution", which would let a second valid
## solution be rejected.
func is_complete() -> bool:
	if filled_count() != CELL_COUNT:
		return false
	return not has_conflicts()


func snapshot() -> Dictionary:
	return {
		"given": given.duplicate(),
		"values": values.duplicate(),
		"notes": notes.duplicate(),
	}


func restore(state: Dictionary) -> void:
	given = (state["given"] as PackedByteArray).duplicate()
	values = (state["values"] as PackedByteArray).duplicate()
	notes = (state["notes"] as PackedInt32Array).duplicate()


func _mark_duplicates(out: PackedByteArray, cells: Array[int]) -> void:
	var seen := 0
	for index in cells:
		var digit := values[index]
		if digit == 0:
			continue
		if seen & (1 << digit):
			for other in cells:
				if values[other] == digit:
					out[other] = 1
		seen |= 1 << digit


static func _bit(digit: int) -> int:
	return 0 if digit == 0 else 1 << digit


static func _row_cells(row: int) -> Array[int]:
	var cells: Array[int] = []
	for col in SIZE:
		cells.append(index_of(row, col))
	return cells


static func _col_cells(col: int) -> Array[int]:
	var cells: Array[int] = []
	for row in SIZE:
		cells.append(index_of(row, col))
	return cells


static func _box_cells(box: int) -> Array[int]:
	var cells: Array[int] = []
	var box_row := (box / BOX) * BOX
	var box_col := (box % BOX) * BOX
	for row_step in BOX:
		for col_step in BOX:
			cells.append(index_of(box_row + row_step, box_col + col_step))
	return cells
