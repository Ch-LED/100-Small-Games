class_name SnakeBoard
extends Node2D
## Draws the play frame: panel, faint grid, and the border the snake dies on.
## Pure rendering — it decides nothing about the game, it only paints what the
## controller hands it.

const LETHAL_COLOR := Color("FF4B4B")
const SAFE_COLOR := Color("4BFF88")
const MARK_WIDTH := 3.0
const MARK_INSET_RATIO := 0.28

var _board_color := Color("16202E")
var _grid_color := Color("22304A")
var _border_color := Color("3B5A7A")
var _border_cheat_color := Color("2B3B52")
var _border_width := 4.0

## While true the frame is drawn dimmed: the edges no longer kill, they wrap.
var _wrapping := false

## Debug marks pushed by the controller: [{cell: Vector2i, lethal: bool}].
var marks: Array[Dictionary] = []


func configure(board_color: Color, grid_color: Color, border_color: Color,
		border_cheat_color: Color, border_width: float) -> void:
	_board_color = board_color
	_grid_color = grid_color
	_border_color = border_color
	_border_cheat_color = border_cheat_color
	_border_width = border_width
	queue_redraw()


## The frame is the death surface, so tint it when the edges stop being lethal.
func set_wrapping(enabled: bool) -> void:
	_wrapping = enabled
	queue_redraw()


func set_marks(new_marks: Array[Dictionary]) -> void:
	marks = new_marks
	queue_redraw()


func _draw() -> void:
	var origin := SnakeGrid.ORIGIN
	var size := SnakeGrid.BOARD_SIZE
	draw_rect(Rect2(origin, size), _board_color, true)

	for col in range(1, SnakeGrid.COLS):
		var x := origin.x + float(col) * SnakeGrid.CELL
		draw_line(Vector2(x, origin.y), Vector2(x, origin.y + size.y), _grid_color, 1.0)
	for row in range(1, SnakeGrid.ROWS):
		var y := origin.y + float(row) * SnakeGrid.CELL
		draw_line(Vector2(origin.x, y), Vector2(origin.x + size.x, y), _grid_color, 1.0)

	for mark in marks:
		_draw_mark(mark)

	draw_rect(Rect2(origin, size),
			_border_cheat_color if _wrapping else _border_color, false, _border_width)


func _draw_mark(mark: Dictionary) -> void:
	var cell: Vector2i = mark["cell"]
	var lethal: bool = mark["lethal"]
	var half := SnakeGrid.CELL * 0.5
	var rect := Rect2(SnakeGrid.cell_center(cell) - Vector2(half, half),
			Vector2(SnakeGrid.CELL, SnakeGrid.CELL))
	rect = rect.grow(-SnakeGrid.CELL * MARK_INSET_RATIO)
	draw_rect(rect, LETHAL_COLOR if lethal else SAFE_COLOR, false, MARK_WIDTH)
