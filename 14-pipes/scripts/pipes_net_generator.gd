class_name PipesNetGenerator
extends RefCounted

## Deals a pipe grid by building a joined one, then wrecking it with the same
## moves the player will have.
##
## That order is the whole reason this game needs no solver (spec 5.1). A
## random spanning tree over the cells is joined by construction -- every edge
## it lays down is two openings facing each other, and a tree has no loose ends
## because every branch ends at a leaf, which is a piece with one opening and
## that opening faces its own edge. Empty cells are simply never visited, so a
## gap is a gap and not a loose end.
##
## Wrecking it with the player's own verb is what keeps it solvable: turning
## four times is turning none, shifting a line wraps around, and sliding a cell
## leaves the gap where the cell was. Every shuffle is undone by doing it
## backwards, so a deal is solvable by construction too.

## How the deal was wrecked -- and therefore what the player is allowed to do
## to fix it. Same three verbs the grid itself knows (spec 5.2).
enum Shuffle { TURN, SHIFT, SLIDE }


## Fills `net` with a wrecked board and returns the answer as one mask per cell
## (or `PipesNet.EMPTY`), which is what `[` draws from.
static func build(rng: RandomNumberGenerator, net: PipesNet, gaps: int,
		shuffle_kind: Shuffle, steps: int, attempts: int = 8) -> PackedInt32Array:
	var total := net.cell_count()
	for _attempt in attempts:
		var blocked := PackedByteArray()
		blocked.resize(total)
		blocked.fill(0)
		var order: Array[int] = []
		for cell in total:
			order.append(cell)
		shuffle(order, rng)
		var want := clampi(gaps, 0, total - 4)
		for step in want:
			blocked[order[step]] = 1

		var solution := _spanning_tree(rng, net, blocked)
		# A gap must not cut the board in two. A second clump of network the
		# walk never reached is not a gap, it is a hole -- and on the sliding
		# boards it is worse than ugly, because a clump walled off by gaps can
		# never be moved. Re-scatter the gaps instead.
		var covered := 0
		for cell in total:
			if solution[cell] != PipesNet.EMPTY:
				covered += 1
		if covered != total - want:
			continue
		net.pieces = solution.duplicate()
		net.pinned.fill(0)
		_shuffle(rng, net, shuffle_kind, steps)
		# A wreck that left the board joined is a level the player has already
		# won. It is rare, but it is free to check for and re-deal.
		if not net.is_joined():
			return solution
	return PackedInt32Array()


## A random spanning tree over every unblocked cell, written out as pipe masks.
## Cells the walk never reaches stay EMPTY, which is what a gap is.
static func _spanning_tree(rng: RandomNumberGenerator, net: PipesNet,
		blocked: PackedByteArray) -> PackedInt32Array:
	var total := net.cell_count()
	var out := PackedInt32Array()
	out.resize(total)
	out.fill(PipesNet.EMPTY)
	var visited := PackedByteArray()
	visited.resize(total)
	visited.fill(0)
	var start := -1
	for cell in total:
		if blocked[cell] == 0:
			start = cell
			break
	if start < 0:
		return out
	visited[start] = 1
	out[start] = 0
	var stack: Array[int] = [start]
	while not stack.is_empty():
		var cell: int = stack[stack.size() - 1]
		var options: Array[int] = []
		for side in PipesNet.SIDES:
			var next := net.neighbour(cell, side)
			if next < 0 or blocked[next] != 0 or visited[next] != 0:
				continue
			options.append(side)
		if options.is_empty():
			stack.pop_back()
			continue
		var side: int = options[rng.randi_range(0, options.size() - 1)]
		var next := net.neighbour(cell, side)
		visited[next] = 1
		out[next] = 0
		out[cell] |= side
		out[next] |= PipesNet.OPPOSITE[side]
		stack.append(next)
	return out


static func shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for index in range(items.size() - 1, 0, -1):
		var swap_with := rng.randi_range(0, index)
		var held: Variant = items[index]
		items[index] = items[swap_with]
		items[swap_with] = held


static func _shuffle(rng: RandomNumberGenerator, net: PipesNet, shuffle_kind: Shuffle,
		steps: int) -> void:
	match shuffle_kind:
		Shuffle.TURN:
			net.rotate_random(rng, steps)
		Shuffle.SHIFT:
			for _index in steps:
				var horizontal := rng.randi_range(0, 1) == 0
				# How many rows (or columns) there are to choose from, and how
				# long the one picked happens to be.
				var lines := net.rows if horizontal else net.cols
				var length := net.cols if horizontal else net.rows
				var amount := rng.randi_range(1, length - 1)
				if rng.randi_range(0, 1) == 1:
					amount = -amount
				net.shift_line(rng.randi_range(0, lines - 1), horizontal, amount)
		Shuffle.SLIDE:
			for _index in steps:
				var movers: Array[int] = []
				for cell in net.cell_count():
					if net.has_piece(cell):
						movers.append(cell)
				if movers.is_empty():
					return
				var cell: int = movers[rng.randi_range(0, movers.size() - 1)]
				var side: int = PipesNet.SIDES[rng.randi_range(0, 3)]
				net.slide_step(cell, side)
