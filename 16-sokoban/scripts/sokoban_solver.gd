class_name SokobanSolver
extends RefCounted

## Breadth-first search over whole board states, used to prove a level can
## actually be finished.
##
## It is not part of the game -- the game never solves anything. It exists so
## that "this level is solvable" is something the assertions *check* rather
## than something whoever wrote the level *hoped*. A Sokoban level that cannot
## be finished looks exactly like one that can until someone tries.
##
## A state is the player's cell plus every box's cell; the moves that reach a
## given state do not matter, so the search is over positions and the first
## time it sees a position it is done with it. Small boards settle in
## milliseconds; the state cap is there so a badly shaped level reports "no
## answer" instead of hanging the test run.

const DEFAULT_LIMIT := 300000


## Shortest number of moves, or -1 when it cannot be finished (or the search
## hit the state cap).
static func solve(level: SokobanLevel, limit: int = DEFAULT_LIMIT) -> int:
	var start := _key(level.start_player, level.start_boxes)
	var queue: Array = [[level.start_player, level.start_boxes.duplicate(), 0]]
	var seen := {start: true}
	var head := 0
	while head < queue.size():
		if seen.size() > limit:
			return -1
		var state: Array = queue[head]
		head += 1
		var player: int = state[0]
		var boxes: PackedByteArray = state[1]
		var depth: int = state[2]
		if _won(boxes, level):
			return depth
		for direction in SokobanLevel.DIRECTIONS:
			var target := _step(player, direction, level)
			if target < 0 or level.is_wall(target):
				continue
			var next_boxes: PackedByteArray = boxes
			if boxes[target] != 0:
				var beyond := _step(target, direction, level)
				if beyond < 0 or level.is_wall(beyond) or boxes[beyond] != 0:
					continue
				next_boxes = boxes.duplicate()
				next_boxes[target] = 0
				next_boxes[beyond] = 1
			var key := _key(target, next_boxes)
			if seen.has(key):
				continue
			seen[key] = true
			queue.append([target, next_boxes, depth + 1])
	return -1


static func _step(cell: int, direction: Vector2i, level: SokobanLevel) -> int:
	var row := cell / level.cols + direction.y
	var col := cell % level.cols + direction.x
	if row < 0 or row >= level.rows or col < 0 or col >= level.cols:
		return -1
	return row * level.cols + col


static func _key(player: int, boxes: PackedByteArray) -> String:
	var out := str(player)
	for cell in boxes.size():
		if boxes[cell] != 0:
			out += ",%d" % cell
	return out


static func _won(boxes: PackedByteArray, level: SokobanLevel) -> bool:
	for cell in level.cell_count():
		if level.goals[cell] != 0 and boxes[cell] == 0:
			return false
	return true
