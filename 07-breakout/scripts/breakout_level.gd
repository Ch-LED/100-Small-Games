class_name BreakoutLevel
## One hand-authored level, read from `levels/NN.txt`.
##
## The file is a character grid: a digit is how many hits the brick in that cell
## takes, `.` (or a space) is a hole. Both the SHAPE and the SIZE of the block
## come from the file — that is the whole point of hand-authoring, and it is why
## the grid is no longer tied to a column count in cfg.
##
## A digit does double duty as the brick's colour, so "how many hits will this
## take" is readable at a glance (DECISION_LOG 049).

const DIR := "res://07-breakout/levels"
const EXTENSION := ".txt"
const EMPTY_MARKS := [".", " "]
## A taller block than this eats the paddle's half of the board, and a wider one
## gives bricks thinner than the ball. Both are checked again against the real
## field geometry before a level is accepted.
const MAX_ROWS := 14
const MAX_COLS := 24

## Used when the level folder is missing or empty. `.txt` files do NOT ship in an
## exported build unless the preset's include filter names them, so a build that
## lost them has to still be playable.
const FALLBACK_TEXT := """\
11111111111111
11111111111111
11111111111111
11111111111111
11111111111111
11111111111111
11111111111111
11111111111111
"""

## One PackedInt32Array per row, top row first. 0 = hole, n = hits needed.
var rows: Array[PackedInt32Array] = []
var cols := 0
var source := ""


## Every level file in the folder, in name order. Empty when there are none.
static func available() -> PackedStringArray:
	var found := PackedStringArray()
	var dir := DirAccess.open(DIR)
	if dir == null:
		return found
	for file in dir.get_files():
		if file.ends_with(EXTENSION):
			found.append(DIR.path_join(file))
	found.sort()
	return found


static func load_file(path: String) -> BreakoutLevel:
	if not FileAccess.file_exists(path):
		push_error("BreakoutLevel: %s does not exist" % path)
		return null
	return parse(FileAccess.get_file_as_string(path), path)


static func fallback() -> BreakoutLevel:
	return parse(FALLBACK_TEXT, "built-in")


## Returns null when the text cannot be used. Every rejection is reported with a
## line number: quietly dropping a bad row would shift the whole layout, and the
## author would have no way to see why the board does not match the file.
static func parse(text: String, from: String) -> BreakoutLevel:
	var level := BreakoutLevel.new()
	level.source = from

	var line_number := 0
	for raw in text.split("\n"):
		line_number += 1
		# Trailing whitespace only: a leading space is a hole, not padding.
		var line := raw.trim_suffix("\r").rstrip(" \t")
		# A truly blank line separates rows, so it is skipped; a line of holes is
		# written with dots.
		if line.is_empty() or line.begins_with("#"):
			continue

		if line.length() > MAX_COLS:
			push_error("BreakoutLevel %s:%d has %d columns, over the %d limit"
					% [from, line_number, line.length(), MAX_COLS])
			return null

		var cells := PackedInt32Array()
		for i in line.length():
			var mark := line[i]
			if mark in EMPTY_MARKS:
				cells.append(0)
			elif mark.is_valid_int():
				cells.append(int(mark))
			else:
				push_error("BreakoutLevel %s:%d has an unknown mark '%s' (use '.' for a hole or 1-9)"
						% [from, line_number, mark])
				return null
		level.rows.append(cells)

	if level.rows.is_empty():
		push_error("BreakoutLevel %s has no rows" % from)
		return null
	if level.rows.size() > MAX_ROWS:
		push_error("BreakoutLevel %s has %d rows, over the %d limit"
				% [from, level.rows.size(), MAX_ROWS])
		return null

	# Ragged rows are padded on the right rather than refused: refusing would be
	# hostile to hand-editing, and a missing right-edge brick is plain to see.
	for row in level.rows:
		level.cols = maxi(level.cols, row.size())
	for row in level.rows:
		while row.size() < level.cols:
			row.append(0)

	if level.brick_count() == 0:
		push_error("BreakoutLevel %s has no bricks" % from)
		return null
	return level


func row_count() -> int:
	return rows.size()


func brick_count() -> int:
	var total := 0
	for row in rows:
		for cell in row:
			if cell > 0:
				total += 1
	return total


## Hits needed at a cell, 0 when it is a hole or off the grid.
func hits(row_index: int, col: int) -> int:
	if row_index < 0 or row_index >= rows.size():
		return 0
	var row := rows[row_index]
	if col < 0 or col >= row.size():
		return 0
	return row[col]


## The deepest layer count anywhere in the level, which is how far into the
## brick tables a lookup can go.
func max_hits() -> int:
	var deepest := 0
	for row in rows:
		for cell in row:
			deepest = maxi(deepest, cell)
	return deepest
