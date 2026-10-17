class_name SokobanLevel
extends RefCounted

## One board: the walls, the goals, where the boxes are, where the player is.
##
## Parsed from the standard Sokoban text format, so a level file is legible
## and hand-editable:
##
##   #  wall       space  floor
##   $  box        .      goal
##   *  box on goal
##   @  player     +      player on goal
##
## No scene tree, no signals -- the assertions and the solver drive it directly.

const WALL := "#"
const FLOOR := " "
const BOX := "$"
const GOAL := "."
const BOX_ON_GOAL := "*"
const PLAYER := "@"
const PLAYER_ON_GOAL := "+"

const DIRECTIONS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

var rows := 0
var cols := 0
var walls := PackedByteArray()
var goals := PackedByteArray()
## Where the boxes begin, so a restart can put them back.
var start_boxes := PackedByteArray()

var boxes := PackedByteArray()
var player := -1
var start_player := -1
var moves := 0
var pushes := 0

var _history: Array = []


## Returns false when the text is not a usable board. A level with no player,
## no box or no goal is not a puzzle, and failing loudly beats shipping it.
func load_from_text(text: String) -> bool:
	var lines: PackedStringArray = text.split("\n", false)
	if lines.is_empty():
		return false
	var width := 0
	for line in lines:
		width = maxi(width, line.length())
	rows = lines.size()
	cols = width
	walls = PackedByteArray()
	goals = PackedByteArray()
	start_boxes = PackedByteArray()
	walls.resize(rows * cols)
	goals.resize(rows * cols)
	start_boxes.resize(rows * cols)
	walls.fill(0)
	goals.fill(0)
	start_boxes.fill(0)
	start_player = -1
	var box_count := 0
	var goal_count := 0
	for row in rows:
		var line: String = lines[row]
		for col in line.length():
			var cell := index_of(row, col)
			var glyph := line[col]
			match glyph:
				WALL:
					walls[cell] = 1
				GOAL:
					goals[cell] = 1
					goal_count += 1
				BOX:
					start_boxes[cell] = 1
					box_count += 1
				BOX_ON_GOAL:
					start_boxes[cell] = 1
					goals[cell] = 1
					box_count += 1
					goal_count += 1
				PLAYER:
					start_player = cell
				PLAYER_ON_GOAL:
					start_player = cell
					goals[cell] = 1
					goal_count += 1
				_:
					pass
	if start_player < 0 or box_count == 0 or box_count != goal_count:
		return false
	restart()
	return true


func restart() -> void:
	boxes = start_boxes.duplicate()
	player = start_player
	moves = 0
	pushes = 0
	_history = []


func index_of(row: int, col: int) -> int:
	return row * cols + col


func row_of(cell: int) -> int:
	return cell / cols


func col_of(cell: int) -> int:
	return cell % cols


func cell_count() -> int:
	return rows * cols


## Anything off the grid is a wall. Levels are not required to be rectangular,
## and the ragged edge is what keeps a box from being pushed into the void.
func is_wall(cell: int) -> bool:
	if cell < 0 or cell >= cell_count():
		return true
	return walls[cell] != 0


func has_box(cell: int) -> bool:
	return cell >= 0 and cell < cell_count() and boxes[cell] != 0


func is_goal(cell: int) -> bool:
	return cell >= 0 and cell < cell_count() and goals[cell] != 0


func step(cell: int, direction: Vector2i) -> int:
	var row := row_of(cell) + direction.y
	var col := col_of(cell) + direction.x
	if row < 0 or row >= rows or col < 0 or col >= cols:
		return -1
	return index_of(row, col)


# --- moves -------------------------------------------------------------------

## Moves the player one cell. Returns 0 when nothing happened, 1 when the player
## walked, and 2 when a box was pushed.
func move(direction: Vector2i) -> int:
	if player < 0:
		return 0
	var target := step(player, direction)
	if target < 0 or is_wall(target):
		return 0
	if has_box(target):
		var beyond := step(target, direction)
		if beyond < 0 or is_wall(beyond) or has_box(beyond):
			return 0
		_push_history()
		boxes[target] = 0
		boxes[beyond] = 1
		player = target
		moves += 1
		pushes += 1
		return 2
	_push_history()
	player = target
	moves += 1
	return 1


## The `[` cheat: drag a box along behind the player. It breaks the rule that
## makes the game hard -- that a box, once pushed into a corner, is finished --
## so a player who has wedged one can still get it back (DECISION_LOG 107).
func pull(direction: Vector2i) -> int:
	if player < 0:
		return 0
	var target := step(player, direction)
	if target < 0 or is_wall(target) or has_box(target):
		return 0
	var behind := step(player, -direction)
	if behind < 0 or is_wall(behind) or not has_box(behind):
		return 0
	_push_history()
	boxes[behind] = 0
	boxes[player] = 1
	player = target
	moves += 1
	pushes += 1
	return 2


## The `]` cheat: walk through a box. Walls still stop the player -- what is
## broken is "a box is in your way", not the shape of the level
## (DECISION_LOG 107).
func move_ghost(direction: Vector2i) -> int:
	if player < 0:
		return 0
	var target := step(player, direction)
	if target < 0 or is_wall(target):
		return 0
	_push_history()
	player = target
	moves += 1
	return 1


func undo() -> bool:
	if _history.is_empty():
		return false
	var state: Dictionary = _history.pop_back()
	boxes = (state["boxes"] as PackedByteArray).duplicate()
	player = int(state["player"])
	moves = int(state["moves"])
	pushes = int(state["pushes"])
	return true


func can_undo() -> bool:
	return not _history.is_empty()


func _push_history() -> void:
	_history.append({
		"boxes": boxes.duplicate(),
		"player": player,
		"moves": moves,
		"pushes": pushes,
	})


# --- state -------------------------------------------------------------------

func box_count() -> int:
	var count := 0
	for cell in cell_count():
		if boxes[cell] != 0:
			count += 1
	return count


func boxes_on_goals() -> int:
	var count := 0
	for cell in cell_count():
		if boxes[cell] != 0 and goals[cell] != 0:
			count += 1
	return count


func is_won() -> bool:
	for cell in cell_count():
		if goals[cell] != 0 and boxes[cell] == 0:
			return false
	return true


## Every box that sits in a corner of the wall, which can never move again.
## Used only to tell the player when a board has become impossible.
func stuck_boxes() -> int:
	var count := 0
	for cell in cell_count():
		if boxes[cell] == 0 or goals[cell] != 0:
			continue
		var up := is_wall(step(cell, Vector2i(0, -1)))
		var down := is_wall(step(cell, Vector2i(0, 1)))
		var left := is_wall(step(cell, Vector2i(-1, 0)))
		var right := is_wall(step(cell, Vector2i(1, 0)))
		if (up or down) and (left or right):
			count += 1
	return count
