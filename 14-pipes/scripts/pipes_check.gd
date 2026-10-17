extends SceneTree

## Assertion suite for 14-pipes. Run:
##   godot --headless --path . --script res://14-pipes/scripts/pipes_check.gd
##
## The generator is checked on its own terms first -- if a deal is not a legal
## board, nothing the level says about it means anything.

var _passed := 0
var _failed := 0


func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_check_generator(rng)
	_check_level(rng)
	_check_solving(rng)
	_check_net(rng)
	_check_net_generator(rng)
	_check_shift_solvable(rng)
	_check_save()
	print("\n%d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


## The shift mode is only fair if every deal can be undone, and what makes that
## true is that the shuffle is a run of the player's own move -- replaying it
## backwards is a solution. This walks the claim rather than trusting it.
##
## It is worth walking because the first version got it wrong: it shuffled rows
## as well as columns, and no amount of column dragging could undo a row shift,
## so deals came out unsolvable (DECISION_LOG 102).
func _check_shift_solvable(rng: RandomNumberGenerator) -> void:
	var net := PipesNet.new()
	net.setup(6, 6)
	PipesNetGenerator.build(rng, net, {"colors": 1}, PipesNetGenerator.Shuffle.SHIFT, 0)
	_check("an unshuffled board is joined", net.is_joined())

	var moves: Array = []
	for _index in 24:
		var column := rng.randi_range(0, net.cols - 1)
		var amount := rng.randi_range(1, net.rows - 1)
		if rng.randi_range(0, 1) == 1:
			amount = -amount
		if net.shift_line(column, amount):
			moves.append([column, amount])
	_check("a column shuffle un-solves the board", not net.is_joined())
	_check("the shuffle actually moved something", not moves.is_empty())

	for step in range(moves.size() - 1, -1, -1):
		var move: Array = moves[step]
		net.shift_line(move[0], -move[1])
	_check("replaying the shuffle backwards joins it again", net.is_joined())


## Records are per mode and per level, and the level can be one that has never
## been reached -- which is exactly the case that used to take the whole run
## down, because an untyped Array pads with null and `int(null)` is not a thing
## (DECISION_LOG 101).
func _check_save() -> void:
	var save := PipesSave.new()
	root.add_child(save)
	save.reset(PipesModes.LINK)
	save.reset(PipesModes.TURN)
	_check("a fresh save has no record", save.best_for(PipesModes.LINK, 0) == 0)
	_check("a fresh save is at level one", save.next_level(PipesModes.LINK) == 0)

	_check("a first finish is a record", save.record(PipesModes.LINK, 3, 5000))
	_check("the time is stored", save.best_for(PipesModes.LINK, 3) == 5000)
	_check("progress moved past the level cleared", save.next_level(PipesModes.LINK) == 4)
	# Level 0 has no time yet, so even a slow one is a record the first time.
	_check("a first finish at level zero is a record", save.record(PipesModes.LINK, 0, 9000))
	_check("a slower run at the same level is not", not save.record(PipesModes.LINK, 0, 9500))
	_check("the slow time is what stuck", save.best_for(PipesModes.LINK, 0) == 9000)
	_check("a faster run is", save.record(PipesModes.LINK, 0, 1000))
	_check("the faster time replaced the old one", save.best_for(PipesModes.LINK, 0) == 1000)
	_check("clearing a level already cleared does not move progress",
			save.next_level(PipesModes.LINK) == 4)

	# A level far past anything reached: the slots in between factor in as
	# "never finished" rather than blowing up.
	_check("recording a level past the end works", save.record(PipesModes.SLIDE, 9, 7000))
	_check("the far record is stored", save.best_for(PipesModes.SLIDE, 9) == 7000)
	_check("the levels it skipped read as unplayed", save.best_for(PipesModes.SLIDE, 4) == 0)
	_check("it advanced progress to the end", save.next_level(PipesModes.SLIDE) == 10)

	_check("modes keep separate records", save.best_for(PipesModes.TURN, 0) == 0)
	_check("modes keep separate progress", save.next_level(PipesModes.TURN) == 0)
	_check("a mode with no record reads zero", save.best_for(PipesModes.SHIFT, 2) == 0)
	save.queue_free()


## The three modes that share PipesNet: turning, shifting a line, sliding into
## a gap. What is checked here is that each verb is undoable, because that is
## exactly what makes the generator's shuffle reversible and every deal
## solvable (spec 5).
func _check_net(_rng: RandomNumberGenerator) -> void:
	var straight := PipesNet.NORTH | PipesNet.SOUTH
	_check("turning four times is turning none",
			PipesNet.turn_cw(PipesNet.turn_cw(PipesNet.turn_cw(PipesNet.turn_cw(straight))))
					== straight)
	_check("turning back undoes a turn",
			PipesNet.turn_ccw(PipesNet.turn_cw(straight)) == straight)
	_check("a run turned twice is a run again",
			PipesNet.turn_cw(PipesNet.turn_cw(straight)) == straight)
	_check("an elbow keeps its two openings",
			PipesNet.opening_count(PipesNet.turn_cw(PipesNet.NORTH | PipesNet.EAST)) == 2)

	var net := PipesNet.new()
	net.setup(3, 3)
	net.set_piece(4, straight)
	_check("a piece turns", net.turn(4, true))
	_check("the turned piece is sideways", net.piece_at(4) == (PipesNet.EAST | PipesNet.WEST))
	_check("turning back restores it", net.turn(4, false) and net.piece_at(4) == straight)
	net.pinned[4] = 1
	_check("a pinned piece will not turn", not net.turn(4, true))
	net.pinned[4] = 0

	# Joining: two openings that face each other are joined; anything else is a
	# loose end, including an opening that faces the edge of the board.
	var joined := PipesNet.new()
	joined.setup(2, 2)
	joined.set_piece(0, PipesNet.EAST)
	joined.set_piece(1, PipesNet.WEST)
	_check("two pieces facing each other are joined", joined.is_joined())
	joined.set_piece(1, PipesNet.NORTH)
	_check("an opening facing a shut side is loose", not joined.is_joined())
	joined.set_piece(1, PipesNet.WEST)
	joined.set_piece(0, PipesNet.WEST)
	_check("an opening onto the edge is loose", not joined.is_joined())
	# A gap is not itself a loose end -- only an opening left facing one is.
	var gap_net := PipesNet.new()
	gap_net.setup(1, 3)
	gap_net.set_piece(0, PipesNet.EAST)
	gap_net.set_piece(1, PipesNet.WEST | PipesNet.EAST)
	gap_net.set_piece(2, PipesNet.WEST)
	_check("a full line of pipes is joined", gap_net.is_joined())
	gap_net.set_piece(1, PipesNet.EMPTY)
	_check("taking a middle piece out leaves two loose ends", not gap_net.is_joined())

	# Shifting a column wraps rather than dropping anything, which is what
	# makes it reversible. Column 1 holds 1,4,7; shifting it two down brings
	# 4 and 7 to the top and wraps 1 to the bottom.
	var shift := PipesNet.new()
	shift.setup(3, 3)
	for cell in 9:
		shift.set_piece(cell, cell)
	var snapshot := shift.pieces.duplicate()
	shift.shift_line(1, 2)
	_check("a shift moves the whole column",
			shift.piece_at(shift.index_of(0, 1)) == 4
			and shift.piece_at(shift.index_of(1, 1)) == 7
			and shift.piece_at(shift.index_of(2, 1)) == 1)
	_check("nothing falls off a shifted column", shift.piece_count() == 9)
	_check("shifting back restores it", shift.shift_line(1, -2)
			and shift.pieces == snapshot)
	_check("shifting a whole column length is no shift",
			not shift.shift_line(1, 3) and shift.pieces == snapshot)
	# A wall holds its place; a column that shifted around one would tear it.
	shift.pinned[shift.index_of(1, 1)] = 1
	_check("a column with a wall refuses to shift", not shift.shift_line(1, 1))
	shift.pinned[shift.index_of(1, 1)] = 0

	# Colour is a property of the floor, so two runs of different colours that
	# touch do not join even when their openings line up.
	var two := PipesNet.new()
	two.setup(1, 2)
	two.set_piece(0, PipesNet.EAST)
	two.set_piece(1, PipesNet.WEST)
	two.colors[0] = 0
	two.colors[1] = 1
	_check("two colours facing each other do not join", not two.is_joined())
	two.colors[1] = 0
	_check("the same colour facing itself joins", two.is_joined())
	two.set_piece(1, PipesNet.BLANK)
	_check("a pipe facing a pipe-less block is loose", not two.is_joined())

	# An overpass carries two channels that never meet, and both turn together.
	var overpass := PipesNet.NORTH | PipesNet.SOUTH \
			| (PipesNet.EAST << 4) | (PipesNet.WEST << 4)
	_check("an overpass has four openings", PipesNet.opening_count(overpass) == 4)
	_check("an overpass is recognised", PipesNet.is_overpass(overpass))
	_check("both channels turn with the piece",
			PipesNet.turn_cw(overpass) == (PipesNet.EAST | PipesNet.WEST
			| (PipesNet.SOUTH << 4) | (PipesNet.NORTH << 4)))
	_check("a plain piece is not an overpass", not PipesNet.is_overpass(PipesNet.NORTH))

	# Sliding: one step in, one step back. Sliding far is the player's move.
	var slide := PipesNet.new()
	slide.setup(1, 3)
	slide.set_piece(0, PipesNet.EAST)
	_check("a piece slides into the gap", slide.slide_step(0, PipesNet.EAST) == 1)
	_check("the gap is where the piece was", slide.piece_at(0) == PipesNet.EMPTY)
	_check("sliding back restores it", slide.slide_step(1, PipesNet.WEST) == 0)
	slide.set_piece(2, PipesNet.WEST)
	_check("a piece will not slide into another", slide.slide_step(1, PipesNet.EAST) == -1)
	_check("a piece will not slide off the board", slide.slide_step(0, PipesNet.WEST) == -1)
	var far := PipesNet.new()
	far.setup(1, 5)
	far.set_piece(0, PipesNet.EAST)
	_check("sliding far goes as far as it can", far.slide_far(0, PipesNet.EAST) == 4)


## Every deal is built joined and then wrecked with the player's own verb, so
## the two things to prove are that the answer really is joined, and that the
## wreck really did wreck it.
func _check_net_generator(rng: RandomNumberGenerator) -> void:
	var kinds := [PipesNetGenerator.Shuffle.TURN, PipesNetGenerator.Shuffle.SHIFT,
			PipesNetGenerator.Shuffle.SLIDE]
	for kind in kinds:
		var dealt := 0
		var spent := 0
		for _index in 8:
			var net := PipesNet.new()
			net.setup(6, 6)
			# A sliding board needs somewhere to slide to or the wreck move
			# does nothing and the deal comes out already solved.
			var recipe := {"gaps": 0, "blanks": 0, "walls": 0, "colors": 1}
			if kind == PipesNetGenerator.Shuffle.SLIDE:
				recipe = {"gaps": 5, "blanks": 2, "walls": 1, "colors": 1}
			var started := Time.get_ticks_msec()
			var solution := PipesNetGenerator.build(rng, net, recipe, kind, 40)
			spent += Time.get_ticks_msec() - started
			if solution.is_empty():
				continue
			dealt += 1
			var answer := PipesNet.new()
			answer.setup(net.rows, net.cols)
			answer.pieces = solution.duplicate()
			answer.colors = net.colors.duplicate()
			answer.pinned = net.pinned.duplicate()
			_check("mode %d: the answer is joined" % kind, answer.is_joined())
			_check("mode %d: the deal is not already solved" % kind, not net.is_joined())
			# Every cell holds something except the gaps -- and a pipe-less
			# block is something, so the blanks come back out of the count.
			_check("mode %d: the board holds what the recipe asked for" % kind,
					net.piece_count() == net.cell_count() - int(recipe["gaps"])
					+ int(recipe["blanks"]))
		print("  shuffle %d: %d/8 dealt, %.1f ms each" % [kind, dealt, float(spent) / 8.0])
		_check("mode %d deals every time" % kind, dealt == 8)


func _check_generator(rng: RandomNumberGenerator) -> void:
	for size in [5, 7, 9]:
		var side: int = size
		var pairs := side - 1
		var ok := 0
		var started := Time.get_ticks_msec()
		for _index in 10:
			var dealt := PipesGenerator.generate(rng, side, side, pairs, 3, side * 2)
			if dealt.is_empty():
				continue
			ok += 1
			_check("%dx%d deal covers every cell once" % [side, side],
					_validate(dealt) == "")
			_check("%dx%d deal has a sane colour count" % [side, side],
					(dealt["paths"] as Array).size() >= 2)
		var each := float(Time.get_ticks_msec() - started) / 10.0
		print("  %dx%d: %d/10 dealt, %.1f ms each" % [side, side, ok, each])
		_check("%dx%d deals every time" % [side, side], ok == 10)
		_check("%dx%d deals quickly" % [side, side], each < 40.0)


## Empty when the deal is a legal board: every cell covered exactly once,
## every path a chain of touching cells, none of them a stub.
func _validate(dealt: Dictionary) -> String:
	var rows := int(dealt["rows"])
	var cols := int(dealt["cols"])
	var paths: Array = dealt["paths"]
	if paths.size() < 2:
		return "too few colours"
	var owner := PackedInt32Array()
	owner.resize(rows * cols)
	owner.fill(-1)
	for id in paths.size():
		var path: PackedInt32Array = paths[id]
		if path.size() < 3:
			return "stub"
		for step in path.size():
			var cell := path[step]
			if owner[cell] != -1:
				return "overlap"
			owner[cell] = id
			if step > 0:
				var previous := path[step - 1]
				var gap := absi(previous - cell)
				var same_row := previous / cols == cell / cols and gap == 1
				if gap != cols and not same_row:
					return "gap"
	for index in owner.size():
		if owner[index] == -1:
			return "hole"
	return ""


func _check_level(rng: RandomNumberGenerator) -> void:
	var level := _make_level(rng, 5, 5)
	_check("a fresh board is empty", level.covered_count() == 0)
	_check("a fresh board is unsolved", not level.is_solved())
	_check("no colour starts done", level.done_count() == 0)

	var color := 0
	var chain := level.solution[color]
	var end_a := chain[0]
	var end_b := chain[chain.size() - 1]
	var middle := chain[1]

	_check("a stroke cannot start in the middle", not level.begin_stroke(color, middle))
	_check("a stroke cannot start on another colour's end", not level.begin_stroke(color + 1, end_a))
	_check("a stroke starts on its own end", level.begin_stroke(color, end_a))
	_check("the stroke is live", level.is_stroking())
	_check("the first cell is covered", level.covers(end_a, color))

	# Straight along the answer, which is the one route known to be legal.
	var length := _walk_chain(level, chain, false)
	_check("the whole answer can be drawn", length == chain.size())
	_check("reaching the far end finishes the colour", level.is_color_done(color))
	_check("finished colours are counted", level.done_count() == 1)
	level.end_stroke()
	_check("letting go ends the stroke", not level.is_stroking())

	# Trimming: dragging back over your own line shortens it. Walked by index,
	# not by a fixed count -- the shortest colour a deal may contain is three
	# cells, so assuming room for four would test the deal rather than the rule.
	var steps := mini(4, chain.size() - 1)
	_check("redrawing from the end works", level.begin_stroke(color, end_a))
	for step in range(1, steps + 1):
		level.extend_stroke(chain[step], false)
	_check("the line came back to the expected length",
			(level.drawn[color] as Array).size() == steps + 1)
	level.extend_stroke(chain[1], false)
	_check("dragging back over the line trims it", (level.drawn[color] as Array).size() == 2)
	_check("the trimmed cells are released", not level.covers(chain[2], color))
	level.end_stroke()
	_check("a two-cell line survives letting go", (level.drawn[color] as Array).size() == 2)
	level.clear_color(color)
	_check("clearing empties the colour", (level.drawn[color] as Array).size() == 0)
	_check("clearing releases the cells", not level.covers(end_a, color))

	# Walls, on a board built for the purpose. A dealt board is no good here:
	# cutting a grid into touching runs tends to leave ends facing ends, and
	# ends are barred to everyone, so a deal cannot show what a crossing is.
	var crossing := _crossing_board()
	_check("the crossing board starts its first colour", crossing.begin_stroke(0, 0))
	crossing.extend_stroke(1, false)
	crossing.extend_stroke(2, false)
	crossing.end_stroke()
	_check("the crossing board starts its second colour", crossing.begin_stroke(1, 3))
	_walk_chain(crossing, crossing.solution[1], false)
	crossing.end_stroke()
	_check("the target is covered by the other colour",
			crossing.covers(5, 1) and crossing.color_at(5) == 1)
	_check("the target is not a dot", not crossing.is_any_endpoint(5))
	_check("hanging on to it", crossing.can_undo())

	crossing.begin_stroke(0, 0)
	crossing.extend_stroke(1, false)
	crossing.extend_stroke(2, false)
	_check("a line may not run over another colour", not crossing.extend_stroke(5, false))
	_check("the cheat lets a line be laid over another", crossing.extend_stroke(5, true))
	_check("the crossed cell belongs to both", crossing.covers(5, 0) and crossing.covers(5, 1))
	_check("a crossed cell reads as a crossing", crossing.is_crossing(5))
	_check("a plain cell still reads as one colour", crossing.color_at(1) == 0)
	_check("even the cheat may not run over a dot", not crossing.extend_stroke(6, true))
	crossing.end_stroke()

	level.clear_all()
	_check("clear all empties the board", level.covered_count() == 0)

	# Undo has to put back exactly what was there.
	var other := color + 1
	var other_chain := level.solution[other]
	_check("undo with nothing to undo says so", not level.undo())
	_check("drawing again", level.begin_stroke(color, end_a))
	_walk_chain(level, level.solution[color], false)
	level.end_stroke()
	_check("the second colour is drawn", level.begin_stroke(other, other_chain[0]))
	level.end_stroke()
	_check("undo is available", level.can_undo())
	_check("undo runs", level.undo())
	_check("undo removed the second colour", (level.drawn[other] as Array).size() == 0)
	_check("undo kept the first", (level.drawn[color] as Array).size() > 1)


func _check_solving(rng: RandomNumberGenerator) -> void:
	for size in [5, 6, 7]:
		var level := _make_level(rng, size, size)
		_check("%dx%d starts unsolved" % [size, size], not level.is_solved())
		for color in level.color_count:
			level.begin_stroke(color, level.solution[color][0])
			_walk_chain(level, level.solution[color], false)
			level.end_stroke()
		_check("%dx%d solves when the answer is drawn" % [size, size], level.is_solved())
		_check("%dx%d covers every cell" % [size, size], level.covered_count() == size * size)
		# Taking one colour back off has to unsolve it, both ways: the colour is
		# no longer joined, and a cell goes uncovered.
		level.clear_color(0)
		_check("%dx%d unsolves when a colour is cleared" % [size, size], not level.is_solved())


## Draws `chain` from wherever the live stroke is, and reports how many cells it
## managed to add -- a short count means the rules stopped it.
func _walk_chain(level: PipesLevel, chain: PackedInt32Array, bridges: bool) -> int:
	for step in range(1, chain.size()):
		if not level.extend_stroke(chain[step], bridges):
			return step
	return chain.size()


## One colour's end sits directly beside the middle of another colour, which is
## the arrangement the crossing rule exists for. A dealt board cannot show this:
## cutting a grid into touching runs tends to leave ends facing ends, and ends
## are barred to everyone.
func _crossing_board() -> PipesLevel:
	var level := PipesLevel.new()
	level.setup({
		"rows": 3,
		"cols": 3,
		"paths": [
			PackedInt32Array([0, 1, 2]),
			PackedInt32Array([3, 4, 5, 8, 7, 6]),
		],
	})
	return level


func _make_level(rng: RandomNumberGenerator, rows: int, cols: int) -> PipesLevel:
	var level := PipesLevel.new()
	var dealt := PipesGenerator.generate(rng, rows, cols, rows - 1, 3, rows * 2)
	if dealt.is_empty():
		_check("could not deal a %dx%d board" % [rows, cols], false)
		return level
	level.setup(dealt)
	return level


func _check(name: String, ok: bool) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("  FAIL  %s" % name)
