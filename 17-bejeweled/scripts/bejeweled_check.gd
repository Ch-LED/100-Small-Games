extends SceneTree

## Assertion suite for 17-bejeweled. Run:
##   godot --headless --path . --script res://17-bejeweled/scripts/bejeweled_check.gd
##
## Two claims matter more than the rest, and both are about cards being dealt
## fairly: the opening board must not already match, and it must have a move.
## Everything else follows from those.

var _passed := 0
var _failed := 0


func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_check_deal(rng)
	_check_matching()
	_check_swaps()
	_check_gravity(rng)
	_check_moves()
	_check_specials(rng)
	_check_config()
	print("\n%d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check_deal(rng: RandomNumberGenerator) -> void:
	for attempt in 8:
		var board := _blank(8, 8, 6)
		_check("deal %d succeeds" % attempt, board.deal(rng))
		_check("deal %d fills every cell" % attempt, _empty_count(board) == 0)
		_check("deal %d opens without a match" % attempt, board.matched_cells().is_empty())
		_check("deal %d leaves a move" % attempt, board.has_move())

	# Many deals in a row: the guarantee has to hold every time, not usually.
	var clean := true
	var playable := true
	for _attempt in 40:
		var board := _blank(8, 8, 6)
		board.deal(rng)
		if not board.matched_cells().is_empty():
			clean = false
		if not board.has_move():
			playable = false
	_check("forty deals in a row all open clean", clean)
	_check("forty deals in a row all have a move", playable)


func _check_matching() -> void:
	var three := _blank(1, 5, 0)
	three.cells = PackedInt32Array([1, 1, 1, 2, 3])
	_check("a run of three matches", three.matched_cells().size() == 3)
	var two := _blank(1, 5, 0)
	two.cells = PackedInt32Array([1, 1, 2, 3, 4])
	_check("a run of two does not match", two.matched_cells().is_empty())
	var four := _blank(1, 6, 0)
	four.cells = PackedInt32Array([1, 1, 1, 1, 2, 3])
	_check("a run of four matches four", four.matched_cells().size() == 4)
	var five := _blank(1, 6, 0)
	five.cells = PackedInt32Array([1, 1, 1, 1, 1, 2])
	_check("a run of five matches five", five.matched_cells().size() == 5)

	var vertical := _blank(4, 3, 0)
	vertical.cells = PackedInt32Array([
		1, 2, 3,
		1, 4, 5,
		1, 6, 0,
		2, 3, 4,
	])
	_check("a vertical run matches", vertical.matched_cells().size() == 3)

	# An L: the crossing cell belongs to both a row and a column, and is
	# reported once.
	var cross := _blank(3, 3, 0)
	cross.cells = PackedInt32Array([
		1, 1, 1,
		1, 2, 3,
		1, 4, 5,
	])
	_check("a crossing counts its shared cell once", cross.matched_cells().size() == 5)

	var gap := _blank(1, 5, 0)
	gap.cells = PackedInt32Array([1, 1, 2, 1, 1])
	_check("a broken run does not match", gap.matched_cells().is_empty())

	var blank_cells := _blank(1, 3, 0)
	blank_cells.cells = PackedInt32Array([-1, -1, -1])
	_check("empty cells do not match each other", blank_cells.matched_cells().is_empty())


func _check_swaps() -> void:
	var board := _blank(3, 3, 6)
	# Column 0 is 0,1,1 -- quiet. Swapping the two gems in row 0 makes it 1,1,1.
	board.cells = PackedInt32Array([
		0, 1, 2,
		1, 4, 5,
		1, 1, 7,
	])
	_check("the board is quiet before the swap", board.matched_cells().is_empty())
	_check("swapping makes a match", board.swap_makes_match(board.index_of(0, 0),
			board.index_of(0, 1)))
	_check("the check does not disturb the board",
			board.gem_at(board.index_of(0, 0)) == 0 and board.gem_at(board.index_of(0, 1)) == 1)

	var no := _blank(2, 2, 6)
	no.cells = PackedInt32Array([0, 1, 2, 3])
	_check("a swap that makes nothing is detected", not no.swap_makes_match(0, 1))

	var adjacent := _blank(3, 3, 6)
	_check("side by side is adjacent", adjacent.are_adjacent(0, 1))
	_check("above and below is adjacent", adjacent.are_adjacent(0, 3))
	_check("diagonal is not adjacent", not adjacent.are_adjacent(0, 4))
	_check("the same cell is not adjacent", not adjacent.are_adjacent(0, 0))

	var any := _blank(2, 2, 6)
	any.cells = PackedInt32Array([0, 1, 2, 3])
	any.swap(0, 3)
	_check("a distant swap is allowed by the board",
			any.gem_at(0) == 3 and any.gem_at(3) == 0)


func _check_gravity(rng: RandomNumberGenerator) -> void:
	var board := _blank(4, 1, 4)
	board.cells = PackedInt32Array([0, -1, 2, -1])
	board.apply_gravity(rng)
	_check("gems fall to the bottom", board.gem_at(3) == 2 and board.gem_at(2) == 0)
	_check("the top is refilled", not board.is_empty(0) and not board.is_empty(1))
	_check("nothing is left empty", _empty_count(board) == 0)

	var full := _blank(3, 2, 4)
	full.cells = PackedInt32Array([0, 1, 2, 3, 0, 1])
	var moved := full.apply_gravity(rng)
	_check("a full board falls nowhere", moved == 0)

	# The view slides each gem the distance it actually fell, so the board has
	# to say where every gem came from and which cells were refilled.
	var drop := _blank(4, 1, 4)
	drop.cells = PackedInt32Array([0, -1, 2, -1])
	drop.apply_gravity(rng)
	_check("the fall records both moved gems", drop.last_moves.size() == 2)
	_check("the fall records the two refills", drop.last_spawns.size() == 2)
	_check("every move ends where the gem now is",
			drop.gem_at((drop.last_moves[0] as Vector2i).y) >= 0
			and drop.gem_at((drop.last_moves[1] as Vector2i).y) >= 0)

	var cleared := _blank(2, 2, 4)
	cleared.cells = PackedInt32Array([0, 1, 2, 3])
	cleared.clear([0, 3])
	_check("clearing empties the cells", cleared.is_empty(0) and cleared.is_empty(3))
	_check("clearing leaves the rest", cleared.gem_at(1) == 1 and cleared.gem_at(2) == 2)


func _check_moves() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var board := _blank(8, 8, 6)
	board.deal(rng)
	var move := board.find_move()
	_check("a dealt board has a move to point at", move.size() == 2)
	if move.size() == 2:
		_check("the pointed move really makes a match",
				board.swap_makes_match(move[0], move[1]))
		_check("the pointed move is between touching gems",
				board.are_adjacent(move[0], move[1]))

	# A two-by-two board cannot hold a line of three at all, so no swap can
	# ever score on it -- the simplest board that really has no move.
	var stuck := _blank(2, 2, 6)
	stuck.cells = PackedInt32Array([0, 1, 2, 3])
	_check("a 2x2 board has no legal swap", not stuck.has_move())
	_check("a board with no legal swap points at nothing", stuck.find_move().is_empty())
	_check("has_move and find_move agree", board.has_move() == (board.find_move().size() == 2))


## Charges: a run of four leaves a bomb, five leaves a lightning, and a charge
## caught in another charge's blast goes off too (DECISION_LOG 109).
func _check_specials(rng: RandomNumberGenerator) -> void:
	var four := _blank(1, 5, 6)
	four.cells = PackedInt32Array([0, 0, 0, 0, 1])
	var rewards := four.pending_rewards()
	_check("a run of four earns a charge", rewards.size() == 1)
	_check("four earns a bomb",
			not rewards.is_empty()
			and int(rewards[0]["special"]) == BejeweledBoard.Special.BOMB)

	var five := _blank(1, 6, 6)
	five.cells = PackedInt32Array([0, 0, 0, 0, 0, 1])
	var big := five.pending_rewards()
	_check("five earns the bigger charge", not big.is_empty()
			and int(big[0]["special"]) == BejeweledBoard.Special.LIGHTNING)

	var three := _blank(1, 4, 6)
	three.cells = PackedInt32Array([0, 0, 0, 1])
	_check("a run of three earns nothing", three.pending_rewards().is_empty())

	var bomb := _blank(5, 5, 6)
	bomb.set_special(12, BejeweledBoard.Special.BOMB)
	_check("a bomb takes nine cells", bomb.expand_specials([12]).size() == 9)

	var bolt := _blank(5, 5, 6)
	bolt.set_special(12, BejeweledBoard.Special.LIGHTNING)
	_check("a lightning takes its row and column", bolt.expand_specials([12]).size() == 9)

	var chained := _blank(5, 5, 6)
	chained.set_special(12, BejeweledBoard.Special.BOMB)
	chained.set_special(13, BejeweledBoard.Special.BOMB)
	_check("a charge caught in a blast goes off too",
			chained.expand_specials([12]).size() > 9)

	var plain := _blank(3, 3, 6)
	_check("a quiet gem takes only itself", plain.expand_specials([4]).size() == 1)

	# A charge rides down with its gem and never rides into a fresh one.
	var falling := _blank(3, 1, 6)
	falling.set_gem(0, 2)
	falling.set_special(0, BejeweledBoard.Special.BOMB)
	falling.apply_gravity(rng)
	_check("a charge falls with its gem",
			falling.special[2] == BejeweledBoard.Special.BOMB)
	_check("a fresh gem carries no charge",
			falling.special[0] == BejeweledBoard.Special.NONE
			and falling.special[1] == BejeweledBoard.Special.NONE)
	falling.clear([2])
	_check("clearing takes the charge with it",
			falling.special[2] == BejeweledBoard.Special.NONE)


func _check_config() -> void:
	var settings := BejeweledSettings.new()
	_check("the board is square and even", settings.rows == settings.cols)
	_check("there are kinds to play with", settings.kinds >= 4)
	_check("the round has a length", settings.round_seconds > 0)
	_check("every kind has a colour", settings.gem_colors.size() >= settings.kinds)
	_check("the board fits the field",
			settings.cols * settings.cell_size <= BejeweledSettings.FIELD.x
			and settings.rows * settings.cell_size <= BejeweledSettings.FIELD.y - 140.0)


func _blank(rows: int, cols: int, kinds: int) -> BejeweledBoard:
	var board := BejeweledBoard.new()
	board.setup(rows, cols, maxi(3, kinds))
	return board


func _empty_count(board: BejeweledBoard) -> int:
	var count := 0
	for cell in board.cell_count():
		if board.is_empty(cell):
			count += 1
	return count


func _check(name: String, ok: bool) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("  FAIL  %s" % name)
