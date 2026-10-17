extends SceneTree

## Assertion suite for 16-sokoban. Run:
##   godot --headless --path . --script res://16-sokoban/scripts/sokoban_check.gd
##
## The part that earns its keep is the last one: every shipped level is handed
## to the solver and must come back with an answer. A Sokoban level that cannot
## be finished looks exactly like one that can until someone tries -- and by
## then it is shipped.

const LEVEL_DIR := "res://16-sokoban/levels/"

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_check_parsing()
	_check_moves()
	_check_undo()
	_check_stuck()
	_check_levels()
	print("\n%d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check_parsing() -> void:
	var level := _level("#####\n#@$.#\n#####\n")
	_check("a level parses", level != null)
	if level == null:
		return
	_check("the walls are walls", level.is_wall(level.index_of(0, 0)))
	_check("the player is found", level.player == level.index_of(1, 1))
	_check("the box is found", level.box_count() == 1)
	_check("the goal is found", level.is_goal(level.index_of(1, 3)))
	var both := _level("#####\n#@* #\n#####\n")
	_check("a box on a goal counts for both",
			both != null and both.box_count() == 1 and both.is_goal(both.index_of(1, 2)))
	var standing := _level("#####\n#+$ #\n#####\n")
	_check("a player on a goal counts for both",
			standing != null and standing.is_goal(standing.player))

	_check("a board with no player is refused",
			_level("#####\n# $.#\n#####\n") == null)
	_check("a board with no box is refused",
			_level("#####\n#@ .#\n#####\n") == null)
	_check("a board with more boxes than goals is refused",
			_level("#####\n#@$$.#\n#####\n") == null)
	_check("ragged rows are acceptable",
			_level("#####\n#@$.#\n###\n") != null)


func _check_moves() -> void:
	var level := _level("#######\n#@ $ .#\n#######\n")
	_check("walking into a wall does nothing",
			level.move(Vector2i(0, -1)) == 0 and level.moves == 0)
	_check("walking onto floor works", level.move(Vector2i(1, 0)) == 1)
	_check("the player moved", level.player == level.index_of(1, 2))
	_check("pushing a box works", level.move(Vector2i(1, 0)) == 2)
	_check("the box moved with the player",
			level.has_box(level.index_of(1, 4)) and not level.has_box(level.index_of(1, 3)))
	_check("the push is counted", level.pushes == 1 and level.moves == 2)

	var blocked := _level("#######\n#@$$..#\n#######\n")
	_check("the box-train board parses", blocked != null)
	_check("a box cannot push another box", blocked.move(Vector2i(1, 0)) == 0)
	# A board needs a goal for every box, so even the small rule tests carry
	# one -- the parser refuses anything else, which is the point.
	var corner := _level("####\n#@$#\n# .#\n####\n")
	_check("the wall-corner board parses", corner != null)
	_check("a box cannot be pushed into a wall", corner.move(Vector2i(1, 0)) == 0)
	_check("the board is unchanged after a refused push",
			corner.player == corner.index_of(1, 1) and corner.moves == 0)

	var win := _level("#####\n#@$.#\n#####\n")
	_check("the board starts unfinished", not win.is_won())
	win.move(Vector2i(1, 0))
	_check("a box on every goal wins", win.is_won())
	_check("boxes on goals are counted", win.boxes_on_goals() == 1)

	# The `[` cheat: the player walks away and drags the box behind.
	var pull := _level("#######\n#@$ . #\n#######\n")
	pull.move(Vector2i(1, 0))
	_check("a pull needs the player beside a box", pull.pull(Vector2i(-1, 0)) == 2)
	_check("the player stepped away", pull.player == pull.index_of(1, 1))
	# The box ends up in the cell the player just left, not where it started:
	# it is dragged along, one cell per step.
	_check("the box followed the player", pull.has_box(pull.index_of(1, 2)))
	_check("the box is no longer where it was pushed to",
			not pull.has_box(pull.index_of(1, 3)))


func _check_undo() -> void:
	var level := _level("#######\n#@ $ .#\n#######\n")
	_check("nothing to undo on a fresh board", not level.can_undo())
	level.move(Vector2i(1, 0))
	level.move(Vector2i(1, 0))
	var pushed := level.pushes
	_check("undo is available after a move", level.can_undo())
	_check("undo runs", level.undo())
	_check("undo put the box back", not level.has_box(level.index_of(1, 4))
			and level.has_box(level.index_of(1, 3)))
	_check("undo put the push count back", level.pushes == pushed - 1)
	_check("undo put the player back", level.player == level.index_of(1, 2))
	# Two moves were made, so two undos exhaust it.
	_check("undo runs out", level.undo() and not level.can_undo())
	_check("undoing everything restores the start", level.player == level.start_player
			and level.moves == 0)


func _check_stuck() -> void:
	# A box with a wall above it and a wall beside it can never move again.
	var corner := _level("####\n#@$#\n# .#\n####\n")
	_check("the corner board parses", corner != null)
	_check("a box in a wall corner is stuck", corner.stuck_boxes() == 1)
	var on_goal := _level("#####\n#@* #\n#####\n")
	_check("the on-goal board parses", on_goal != null)
	_check("a box on a goal is never called stuck", on_goal.stuck_boxes() == 0)


## Every shipped level: it parses, and the solver can finish it.
func _check_levels() -> void:
	var directory := DirAccess.open(LEVEL_DIR)
	_check("the level folder opens", directory != null)
	if directory == null:
		return
	var names: Array[String] = []
	for name in directory.get_files():
		if name.ends_with(".txt"):
			names.append(name)
	names.sort()
	_check("there are levels to play", not names.is_empty())

	var previous := 0
	for name in names:
		var text := FileAccess.get_file_as_string(LEVEL_DIR + name)
		var level := SokobanLevel.new()
		_check("%s parses" % name, level.load_from_text(text))
		if level.player < 0:
			continue
		var started := Time.get_ticks_msec()
		var solution := SokobanSolver.solve(level)
		var spent := Time.get_ticks_msec() - started
		_check("%s can be finished" % name, solution > 0)
		print("  %s: %d boxes, %dx%d, shortest %d moves, %d ms" % [name,
				level.box_count(), level.cols, level.rows, solution, spent])
		if solution > 0:
			previous = maxi(previous, solution)


func _level(text: String) -> SokobanLevel:
	var level := SokobanLevel.new()
	if not level.load_from_text(text):
		return null
	return level


func _check(name: String, ok: bool) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("  FAIL  %s" % name)
