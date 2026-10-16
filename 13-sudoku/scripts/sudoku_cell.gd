class_name SudokuCell
extends Control

## One square of the board, drawn rather than assembled from Labels.
##
## A cell has to show either one large digit or up to nine small ones in the
## same place, and it has to do it 81 times over. Nine child Labels per cell
## would be 729 nodes whose layout the engine re-solves on every change; a
## single `_draw` is one node and one pass (spec 3.1).
##
## The cell knows nothing about the puzzle -- the view pushes a state
## dictionary in and the cell paints it.

var index := 0
var digit := 0
var is_given := false
var is_conflict := false
var is_cursor := false
var is_peer := false
## Set on digits the super cheat entered, so the colour says who wrote them.
var is_super := false
var note_mask := 0
## Candidates the cheat key is showing; overrides the pencil marks while it is on.
var hint_mask := 0

var _palette: SudokuSettings
var _font: FontFile


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = PixelFont.get_font()


func set_palette(palette: SudokuSettings) -> void:
	_palette = palette
	if _font == null:
		_font = PixelFont.get_font()
	queue_redraw()


func set_state(state: Dictionary) -> void:
	digit = int(state.get("digit", 0))
	is_given = bool(state.get("given", false))
	is_conflict = bool(state.get("conflict", false))
	is_cursor = bool(state.get("cursor", false))
	is_peer = bool(state.get("peer", false))
	is_super = bool(state.get("super", false))
	note_mask = int(state.get("notes", 0))
	hint_mask = int(state.get("hints", 0))
	queue_redraw()


func _draw() -> void:
	if _palette == null:
		return
	var background := Color(0, 0, 0, 0)
	if is_cursor:
		background = _palette.cursor_color
	elif is_peer:
		background = _palette.peer_color
	if background.a > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), background)
	if digit != 0:
		_draw_digit()
	elif note_mask != 0 or hint_mask != 0:
		_draw_notes()
	_draw_borders()


## Each cell draws its own top and left edge, so the grid costs no extra node
## and the lines come out on top of the highlight fills rather than under them.
## Lines falling on a box boundary are heavier, which is the whole reason a
## sudoku board is readable at a glance.
func _draw_borders() -> void:
	var row := SudokuBoard.row_of(index)
	var col := SudokuBoard.col_of(index)
	var thick := col % SudokuBoard.BOX == 0
	draw_line(Vector2.ZERO, Vector2(0.0, size.y),
			_palette.box_line_color if thick else _palette.line_color,
			3.0 if thick else 1.0)
	thick = row % SudokuBoard.BOX == 0
	draw_line(Vector2.ZERO, Vector2(size.x, 0.0),
			_palette.box_line_color if thick else _palette.line_color,
			3.0 if thick else 1.0)
	if col == SudokuBoard.SIZE - 1:
		draw_line(Vector2(size.x - 1.0, 0.0), Vector2(size.x - 1.0, size.y),
				_palette.box_line_color, 3.0)
	if row == SudokuBoard.SIZE - 1:
		draw_line(Vector2(0.0, size.y - 1.0), Vector2(size.x, size.y - 1.0),
				_palette.box_line_color, 3.0)


func _draw_digit() -> void:
	var color := _palette.entry_color
	if is_given:
		color = _palette.given_color
	if is_conflict:
		color = _palette.conflict_color
	if is_super:
		color = _palette.super_color
	var font_size := maxi(8, int(size.x * _palette.digit_scale))
	var text := str(digit)
	var extent := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(_font, _centred(extent, font_size), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw_notes() -> void:
	# The cheat's candidates are the truth of the moment and win over the
	# player's own pencil marks while it is on.
	var mask := hint_mask if hint_mask != 0 else note_mask
	var color := _palette.auto_note_color if hint_mask != 0 else _palette.note_color
	var font_size := maxi(8, int(size.x * _palette.note_scale))
	var third := size.x / 3.0
	for digit_index in range(1, SudokuBoard.SIZE + 1):
		if not (mask & (1 << digit_index)):
			continue
		var column := (digit_index - 1) % 3
		var row := (digit_index - 1) / 3
		var text := str(digit_index)
		var extent := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var ascent := _font.get_ascent(font_size)
		var descent := _font.get_descent(font_size)
		var position := Vector2(
				third * column + (third - extent.x) * 0.5,
				third * row + (third - (ascent + descent)) * 0.5 + ascent)
		draw_string(_font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## Baseline origin for text centred both ways in the cell.
func _centred(extent: Vector2, font_size: int) -> Vector2:
	var ascent := _font.get_ascent(font_size)
	var descent := _font.get_descent(font_size)
	return Vector2(
			(size.x - extent.x) * 0.5,
			(size.y - (ascent + descent)) * 0.5 + ascent)
