class_name PipesNet
extends RefCounted

## A grid of pipe pieces, where a piece is a mask of the sides it opens onto.
##
## This one class serves three of the four modes -- turning, sliding a whole
## row, sliding a piece into a gap. What separates them is only what the player
## may do to the grid and how a deal was shuffled, never what the grid is or
## what "joined" means. So the modes share every rule below and differ in one
## small verb each (spec 5).
##
## Bit per side: north 1, east 2, south 4, west 8. A piece's mask says where it
## opens; a piece with one opening is an end, two is a run or an elbow, three a
## tee, four a crossing.

const NORTH := 1
const EAST := 2
const SOUTH := 4
const WEST := 8
const SIDES := [NORTH, EAST, SOUTH, WEST]
## Bit of the neighbour on the far side of each of those.
const OPPOSITE := {NORTH: SOUTH, EAST: WEST, SOUTH: NORTH, WEST: EAST}
const STEPS := {NORTH: Vector2i(0, -1), EAST: Vector2i(1, 0),
		SOUTH: Vector2i(0, 1), WEST: Vector2i(-1, 0)}

const EMPTY := -1

var rows := 5
var cols := 5
## One mask per cell, or EMPTY.
var pieces := PackedInt32Array()
## Which cells start pinned. A turning mode has none; the sliding modes use
## them for the frame a piece cannot be dragged out of.
var pinned := PackedByteArray()


func setup(rows_in: int, cols_in: int) -> void:
	rows = rows_in
	cols = cols_in
	pieces = PackedInt32Array()
	pieces.resize(rows * cols)
	pieces.fill(EMPTY)
	pinned = PackedByteArray()
	pinned.resize(rows * cols)
	pinned.fill(0)


func cell_count() -> int:
	return rows * cols


func index_of(row: int, col: int) -> int:
	return row * cols + col


func row_of(cell: int) -> int:
	return cell / cols


func col_of(cell: int) -> int:
	return cell % cols


func has_piece(cell: int) -> bool:
	return cell >= 0 and cell < cell_count() and pieces[cell] != EMPTY


func piece_at(cell: int) -> int:
	if cell < 0 or cell >= cell_count():
		return EMPTY
	return pieces[cell]


func set_piece(cell: int, mask: int) -> void:
	pieces[cell] = mask


## The cell one step from `cell` in `side`, or -1 when that leaves the board.
func neighbour(cell: int, side: int) -> int:
	var step: Vector2i = STEPS[side]
	var row := row_of(cell) + step.y
	var col := col_of(cell) + step.x
	if row < 0 or row >= rows or col < 0 or col >= cols:
		return -1
	return index_of(row, col)


static func turn_cw(mask: int) -> int:
	return ((mask << 1) | (mask >> 3)) & 0xF


static func turn_ccw(mask: int) -> int:
	return ((mask >> 1) | (mask << 3)) & 0xF


static func opening_count(mask: int) -> int:
	var count := 0
	var remaining := mask
	while remaining:
		remaining &= remaining - 1
		count += 1
	return count


func turn(cell: int, clockwise: bool) -> bool:
	if not has_piece(cell) or pinned[cell] != 0:
		return false
	var mask := pieces[cell]
	var turned := turn_cw(mask) if clockwise else turn_ccw(mask)
	if turned == mask:
		return false
	pieces[cell] = turned
	return true


# --- the one thing all three modes agree on ----------------------------------

## Joined means every opening has an opening facing back at it, and nothing
## opens onto the edge of the board. An empty cell is fine -- it is a gap, not
## a loose end (spec 4.1).
func is_joined() -> bool:
	for cell in cell_count():
		var mask := pieces[cell]
		if mask == EMPTY:
			continue
		for side in SIDES:
			if mask & side == 0:
				continue
			var other := neighbour(cell, side)
			if other < 0:
				return false
			var other_mask := pieces[other]
			if other_mask == EMPTY or (other_mask & (OPPOSITE[side] as int)) == 0:
				return false
	return true


func joined_count() -> int:
	var open := 0
	for cell in cell_count():
		var mask := pieces[cell]
		if mask == EMPTY:
			continue
		for side in SIDES:
			if mask & side == 0:
				continue
			var other := neighbour(cell, side)
			if other < 0:
				open += 1
				continue
			var other_mask := pieces[other]
			if other_mask == EMPTY or (other_mask & (OPPOSITE[side] as int)) == 0:
				open += 1
	return open


func piece_count() -> int:
	var count := 0
	for cell in cell_count():
		if pieces[cell] != EMPTY:
			count += 1
	return count


# --- moves the modes borrow --------------------------------------------------

## Turning a piece is one move. Turning it four times is where it started, so
## any shuffle made of these is undone by turning back.
func rotate_random(rng: RandomNumberGenerator, turns: int) -> void:
	for _index in turns:
		var movable: Array[int] = []
		for cell in cell_count():
			if has_piece(cell) and pinned[cell] == 0:
				movable.append(cell)
		if movable.is_empty():
			return
		var pick: int = movable[rng.randi_range(0, movable.size() - 1)]
		turn(pick, rng.randi_range(0, 1) == 0)


## Shifts a whole row sideways or a whole column up or down, wrapping around.
## Wrapping is what makes it reversible: nothing falls off the board, so the
## same shift in the other direction puts it back (spec 5.2).
func shift_line(index: int, horizontal: bool, amount: int) -> bool:
	if amount == 0:
		return false
	# `index` names a row when shifting horizontally and a column otherwise;
	# `line` is how many cells are in the thing being shifted, which is the
	# other dimension's count, not this one.
	var line := cols if horizontal else rows
	var wrapped := ((amount % line) + line) % line
	if wrapped == 0:
		return false
	var saved := PackedInt32Array()
	saved.resize(line)
	for step in line:
		var cell := index_of(index, step) if horizontal else index_of(step, index)
		saved[step] = pieces[cell]
	for step in line:
		var from := (step - wrapped + line) % line
		var cell := index_of(index, step) if horizontal else index_of(step, index)
		pieces[cell] = saved[from]
	return true


## One cell slides into an adjacent gap. This is the only shift the sliding
## mode shuffles with, and the reason is reversibility: after the slide the gap
## is where the piece was, so the same slide in reverse undoes it. Sliding all
## the way to the next obstacle is what the player may do, and is free.
func slide_step(cell: int, direction: int) -> int:
	if not has_piece(cell) or pinned[cell] != 0:
		return -1
	var target := neighbour(cell, direction)
	if target < 0 or pieces[target] != EMPTY:
		return -1
	pieces[target] = pieces[cell]
	pieces[cell] = EMPTY
	return target


## Slides as far as it goes in one direction: the player's move, not the
## shuffler's.
func slide_far(cell: int, direction: int) -> int:
	var current := cell
	var moved := -1
	while true:
		var next := slide_step(current, direction)
		if next < 0:
			break
		current = next
		moved = next
	return moved


func empty_cells() -> Array[int]:
	var out: Array[int] = []
	for cell in cell_count():
		if pieces[cell] == EMPTY:
			out.append(cell)
	return out
