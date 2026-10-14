class_name TutorialLevels
extends RefCounted

## The five lessons, hardest thing last.
##
## Every lesson is a hand-built position plus a fixed deal order. The order has
## to be fixed: a lesson that waited on the 7-bag would sometimes never deal
## the piece it is teaching.
##
## `rows` are spelled top-down and pinned to the FLOOR, so a one-row lesson
## still sits on row 23 where the player expects it. '#' is filled, '.' is not.
##
## ⚠️ A position row must never be COMPLETE. `clear_lines()` does not care that
## a row was hand-written, so a full row in a lesson is cleared the moment the
## player locks anything -- and the lesson silently stops being winnable. Every
## lesson here keeps at least one hole in every row, and the assertion suite
## checks it.
##
## `demo` is the run-through shown before play starts: one step per move, each
## a ghost of where the piece ends up plus the key that does it. The last step
## doubles as the SOLUTION -- a lock anywhere else is a miss, and the lesson
## restarts.

enum Goal {
	CLEAR_LINE,
	TETRIS,
	T_SPIN,
	HOLD_CLEAR,
	COMBO,
}


static func all() -> Array[Dictionary]:
	return [
		{
			"title": "1 / 5    CLEAR A LINE",
			"hint": "Fill the bottom row.",
			"done": "A full row disappears. That is the whole game.",
			"rows": ["########.."],
			"pieces": [Tetromino.Kind.O],
			"goal": Goal.CLEAR_LINE,
			"demo": [
				_step(Tetromino.Kind.O, 0, Vector2i(8, 22), "SPACE"),
			],
		},
		{
			"title": "2 / 5    TETRIS",
			"hint": "Stand it up, then drop it down the gap.",
			"done": "Four rows at once is worth EIGHT times one row, not four.",
			"rows": [
				"#########.",
				"#########.",
				"#########.",
				"#########.",
			],
			"pieces": [Tetromino.Kind.I],
			"goal": Goal.TETRIS,
			"demo": [
				_step(Tetromino.Kind.I, 1, Vector2i(7, 6), "X"),
				_step(Tetromino.Kind.I, 1, Vector2i(7, 20), "SPACE"),
			],
		},
		{
			# The notch, from the shape the user drew: three rows of four,
			# 1100 / 1000 / 1101. Its gaps read as a T-shaped pocket, and the
			# only way in is upright-then-turn: a flat T is three wide and the
			# opening is two.
			#
			# ⚠️ Getting here took a while -- see 技术规格书 §16.7. The short of
			# it: a T-spin position can NEVER be reached by dropping, because
			# the two upper corners of the box always sit in the falling
			# piece's path. It only ever happens through a turn at the bottom.
			"title": "3 / 5    T-SPIN",
			"hint": "Turn it upright, slide it left, let it down, then turn again.",
			"done": "That last turn is a T-spin: turning into a slot pays far more than dropping in.",
			"rows": [
				"##..######",
				"#...######",
				"##.#######",
			],
			"pieces": [Tetromino.Kind.T],
			"goal": Goal.T_SPIN,
			"demo": [
				_step(Tetromino.Kind.T, 1, Vector2i(1, 21), "X, then LEFT twice"),
				_step(Tetromino.Kind.T, 2, Vector2i(1, 21), "X"),
			],
		},
		{
			"title": "4 / 5    HOLD",
			"hint": "The piece in hand cannot fill this gap. Swap it.",
			"done": "Hold swaps what you have for what you saved. Once per piece.",
			"rows": ["######...."],
			"pieces": [Tetromino.Kind.O],
			"hold": Tetromino.Kind.I,
			"goal": Goal.HOLD_CLEAR,
			"demo": [
				_step(Tetromino.Kind.I, 0, Vector2i(6, 22), "C"),
			],
		},
		{
			"title": "5 / 5    COMBO",
			"hint": "Fill a row, then fill the next one straight away.",
			"done": "Clearing again without a gap in between pays a combo bonus on top.",
			"rows": [
				"######....",
				"######....",
			],
			"pieces": [Tetromino.Kind.I, Tetromino.Kind.I],
			"goal": Goal.COMBO,
			"demo": [
				_step(Tetromino.Kind.I, 0, Vector2i(6, 22), "SPACE"),
				_step(Tetromino.Kind.I, 0, Vector2i(6, 22), "SPACE again"),
			],
		},
	]


static func count() -> int:
	return all().size()


## The cells the last demonstration step puts the piece on: where a correct
## attempt has to land.
static func solution_cells(level: Dictionary) -> Array[Vector2i]:
	var demo: Array = level.get("demo", [])
	if demo.is_empty():
		return []
	return _step_cells(demo[demo.size() - 1])


static func step_cells(step: Dictionary) -> Array[Vector2i]:
	return _step_cells(step)


## Whether a locked piece landed where the last demonstration step put it.
## Compared as a SET: a different rotation that occupies the same cells still
## counts, because the lesson is about the position, not the fingerpath.
static func is_solution(level: Dictionary, landed: Array[Vector2i]) -> bool:
	var wanted := solution_cells(level)
	if wanted.is_empty():
		return true
	if wanted.size() != landed.size():
		return false
	var lookup := {}
	for cell in wanted:
		lookup[cell] = true
	for cell in landed:
		if not lookup.has(cell):
			return false
	return true


## Whether a lock meets a lesson's goal. `cleared_last` is whether the lock
## before this one cleared anything -- which is the whole of a combo.
static func is_passed(goal: int, lines: int, spin: int, cleared_last: bool) -> bool:
	match goal:
		Goal.CLEAR_LINE, Goal.HOLD_CLEAR:
			return lines > 0
		Goal.TETRIS:
			return lines >= 4
		Goal.T_SPIN:
			return spin != TetrisScoring.Spin.NONE
		Goal.COMBO:
			return lines > 0 and cleared_last
	return false


static func _step(kind: int, rotation: int, origin: Vector2i, key: String) -> Dictionary:
	return {
		"kind": kind,
		"rotation": rotation,
		"origin": origin,
		"key": key,
	}


static func _step_cells(step: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var origin: Vector2i = step["origin"]
	for cell in Tetromino.cells(step["kind"], step["rotation"]):
		result.append(origin + cell)
	return result
