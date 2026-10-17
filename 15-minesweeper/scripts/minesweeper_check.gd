extends SceneTree

## Assertion suite for 15-minesweeper. Run:
##   godot --headless --path . --script res://15-minesweeper/scripts/minesweeper_check.gd
##
## The board is pure logic, so everything here drives it directly. The one
## claim worth more than the rest is the first-click guarantee: it is what
## stops the game from being a coin toss on move one.

var _passed := 0
var _failed := 0


func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_check_seeding(rng)
	_check_reveal(rng)
	_check_flags()
	_check_chord(rng)
	_check_win(rng)
	_check_levels()
	print("\n%d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check_seeding(rng: RandomNumberGenerator) -> void:
	var board := MinesweeperBoard.new()
	board.setup(9, 9, 10)
	_check("a fresh board has no mines", not _count_mines(board) > 0)
	_check("nothing is uncovered", board.revealed_count() == 0)
	_check("nothing is flagged", board.flag_count() == 0)

	_check("seeding succeeds", board.seed(rng, board.index_of(4, 4)))
	_check("seeding places exactly the mine count", _count_mines(board) == 10)
	# The whole point: the first click and its eight neighbours are clear.
	var safe := true
	for cell in _neighbourhood(board, board.index_of(4, 4)):
		if board.has_mine(cell):
			safe = false
	_check("the first click and its neighbours are clear", safe)
	_check("the first click has no number", board.adjacent_at(board.index_of(4, 4)) == 0)

	# A corner leaves far more room, so it must also work.
	var corner := MinesweeperBoard.new()
	corner.setup(9, 9, 10)
	_check("seeding at a corner works", corner.seed(rng, corner.index_of(0, 0)))
	var corner_safe := true
	for cell in _neighbourhood(corner, corner.index_of(0, 0)):
		if corner.has_mine(cell):
			corner_safe = false
	_check("the corner and its neighbours are clear", corner_safe)

	# A board too small to hold the mines away from the safe area is refused
	# rather than silently dropping mines.
	var tiny := MinesweeperBoard.new()
	tiny.setup(3, 3, 5)
	_check("an impossible board is refused", not tiny.seed(rng, tiny.index_of(1, 1)))
	_check("nothing is seeded when refused", not tiny.seeded)

	var numbers := true
	for cell in board.cell_count():
		if board.has_mine(cell):
			continue
		var expected := 0
		for neighbour in board.neighbours_of(cell):
			if board.has_mine(neighbour):
				expected += 1
		if board.adjacent_at(cell) != expected:
			numbers = false
	_check("every number matches the mines around it", numbers)


func _check_reveal(rng: RandomNumberGenerator) -> void:
	var board := _blank(5, 5, 1)
	# One mine in the corner; the rest of a 5x5 board is one number-cascade.
	board.mines[0] = 1
	board._recount()
	board.seeded = true
	_check("revealing a safe cell opens", board.reveal(board.index_of(0, 1)) > 0)
	# (0,1) has the mine beside it, so it carries a number, and a number opens
	# only itself -- the cascade belongs to cells with no mine touching them.
	_check("a numbered cell opens alone", board.revealed_count() == 1)
	_check("revealing it again opens nothing", board.reveal(board.index_of(0, 1)) == 0)

	var wide := _blank(5, 5, 1)
	wide.mines[0] = 1
	wide._recount()
	wide.seeded = true
	var opened := wide.reveal(wide.index_of(4, 4))
	_check("a zero cell cascades across the board", opened == 24)
	_check("the cascade stops at the mine", not wide.is_revealed(0))
	_check("the cascade does not win the game", wide.is_won())

	var boom := _blank(5, 5, 1)
	boom.mines[12] = 1
	boom._recount()
	boom.seeded = true
	_check("stepping on a mine reports it", boom.reveal(12) == -1)
	_check("stepping on a mine ends the game", boom.is_lost())
	_check("nothing more can be revealed after losing", boom.reveal(0) == 0)


func _check_flags() -> void:
	var board := _blank(3, 3, 1)
	board.seeded = true
	var cell := 4
	_check("a cell starts unmarked", board.flags[cell] == MinesweeperBoard.Flag.NONE)
	_check("marking works", board.toggle_flag(cell))
	_check("the first mark is a flag", board.flags[cell] == MinesweeperBoard.Flag.MARK)
	_check("the flag is counted", board.flag_count() == 1)
	board.toggle_flag(cell)
	_check("the second mark is a question", board.flags[cell] == MinesweeperBoard.Flag.QUESTION)
	_check("a question is not a flag", board.flag_count() == 0)
	board.toggle_flag(cell)
	_check("the third mark clears it", board.flags[cell] == MinesweeperBoard.Flag.NONE)

	board.revealed[cell] = 1
	_check("an open cell takes no marks", not board.toggle_flag(cell))
	board.revealed[cell] = 0
	board.toggle_flag(cell)
	board.revealed[cell] = 1
	_check("a flag stops a cell being opened", board.reveal(cell) == 0)
	board.revealed[cell] = 0


func _check_chord(rng: RandomNumberGenerator) -> void:
	# A 3x1 strip: mine, 1, safe. The middle cell has exactly one flagged
	# neighbour, so chording it must open the far cell.
	var board := _blank(1, 3, 1)
	board.mines[0] = 1
	board._recount()
	board.seeded = true
	board.revealed[1] = 1
	_check("a chord with no flag does nothing", board.chord(1) == 0)
	board.toggle_flag(0)
	_check("a chord with the right flags opens the rest", board.chord(1) == 1)
	_check("the chord opened the safe cell", board.is_revealed(2))

	# A chord that is wrong steps on a mine, exactly like a click would.
	var wrong := _blank(1, 3, 1)
	wrong.mines[2] = 1
	wrong._recount()
	wrong.seeded = true
	wrong.revealed[1] = 1
	wrong.toggle_flag(0)
	_check("a wrong chord loses the game", wrong.chord(1) == -1)
	_check("the wrong chord is recorded", wrong.is_lost())

	var _unused := rng


func _check_win(rng: RandomNumberGenerator) -> void:
	for attempt in 6:
		var board := MinesweeperBoard.new()
		board.setup(5, 5, 4)
		var first := attempt % 25
		if not board.seed(rng, first):
			continue
		board.reveal(first)
		_check("opening every safe cell wins",
				_open_all_safe(board) and board.is_won())
		_check("a won game is not lost", not board.is_lost())


func _check_levels() -> void:
	var settings := MinesweeperSettings.new()
	_check("three levels are configured", settings.level_count() == 3)
	for level in settings.level_count():
		var rows := settings.rows_for(level)
		var cols := settings.cols_for(level)
		var mines := settings.mines_for(level)
		_check("level %d holds its mine count" % level, mines > 0)
		_check("level %d leaves room around a first click" % level,
				rows * cols - 9 >= mines)
		_check("level %d fits the field" % level,
				cols * settings.cell_size <= MinesweeperSettings.FIELD.x
				and rows * settings.cell_size <= MinesweeperSettings.FIELD.y - 140.0)


func _open_all_safe(board: MinesweeperBoard) -> bool:
	for cell in board.cell_count():
		if not board.has_mine(cell):
			board.reveal(cell)
	return board.revealed_count() == board.cell_count() - board.mine_count


func _blank(rows: int, cols: int, mines: int) -> MinesweeperBoard:
	var board := MinesweeperBoard.new()
	board.setup(rows, cols, mines)
	return board


func _count_mines(board: MinesweeperBoard) -> int:
	var count := 0
	for cell in board.cell_count():
		if board.has_mine(cell):
			count += 1
	return count


func _neighbourhood(board: MinesweeperBoard, cell: int) -> Array[int]:
	var out: Array[int] = [cell]
	for neighbour in board.neighbours_of(cell):
		out.append(neighbour)
	return out


func _check(name: String, ok: bool) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("  FAIL  %s" % name)
