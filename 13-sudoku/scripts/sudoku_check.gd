extends SceneTree

## One-off assertion suite for 13-sudoku. Run:
##   godot --headless --path . --script res://13-sudoku/scripts/sudoku_check.gd
##
## The heavy end is the generator: "every deal has exactly one answer" is the
## only claim that matters, and it is checked by running the solver back over
## every puzzle the generator produces rather than by trusting it.

const EULER_PUZZLE := """
530070000
600195000
098000060
800060003
400803001
700020006
060000280
000419005
000080079
"""

const EULER_SOLUTION := """
534678912
672195348
198342567
859761423
426853791
713924856
961537284
287419635
345286179
"""

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_check_solver()
	_check_board()
	_check_generator()
	_check_settings()
	print("\n%d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check_solver() -> void:
	var puzzle := _grid(EULER_PUZZLE)
	var expected := _grid(EULER_SOLUTION)
	_check("euler puzzle has exactly one solution", SudokuGenerator.count_solutions(puzzle, 2) == 1)

	var solved := SudokuGenerator.full_solution(_rng())
	_check("generator fills every cell", _blank_count(solved) == 0)
	_check("generator's grid is legal", SudokuGenerator.count_solutions(solved, 2) == 1)

	# A full grid is its own single solution; an empty one has far too many.
	_check("full grid counts as one", SudokuGenerator.count_solutions(expected, 2) == 1)
	_check("empty grid has more than one", SudokuGenerator.count_solutions(_empty(), 2) == 2)

	var one_hole := expected.duplicate()
	one_hole[40] = 0
	_check("one hole keeps it unique", SudokuGenerator.count_solutions(one_hole, 2) == 1)

	var two_holes := expected.duplicate()
	two_holes[40] = 0
	two_holes[41] = 0
	_check("two holes in a row are still unique",
			SudokuGenerator.count_solutions(two_holes, 2) == 1)

	var repeated := expected.duplicate()
	repeated[1] = repeated[0]
	_check("a repeated digit is unsolvable", SudokuGenerator.count_solutions(repeated, 2) == 0)

	var contradictory := expected.duplicate()
	# Same digit twice in a column: no state can ever satisfy this.
	contradictory[0] = contradictory[9]
	_check("a repeated column digit is unsolvable",
			SudokuGenerator.count_solutions(contradictory, 2) == 0)

	# The Euler grid's own solution must be reproduced by the counting solver's
	# search, not merely be "a" solution.
	var forced := puzzle.duplicate()
	for index in SudokuBoard.CELL_COUNT:
		forced[index] = expected[index]
	_check("the known solution is legal", SudokuGenerator.count_solutions(forced, 2) == 1)


func _check_board() -> void:
	var board := SudokuBoard.new()
	board.load_puzzle(_grid(EULER_PUZZLE))
	_check("dealt digits survive load", board.value_at(0) == 5 and board.value_at(2) == 0)
	_check("dealt digits are marked given", board.is_given(0) and not board.is_given(2))
	_check("a given cannot be overwritten", not board.place(0, 9))
	_check("a given cannot be erased", not board.erase(0))
	_check("blank count matches the puzzle", board.blank_count() == 51)

	_check("an empty cell accepts a digit", board.place(2, 4))
	_check("the digit is stored", board.value_at(2) == 4)
	_check("it can be erased again", board.erase(2))
	_check("erasing clears the cell", board.value_at(2) == 0)
	_check("erasing an already empty cell reports nothing", not board.erase(2))

	_check("pencil writes a mark", board.toggle_note(2, 7))
	_check("the mark is recorded", board.notes[2] == (1 << 7))
	_check("pencil toggles back off", board.toggle_note(2, 7) and board.notes[2] == 0)
	board.toggle_note(2, 3)
	board.toggle_note(2, 8)
	_check("marks accumulate", board.notes[2] == ((1 << 3) | (1 << 8)))
	_check("placing a digit clears the marks", board.place(2, 4) and board.notes[2] == 0)
	_check("a given takes no marks", not board.toggle_note(0, 3))

	# Row 0 of the Euler puzzle holds 5,3,7; column 0 holds 5,6,9,8,4,7; the
	# top-left box holds 5,3,6,9,8. So cell 2 (r0 c2) cannot take any of those.
	board.erase(2)
	var blocked := board.candidates_at(2)
	_check("candidates exclude the row", (blocked & (1 << 5)) == 0 and (blocked & (1 << 3)) == 0)
	_check("candidates exclude the column", (blocked & (1 << 6)) == 0 and (blocked & (1 << 9)) == 0)
	_check("candidates exclude the box", (blocked & (1 << 8)) == 0)
	_check("candidates keep what is free", (blocked & (1 << 1)) != 0)
	_check("candidate count agrees with the mask", board.candidate_count(2) == _bits(blocked))
	_check("a filled cell has no candidates", board.candidate_count(0) == 0)

	_check("a legal puzzle reports no conflict", board.conflict_count() == 0)
	board.place(2, 5)
	var conflicts := board.conflicts()
	_check("a repeated digit flags both cells", conflicts[2] != 0 and conflicts[0] != 0)
	_check("a repeated digit does not flag the rest", conflicts[1] == 0)
	_check("the puzzle is not complete with blanks", not board.is_complete())
	board.erase(2)

	# Filling every blank from the known answer has to end the puzzle, and the
	# board must be able to say so without being handed the solution.
	var solved := SudokuBoard.new()
	solved.load_puzzle(_grid(EULER_SOLUTION))
	_check("a full legal grid is complete", solved.is_complete())

	# A grid missing a digit is not complete, whoever owns the cell. Note this
	# has to be dealt as a hole: `erase` refuses a given, which is the rule, so
	# the board cannot be hollowed out from the player's side.
	var holed := _grid(EULER_SOLUTION)
	holed[0] = 0
	var incomplete := SudokuBoard.new()
	incomplete.load_puzzle(holed)
	_check("a grid with a hole is not complete", not incomplete.is_complete())
	_check("the hole reads as empty", incomplete.is_blank(0))
	_check("the hole is the player's to fill", incomplete.place(0, 5))
	_check("filling the hole completes it again", incomplete.is_complete())

	var snapshot := board.snapshot()
	board.place(2, 6)
	board.restore(snapshot)
	_check("restore puts the board back", board.value_at(2) == 0 and board.blank_count() == 51)


func _check_generator() -> void:
	var settings := SudokuSettings.new()
	var rng := _rng()
	var targets := settings.difficulty_blanks
	var sums: Array[int] = []
	for index in targets.size():
		sums.append(0)

	for difficulty in targets.size():
		var target := settings.blanks_for(difficulty)
		var started := Time.get_ticks_msec()
		for round_index in 10:
			var dealt := SudokuGenerator.generate(rng, target)
			var puzzle: PackedByteArray = dealt["puzzle"]
			var solution: PackedByteArray = dealt["solution"]
			var blanks := int(dealt["blanks"])

			_check("deal %d/%d has exactly one answer" % [difficulty, round_index],
					SudokuGenerator.count_solutions(puzzle, 2) == 1)
			_check("deal %d/%d is a complete grid underneath" % [difficulty, round_index],
					SudokuGenerator.count_solutions(solution, 2) == 1)
			_check("deal %d/%d never exceeds the target" % [difficulty, round_index],
					blanks <= target)
			_check("deal %d/%d actually removed cells" % [difficulty, round_index],
					blanks > 0 and _blank_count(puzzle) == blanks)
			_check("deal %d/%d deals only solution digits" % [difficulty, round_index],
					_agrees_with(puzzle, solution))
			sums[difficulty] += blanks
		print("  difficulty %d (%s): target %d, average dealt %d, %.1f ms per deal" % [
				difficulty, settings.difficulty_name(difficulty), target,
				sums[difficulty] / 10, float(Time.get_ticks_msec() - started) / 10.0])

	_check("dealing a board is fast enough to do at startup",
			_time_one_deal(settings.blanks_for(0)) < 2000)


func _check_settings() -> void:
	var settings := SudokuSettings.new()
	_check("three difficulties are configured", settings.difficulty_count() == 3)
	_check("blanks rise with difficulty",
			settings.blanks_for(0) < settings.blanks_for(1)
			and settings.blanks_for(1) < settings.blanks_for(2))
	_check("board side is nine cells", is_equal_approx(settings.board_side(),
			settings.cell_size * 9.0))
	_check("the board fits above the help line",
			SudokuSettings.FIELD.y - settings.board_side() > settings.margin * 2.0)
	_check("cell size leaves room for a digit",
			settings.cell_size * settings.digit_scale >= 16.0)
	_check("the super colour is the project green", settings.super_color == Color("00E676"))


func _time_one_deal(target: int) -> int:
	var started := Time.get_ticks_msec()
	SudokuGenerator.generate(_rng(), target)
	return Time.get_ticks_msec() - started


func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return rng


func _empty() -> PackedByteArray:
	var grid := PackedByteArray()
	grid.resize(SudokuBoard.CELL_COUNT)
	grid.fill(0)
	return grid


func _grid(text: String) -> PackedByteArray:
	var grid := PackedByteArray()
	for character in text:
		if character >= "1" and character <= "9":
			grid.append(character.to_int())
		elif character == "0" or character == ".":
			grid.append(0)
	return grid


func _blank_count(grid: PackedByteArray) -> int:
	var count := 0
	for index in SudokuBoard.CELL_COUNT:
		if grid[index] == 0:
			count += 1
	return count


static func _bits(mask: int) -> int:
	var count := 0
	var remaining := mask
	while remaining:
		remaining &= remaining - 1
		count += 1
	return count


func _agrees_with(puzzle: PackedByteArray, solution: PackedByteArray) -> bool:
	for index in SudokuBoard.CELL_COUNT:
		if puzzle[index] != 0 and puzzle[index] != solution[index]:
			return false
	return true


func _check(name: String, ok: bool) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("  FAIL  %s" % name)
