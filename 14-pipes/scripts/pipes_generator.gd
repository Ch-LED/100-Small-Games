class_name PipesGenerator
extends RefCounted

## Splits a grid into non-overlapping paths that together cover every cell.
##
## The paths *are* the answer: each one becomes a colour whose two ends are the
## dots the player has to join. So a deal is solvable by construction and can
## always be filled completely -- there is nothing to search for, which is the
## whole reason this game is cheaper to build than 13-sudoku (spec 5).
##
## The shape is grow-by-merging, and it is worth saying why it is not a walk.
## A walk that lays down one path at a time strands cells it can no longer
## reach, and a Hamiltonian walk has to backtrack enough that a 7x7 grid never
## finished. Neither problem exists here: every cell starts as its own path of
## one, and each step welds two touching paths into one. Covering the grid is
## the starting state, not a goal to reach, so there is nothing to fail at --
## the only question is how far the count comes down (spec 5.1).


## How many failed welds in a row mean the merge has stalled for good.
const STALL_LIMIT := 300


## Returns `{rows, cols, paths}` where `paths` is one PackedInt32Array of cell
## indices per colour, or an empty dictionary when the deal came out ragged.
##
## Merging stops as soon as `pairs` colours are left; it can stall above that,
## in which case the deal is simply accepted with more colours than asked for,
## and rejected only if a colour ended up shorter than `min_length` or longer
## than `max_length`.
static func generate(rng: RandomNumberGenerator, rows: int, cols: int, pairs: int,
		min_length: int, max_length: int, attempts: int = 12) -> Dictionary:
	var total := rows * cols
	if pairs < 1 or min_length < 2 or max_length < min_length:
		return {}
	if pairs * min_length > total:
		return {}
	for _attempt in attempts:
		var dealt := _merge_down(rng, rows, cols, pairs, min_length, max_length)
		if dealt.is_empty():
			continue
		var paths: Array = dealt["paths"]
		if paths.size() < 2:
			continue
		var shortest := 1 << 30
		for path in paths:
			shortest = mini(shortest, (path as PackedInt32Array).size())
		if shortest < min_length:
			continue
		return dealt
	return {}


static func _merge_down(rng: RandomNumberGenerator, rows: int, cols: int, pairs: int,
		min_length: int, max_length: int) -> Dictionary:
	var total := rows * cols
	var owner := PackedInt32Array()
	owner.resize(total)
	var paths: Array = []
	for index in total:
		owner[index] = index
		paths.append([index] as Array[int])
	var alive := total
	# Merging can stall above the colour count -- some arrangement of what is
	# left has no two paths touching end to end. When it does, the deal is
	# taken as it stands rather than spun on; a run of failures is the signal,
	# not a fixed budget, because a stalled merge fails forever.
	var stalls := 0
	while alive > pairs and stalls < STALL_LIMIT:
		var index := _pick_path(paths, rng, min_length)
		if index < 0:
			break
		if _absorb(index, paths, owner, rows, cols, max_length, rng):
			alive -= 1
			stalls = 0
		else:
			stalls += 1
	var result: Array[PackedInt32Array] = []
	for entry in paths:
		if entry == null:
			continue
		var packed := PackedInt32Array()
		for cell in entry:
			packed.append(cell)
		result.append(packed)
	if result.size() < 2:
		return {}
	return {"rows": rows, "cols": cols, "paths": result}


## Welds the path at `index` onto any touching path it can, and reports whether
## it managed one. A weld that would close the path into a ring is refused --
## a ring has no ends, and ends are the whole point of a colour.
##
## Both ends and their neighbours are visited in random order. With a fixed
## order the merge grows in whichever direction the loop happens to start, and
## every colour comes out a straight stripe -- which reads as a solved board
## rather than a puzzle (spec 5.1).
static func _absorb(index: int, paths: Array, owner: PackedInt32Array, rows: int, cols: int,
		max_length: int, rng: RandomNumberGenerator) -> bool:
	var path: Array = paths[index]
	var ends: Array[int] = [path[0], path[path.size() - 1]]
	if rng.randi_range(0, 1) == 1:
		ends.reverse()
	for end in ends:
		var neighbours := _neighbours(end, rows, cols)
		shuffle(neighbours, rng)
		for neighbour in neighbours:
			var other_index := owner[neighbour]
			if other_index == index:
				continue
			var other: Array = paths[other_index]
			if other == null:
				continue
			var welded := _weld(path, other, cols)
			if welded.is_empty() or welded.size() > max_length:
				continue
			if welded.size() > 2 and _touching(welded[0], welded[welded.size() - 1], cols):
				continue
			paths[index] = welded
			paths[other_index] = null
			for cell in other:
				owner[cell] = index
			return true
	return false


static func shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for index in range(items.size() - 1, 0, -1):
		var swap_with := rng.randi_range(0, index)
		var held: Variant = items[index]
		items[index] = items[swap_with]
		items[swap_with] = held


## Lines the two ends up and joins them, or returns an empty array when no end
## of one touches an end of the other.
static func _weld(first: Array, second: Array, cols: int) -> Array:
	var first_head: int = first[0]
	var first_tail: int = first[first.size() - 1]
	var second_head: int = second[0]
	var second_tail: int = second[second.size() - 1]
	if _touching(first_tail, second_head, cols):
		return first + second
	if _touching(first_tail, second_tail, cols):
		return first + _reversed(second)
	if _touching(first_head, second_head, cols):
		return _reversed(first) + second
	if _touching(first_head, second_tail, cols):
		return second + first
	return []


static func _reversed(items: Array) -> Array:
	var copy := items.duplicate()
	copy.reverse()
	return copy


static func _touching(first: int, second: int, cols: int) -> bool:
	var gap := absi(first - second)
	if gap == cols:
		return true
	return gap == 1 and first / cols == second / cols


static func _neighbours(cell: int, rows: int, cols: int) -> Array[int]:
	var out: Array[int] = []
	var row := cell / cols
	var col := cell % cols
	if row > 0:
		out.append(cell - cols)
	if row < rows - 1:
		out.append(cell + cols)
	if col > 0:
		out.append(cell - 1)
	if col < cols - 1:
		out.append(cell + 1)
	return out


## Which path to grow next: random most of the time, but a path already shorter
## than a colour is allowed to be jumps the queue.
##
## Always taking the shortest kept every colour even and every board striped;
## always taking a random one left a fifth of the 5x5 deals with a stub too
## short to be a puzzle. Rescuing only when it is needed is the middle and gets
## both -- the shapes stay ragged because the choice is usually free.
static func _pick_path(paths: Array, rng: RandomNumberGenerator, min_length: int) -> int:
	var shortest := 1 << 30
	var stubs: Array[int] = []
	var alive: Array[int] = []
	for index in paths.size():
		var entry: Variant = paths[index]
		if entry == null:
			continue
		alive.append(index)
		var length: int = (entry as Array).size()
		if length < shortest:
			shortest = length
			stubs = [index]
		elif length == shortest:
			stubs.append(index)
	if alive.is_empty():
		return -1
	var pool := stubs if shortest < min_length else alive
	return pool[rng.randi_range(0, pool.size() - 1)]
