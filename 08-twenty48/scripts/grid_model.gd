class_name Game2048Grid
extends RefCounted
## The board's plain data model: a 4x4 array of values with the slide/merge
## rules. Deliberately not a Node — it touches no scene tree, so the rules can
## be asserted directly without instantiating anything.

enum Direction { LEFT, RIGHT, UP, DOWN }

const SIZE := 4
const CELLS := SIZE * SIZE


static func direction_from_name(name: String) -> int:
	match name:
		"left": return Direction.LEFT
		"right": return Direction.RIGHT
		"up": return Direction.UP
		"down": return Direction.DOWN
	return Direction.LEFT


var cells: Array[int] = []


func _init() -> void:
	reset()


func reset() -> void:
	cells.clear()
	cells.resize(CELLS)
	cells.fill(0)


func is_inside(row: int, col: int) -> bool:
	return row >= 0 and row < SIZE and col >= 0 and col < SIZE


func get_cell(row: int, col: int) -> int:
	if not is_inside(row, col):
		return 0
	return cells[row * SIZE + col]


func set_cell(row: int, col: int, value: int) -> void:
	if not is_inside(row, col):
		return
	cells[row * SIZE + col] = value


func empty_indices() -> Array[int]:
	var out: Array[int] = []
	for i in CELLS:
		if cells[i] == 0:
			out.append(i)
	return out


func largest() -> int:
	var best := 0
	for value in cells:
		best = maxi(best, value)
	return best


func is_full() -> bool:
	return empty_indices().is_empty()


## True while any move is still possible: an empty cell, or two neighbours that
## could still be merged.
func can_move() -> bool:
	if not is_full():
		return true
	for row in SIZE:
		for col in SIZE:
			var value := get_cell(row, col)
			if col + 1 < SIZE and get_cell(row, col + 1) == value:
				return true
			if row + 1 < SIZE and get_cell(row + 1, col) == value:
				return true
	return false


## Compacts and merges every line. `moved` is the board's own answer to "did this
## move do anything", which is what decides whether a tile spawns.
func slide(direction: int) -> Dictionary:
	var moved := false
	var gained := 0
	var merges: Array[int] = []
	for line in SIZE:
		var before := _read_line(direction, line)
		var result := _slide_line(before)
		if result.line != before:
			moved = true
		gained += int(result.gained)
		for value in result.merges:
			merges.append(int(value))
		_write_line(direction, line, result.line)
	return {"moved": moved, "gained": gained, "merges": merges}


func snapshot() -> Array[int]:
	return cells.duplicate()


func restore(snapshot_cells: Array) -> void:
	cells.clear()
	for value in snapshot_cells:
		cells.append(int(value))
	if cells.size() != CELLS:
		reset()


## Puts a 2 (or, with `four_chance`, a 4) in a random empty cell. Returns the
## index used, or -1 when the board is full.
func spawn(rng: RandomNumberGenerator, four_chance: float) -> int:
	var empty := empty_indices()
	if empty.is_empty():
		return -1
	var index: int = empty[rng.randi_range(0, empty.size() - 1)]
	cells[index] = 4 if rng.randf() < four_chance else 2
	return index


# --- lines ------------------------------------------------------------------

## One line read so that index 0 is the cell nearest the destination, which lets
## a single merge routine serve all four directions.
func _read_line(direction: int, line: int) -> Array[int]:
	var out: Array[int] = []
	for step in SIZE:
		match direction:
			Direction.LEFT:
				out.append(get_cell(line, step))
			Direction.RIGHT:
				out.append(get_cell(line, SIZE - 1 - step))
			Direction.UP:
				out.append(get_cell(step, line))
			_:
				out.append(get_cell(SIZE - 1 - step, line))
	return out


func _write_line(direction: int, line: int, values: Array[int]) -> void:
	for step in SIZE:
		match direction:
			Direction.LEFT:
				set_cell(line, step, values[step])
			Direction.RIGHT:
				set_cell(line, SIZE - 1 - step, values[step])
			Direction.UP:
				set_cell(step, line, values[step])
			_:
				set_cell(SIZE - 1 - step, line, values[step])


## Slides one line toward index 0 and merges equal neighbours. A tile takes part
## in at most one merge per move, which is what the `i += 2` skip guarantees:
## 2 2 2 2 becomes 4 4, never 8.
func _slide_line(values: Array[int]) -> Dictionary:
	var compact: Array[int] = []
	for value in values:
		if value != 0:
			compact.append(value)

	var out: Array[int] = []
	var gained := 0
	var merges: Array[int] = []
	var i := 0
	while i < compact.size():
		if i + 1 < compact.size() and compact[i] == compact[i + 1]:
			var merged := compact[i] * 2
			out.append(merged)
			gained += merged
			merges.append(merged)
			i += 2
		else:
			out.append(compact[i])
			i += 1
	while out.size() < SIZE:
		out.append(0)
	return {"line": out, "gained": gained, "merges": merges}
