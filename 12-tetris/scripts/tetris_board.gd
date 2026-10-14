class_name TetrisBoard
extends RefCounted

## The pile: which cells of the well are taken, and clearing full rows.
##
## There is no "current piece" in here -- that belongs to the play session.
## Row 0 is at the top; the bottom VISIBLE_ROWS rows are the ones on screen and
## the SPAWN_ROWS above them exist so a kick has somewhere to push a piece.

const WIDTH := 10
const TOTAL_ROWS := 24
const VISIBLE_ROWS := 20
const SPAWN_ROWS := TOTAL_ROWS - VISIBLE_ROWS

## 0 is empty; anything else is a locked kind + 1, so the renderer can colour
## the cell without asking who locked it.
const EMPTY := 0

var _cells: Array[PackedInt32Array] = []


func _init() -> void:
	clear()


func clear() -> void:
	_cells.clear()
	for _row in TOTAL_ROWS:
		var line := PackedInt32Array()
		line.resize(WIDTH)
		_cells.append(line)


## Places a hand-authored position against the floor. `rows` are spelled
## top-down, '#' is a filled cell, and they are pinned to the BOTTOM of the
## well so a one-row lesson still sits on the last row where it belongs.
func load_rows(rows: Array) -> void:
	clear()
	var first_row := TOTAL_ROWS - rows.size()
	for index in rows.size():
		var line: String = rows[index]
		var y := first_row + index
		if y < 0 or y >= TOTAL_ROWS:
			continue
		for x in mini(line.length(), WIDTH):
			if line[x] == "#":
				_cells[y][x] = 1


func cell_at(x: int, y: int) -> int:
	if x < 0 or x >= WIDTH or y < 0 or y >= TOTAL_ROWS:
		return EMPTY
	return _cells[y][x]


## Whether a wall or the floor is in the way here. Outside the well counts as
## solid on the sides and the bottom, but the space above the spawn line is
## open -- that is where kicks go.
func is_occupied(x: int, y: int) -> bool:
	if x < 0 or x >= WIDTH or y >= TOTAL_ROWS:
		return true
	if y < 0:
		return false
	return _cells[y][x] != EMPTY


## Whether every cell would land somewhere legal at `origin`.
func is_free(cells: Array[Vector2i], origin: Vector2i) -> bool:
	for cell in cells:
		if is_occupied(origin.x + cell.x, origin.y + cell.y):
			return false
	return true


## How many of the four corners around a T's centre are occupied, and how many
## of the two facing the nub are among them. Returns (total, front).
##
## Both numbers are needed. Three occupied corners is what makes a spin a
## T-spin at all; whether the nub-side pair is complete is what separates a
## full T-spin from a mini.
func t_corner_counts(origin: Vector2i, rotation: int) -> Vector2i:
	var corners := Tetromino.t_corners(rotation)
	var total := 0
	var front := 0
	for index in corners.size():
		var corner := corners[index]
		if is_occupied(origin.x + corner.x, origin.y + corner.y):
			total += 1
			if index < 2:
				front += 1
	return Vector2i(total, front)


func lock(cells: Array[Vector2i], origin: Vector2i, kind: int) -> void:
	for cell in cells:
		var x := origin.x + cell.x
		var y := origin.y + cell.y
		if x >= 0 and x < WIDTH and y >= 0 and y < TOTAL_ROWS:
			_cells[y][x] = kind + 1


## Removes every full row at once -- including rows that were hollowed out in
## the middle of a stack -- and drops everything above down onto the gap.
func clear_lines() -> int:
	var kept: Array[PackedInt32Array] = []
	var cleared := 0
	for row in TOTAL_ROWS:
		if _is_row_full(row):
			cleared += 1
		else:
			kept.append(_cells[row])
	for _row in cleared:
		var line := PackedInt32Array()
		line.resize(WIDTH)
		kept.push_front(line)
	_cells = kept
	return cleared


func _is_row_full(row: int) -> bool:
	for x in WIDTH:
		if _cells[row][x] == EMPTY:
			return false
	return true
