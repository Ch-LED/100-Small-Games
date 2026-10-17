class_name PipesNetGenerator
extends RefCounted

## Deals a pipe grid by building a joined one, then wrecking it with the same
## moves the player will have.
##
## That order is the whole reason this game needs no solver (spec 5.1). A
## random spanning tree over the cells is joined by construction -- every edge
## it lays down is two openings facing each other, and a tree has no loose ends
## because every branch ends at a leaf, which is a piece with one opening and
## that opening faces its own edge.
##
## Colours come later and cheaply: cut `colors - 1` edges out of the tree and it
## falls into that many pieces, each one a colour. Cutting an edge removes both
## openings it made, so two colours that meet across the cut simply do not
## connect -- which is exactly what colour means here.
##
## Wrecking it with the player's own verb is what keeps it solvable: turning
## four times is turning none, shifting a column wraps around, and sliding a
## cell leaves the gap where the cell was. Every shuffle is undone by doing it
## backwards, so a deal is solvable by construction too.
##
## ⚠️ The work array is `Array[int]`, never `PackedInt32Array`. A packed array
## is copied on write, so a helper that edits one is editing its own copy --
## the same trap as DECISION_LOG 097.2, walked into again here.

## How the deal was wrecked -- and therefore what the player is allowed to do
## to fix it.
enum Shuffle { TURN, SHIFT, SLIDE }


## `recipe` says what goes on the board:
##   gaps   -- cells with nothing in them (the sliding mode needs some)
##   blanks -- how many of those gaps hold a pipe-less block instead
##   walls  -- cells that hold a pipe but will not move
##   colors -- how many colours the board is cut into
## Returns the answer as one 8-bit piece mask per cell (or `PipesNet.EMPTY`).
static func build(rng: RandomNumberGenerator, net: PipesNet, recipe: Dictionary,
		shuffle_kind: Shuffle, steps: int, attempts: int = 10) -> PackedInt32Array:
	var total := net.cell_count()
	var gaps := clampi(int(recipe.get("gaps", 0)), 0, total - 4)
	var colors := maxi(1, int(recipe.get("colors", 1)))
	var walls := maxi(0, int(recipe.get("walls", 0)))
	var blanks := clampi(int(recipe.get("blanks", 0)), 0, gaps)

	for _attempt in attempts:
		net.setup(net.rows, net.cols)
		var blocked := _scatter_gaps(rng, total, gaps)
		var masks := _spanning_tree(rng, net, blocked)
		if masks.is_empty():
			continue
		if not _cut_colors(rng, net, masks, blocked, colors):
			continue
		net.pieces = _packed(masks)
		if not _place_walls(rng, net, masks, blocked, walls):
			continue
		_place_blanks(rng, net, blocked, blanks)
		_shuffle(rng, net, shuffle_kind, steps)
		# A wreck that left the board joined is a level the player has already
		# won. It is rare, but it is free to check for and re-deal.
		if not net.is_joined():
			return _packed(masks)
	return PackedInt32Array()


static func _packed(masks: Array[int]) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(masks.size())
	for index in masks.size():
		out[index] = masks[index]
	return out


static func _scatter_gaps(rng: RandomNumberGenerator, total: int, gaps: int) -> PackedByteArray:
	var blocked := PackedByteArray()
	blocked.resize(total)
	blocked.fill(0)
	var order: Array[int] = []
	for cell in total:
		order.append(cell)
	shuffle(order, rng)
	for step in gaps:
		blocked[order[step]] = 1
	return blocked


## A random spanning tree over every unblocked cell, written out as
## single-channel pieces. Cells the walk never reaches stay EMPTY.
static func _spanning_tree(rng: RandomNumberGenerator, net: PipesNet,
		blocked: PackedByteArray) -> Array[int]:
	var total := net.cell_count()
	var out: Array[int] = []
	out.resize(total)
	out.fill(PipesNet.EMPTY)
	var visited := PackedByteArray()
	visited.resize(total)
	visited.fill(0)
	var start := -1
	var wanted := 0
	for cell in total:
		if blocked[cell] == 0:
			wanted += 1
			if start < 0:
				start = cell
	if start < 0:
		return []
	visited[start] = 1
	out[start] = 0
	var covered := 1
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
		covered += 1
	# A gap must not cut the board in two: a second clump the walk never
	# reached is a hole, not a gap -- and on the sliding boards a clump walled
	# off by gaps can never be moved.
	if covered != wanted:
		return []
	return out


## Cuts the tree into `colors` pieces and paints each one.
##
## The cut is done on the tree's own edges, and the openings that edge made go
## with it, so the two sides stop facing each other. A cell left with no
## openings at all is fine -- it becomes a pipe-less block -- but every colour
## must end up with at least two cells, or it is not a colour worth having.
static func _cut_colors(rng: RandomNumberGenerator, net: PipesNet, masks: Array[int],
		blocked: PackedByteArray, colors: int) -> bool:
	var total := net.cell_count()
	var guard := total * 8
	var cut := 0
	while cut < colors - 1 and guard > 0:
		guard -= 1
		var cell := rng.randi_range(0, total - 1)
		if blocked[cell] != 0:
			continue
		var bits := masks[cell] & 0xF
		if bits == 0:
			continue
		var sides: Array[int] = []
		for side in PipesNet.SIDES:
			if bits & side != 0:
				sides.append(side)
		var side: int = sides[rng.randi_range(0, sides.size() - 1)]
		var other := net.neighbour(cell, side)
		masks[cell] &= ~side
		masks[other] &= ~(PipesNet.OPPOSITE[side] as int)
		cut += 1
	if cut < colors - 1:
		return false

	flood_colors(net, masks, blocked)
	if colors == 1:
		_pick_sources(rng, net, 1)
		return _colors_have_bodies(net, 1)
	if not _colors_have_bodies(net, colors):
		return false
	_pick_sources(rng, net, colors)
	return true


## Paints each connected clump of pieces its own colour. Public because the
## assertions want to run it on a hand-built board too.
static func flood_colors(net: PipesNet, masks: Array[int], blocked: PackedByteArray) -> void:
	var total := net.cell_count()
	net.colors.fill(-1)
	net.sources.fill(0)
	var next_color := 0
	for start in total:
		if blocked[start] != 0 or masks[start] == PipesNet.EMPTY:
			continue
		if net.colors[start] >= 0 or (masks[start] & 0xF) == 0:
			continue
		var stack: Array[int] = [start]
		net.colors[start] = next_color
		while not stack.is_empty():
			var cell: int = stack.pop_back()
			for side in PipesNet.SIDES:
				if masks[cell] & side == 0:
					continue
				var other := net.neighbour(cell, side)
				if other < 0 or blocked[other] != 0:
					continue
				if net.colors[other] >= 0 or masks[other] == PipesNet.EMPTY:
					continue
				net.colors[other] = next_color
				stack.append(other)
		next_color += 1


static func _colors_have_bodies(net: PipesNet, colors: int) -> bool:
	var counts := PackedInt32Array()
	counts.resize(colors)
	counts.fill(0)
	for cell in net.cell_count():
		var color := net.colors[cell]
		if color < 0:
			continue
		if color >= colors:
			return false
		counts[color] += 1
	for color in colors:
		if counts[color] < 2:
			return false
	return true


static func _pick_sources(rng: RandomNumberGenerator, net: PipesNet, colors: int) -> void:
	var cells: Array = []
	cells.resize(colors)
	for color in colors:
		cells[color] = []
	for cell in net.cell_count():
		var color := net.colors[cell]
		if color >= 0 and color < colors:
			(cells[color] as Array).append(cell)
	for color in colors:
		var pool: Array = cells[color]
		if not pool.is_empty():
			net.sources[pool[rng.randi_range(0, pool.size() - 1)]] = 1


static func _place_walls(rng: RandomNumberGenerator, net: PipesNet, masks: Array[int],
		blocked: PackedByteArray, walls: int) -> bool:
	var total := net.cell_count()
	var candidates: Array[int] = []
	for cell in total:
		if blocked[cell] == 0 and (masks[cell] & 0xF) != 0:
			candidates.append(cell)
	if candidates.size() < walls:
		return false
	shuffle(candidates, rng)
	for step in walls:
		net.pinned[candidates[step]] = 1
	return true


## The gaps were already empty; some of them get a pipe-less block dropped in,
## which can be pushed around but can never be part of a run.
static func _place_blanks(rng: RandomNumberGenerator, net: PipesNet,
		blocked: PackedByteArray, blanks: int) -> void:
	var holes: Array[int] = []
	for cell in net.cell_count():
		if blocked[cell] != 0:
			holes.append(cell)
	shuffle(holes, rng)
	for step in mini(blanks, holes.size()):
		net.pieces[holes[step]] = PipesNet.BLANK


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
				var amount := rng.randi_range(1, net.rows - 1)
				if rng.randi_range(0, 1) == 1:
					amount = -amount
				net.shift_line(rng.randi_range(0, net.cols - 1), amount)
		Shuffle.SLIDE:
			for _index in steps:
				var movers: Array[int] = []
				for cell in net.cell_count():
					if net.has_piece(cell) and net.pinned[cell] == 0:
						movers.append(cell)
				if movers.is_empty():
					return
				var cell: int = movers[rng.randi_range(0, movers.size() - 1)]
				var side: int = PipesNet.SIDES[rng.randi_range(0, 3)]
				net.slide_step(cell, side)
