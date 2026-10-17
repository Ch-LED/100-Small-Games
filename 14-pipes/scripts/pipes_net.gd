class_name PipesNet
extends RefCounted

## A grid of pipe pieces, where a piece is a mask of the sides it opens onto.
##
## This one class serves three of the four modes -- turning, shifting a whole
## column, sliding a piece into a gap. What separates them is only what the
## player may do to the grid and how a deal was shuffled, never what the grid is
## or what "joined" means.
##
## A piece is **eight bits**, not four: the low nibble is one channel's
## openings, the high nibble is a second channel's. An ordinary piece uses only
## the low nibble; an overpass uses both, and the two channels do not meet --
## which is the whole point of an overpass (spec 4.2).
##
## Bit per side: north 1, east 2, south 4, west 8.
##
## Colour belongs to the **cell**, not to the piece. That matters: pieces move
## when the player slides them, and if colour moved with them a wrecked board
## would be unsolvable by construction -- the colours would have scattered.
## With colour pinned to the floor, every deal stays solvable for exactly the
## reason it did before (spec 4.3).

const NORTH := 1
const EAST := 2
const SOUTH := 4
const WEST := 8
const SIDES := [NORTH, EAST, SOUTH, WEST]
const OPPOSITE := {NORTH: SOUTH, EAST: WEST, SOUTH: NORTH, WEST: EAST}
const STEPS := {NORTH: Vector2i(0, -1), EAST: Vector2i(1, 0),
		SOUTH: Vector2i(0, 1), WEST: Vector2i(-1, 0)}

const EMPTY := -1
## A piece with no openings at all: a block that fills the cell but carries no
## pipe. Movable like any other piece; it just cannot be part of a run.
const BLANK := 0

var rows := 5
var cols := 5
## One 8-bit piece per cell, or EMPTY.
var pieces := PackedInt32Array()
## Which colour this cell belongs to. Colour is a property of the floor.
var colors := PackedInt32Array()
## One cell per colour is marked as that colour's source.
var sources := PackedByteArray()
## A pinned cell is a wall: it holds a piece but will not move, and nothing
## slides through it.
var pinned := PackedByteArray()


func setup(rows_in: int, cols_in: int) -> void:
	rows = rows_in
	cols = cols_in
	pieces = PackedInt32Array()
	pieces.resize(rows * cols)
	pieces.fill(EMPTY)
	colors = PackedInt32Array()
	colors.resize(rows * cols)
	colors.fill(0)
	sources = PackedByteArray()
	sources.resize(rows * cols)
	sources.fill(0)
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


# --- piece geometry ----------------------------------------------------------

static func channel_a(mask: int) -> int:
	return mask & 0xF


static func channel_b(mask: int) -> int:
	return (mask >> 4) & 0xF


## Every side the piece opens onto, whichever channel it belongs to.
static func openings(mask: int) -> int:
	return (mask | (mask >> 4)) & 0xF


static func is_overpass(mask: int) -> bool:
	return channel_b(mask) != 0


static func opening_count(mask: int) -> int:
	return _popcount(openings(mask))


static func turn_cw(mask: int) -> int:
	return _rot_cw(channel_a(mask)) | (_rot_cw(channel_b(mask)) << 4)


static func turn_ccw(mask: int) -> int:
	return _rot_ccw(channel_a(mask)) | (_rot_ccw(channel_b(mask)) << 4)


static func _rot_cw(bits: int) -> int:
	return ((bits << 1) | (bits >> 3)) & 0xF


static func _rot_ccw(bits: int) -> int:
	return ((bits >> 1) | (bits << 3)) & 0xF


static func _popcount(bits: int) -> int:
	var count := 0
	var remaining := bits & 0xF
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

## Joined means every opening has an opening facing back at it, **in the same
## colour**, and nothing opens onto the edge of the board.
##
## Colour is checked here rather than at the source, because it is what makes
## two runs side by side stay two runs. An empty cell is fine -- it is a gap,
## not a loose end; so is a cell with no openings at all.
func is_joined() -> bool:
	var loose := loose_openings()
	return loose == 0 and has_pipe()


func loose_openings() -> int:
	var loose := 0
	for cell in cell_count():
		var mask := pieces[cell]
		if mask == EMPTY:
			continue
		var bits := openings(mask)
		for side in SIDES:
			if bits & side == 0:
				continue
			var other := neighbour(cell, side)
			if other < 0 or not _fits(cell, side, other):
				loose += 1
	return loose


func _fits(cell: int, side: int, other: int) -> bool:
	var other_mask := pieces[other]
	if other_mask == EMPTY:
		return false
	if colors[other] != colors[cell]:
		return false
	if openings(other_mask) & (OPPOSITE[side] as int) == 0:
		return false
	# Two channels meeting means they have to be the same channel: an overpass
	# does not connect its two halves, and neither does it connect across.
	return _shared_channel(pieces[cell], side, other_mask, OPPOSITE[side] as int)


static func _shared_channel(first: int, first_side: int, second: int,
		second_side: int) -> bool:
	if (channel_a(first) & first_side) != 0:
		if (channel_a(second) & second_side) != 0:
			return true
	if (channel_b(first) & first_side) != 0:
		if (channel_b(second) & second_side) != 0:
			return true
	return false


## Does the piece at `cell` on `side` face something that faces back?
func mouth_fits(cell: int, side: int) -> bool:
	var other := neighbour(cell, side)
	return other >= 0 and _fits(cell, side, other)


## True when every opening on this piece faces something. A piece with one
## loose opening stays dark, which is what makes a lit pipe mean a joined one.
func piece_is_joined(cell: int) -> bool:
	var mask := pieces[cell]
	if mask == EMPTY:
		return false
	var bits := openings(mask)
	if bits == 0:
		return false
	for side in SIDES:
		if bits & side != 0 and not mouth_fits(cell, side):
			return false
	return true


func color_count() -> int:
	var highest := -1
	for cell in cell_count():
		if colors[cell] > highest:
			highest = colors[cell]
	return highest + 1


func has_pipe() -> bool:
	for cell in cell_count():
		if pieces[cell] != EMPTY and openings(pieces[cell]) != 0:
			return true
	return false


func piece_count() -> int:
	var count := 0
	for cell in cell_count():
		if pieces[cell] != EMPTY:
			count += 1
	return count


func pipe_count() -> int:
	var count := 0
	for cell in cell_count():
		if pieces[cell] != EMPTY and openings(pieces[cell]) != 0:
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
		if openings(pieces[pick]) != 0:
			turn(pick, rng.randi_range(0, 1) == 0)


## Shifts a whole column up or down, wrapping around. Wrapping is what makes it
## reversible: nothing falls off the board, so the same shift the other way puts
## it back (spec 5.2).
##
## Refused outright when the column holds a wall -- a wall that moved would not
## be a wall, and a column that shifted around one would tear it in half.
func shift_line(column: int, amount: int) -> bool:
	if column < 0 or column >= cols or amount == 0:
		return false
	var wrapped := ((amount % rows) + rows) % rows
	if wrapped == 0:
		return false
	for row in rows:
		if pinned[index_of(row, column)] != 0:
			return false
	var saved := PackedInt32Array()
	saved.resize(rows)
	for row in rows:
		saved[row] = pieces[index_of(row, column)]
	for row in rows:
		pieces[index_of(row, column)] = saved[(row - wrapped + rows) % rows]
	return true


## One cell slides into an adjacent gap. This is the only shift the sliding
## mode shuffles with, and the reason is reversibility: after the slide the gap
## is where the piece was, so the same slide in reverse undoes it. Sliding all
## the way to the next obstacle is what the player may do, and is free.
func slide_step(cell: int, direction: int) -> int:
	if not has_piece(cell) or pinned[cell] != 0:
		return -1
	var target := neighbour(cell, direction)
	if target < 0 or pieces[target] != EMPTY or pinned[target] != 0:
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
