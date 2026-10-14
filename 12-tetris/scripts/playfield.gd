class_name TetrisPlayfield
extends Node2D

## Paints one session: the pile, the piece in flight, its landing preview, and
## the hold / next wells.
##
## It owns no rules. Everything it draws arrives as an argument, which is what
## keeps the play session testable with no scene at all.

## Cells across a preview well. Four fits every kind's bounding box.
const SLOT_SIZE := 4
const SLOT_SCALE := 0.5

@onready var _board_layer: TileMapLayer = $Board
@onready var _ghost_layer: TileMapLayer = $Ghost
@onready var _frame: Line2D = $Frame
@onready var _hold_slot: TileMapLayer = $SidePanel/Hold
@onready var _next_slots: Array[TileMapLayer] = [
	$SidePanel/Next0,
	$SidePanel/Next1,
	$SidePanel/Next2,
	$SidePanel/Next3,
	$SidePanel/Next4,
]


func setup(settings: TetrisSettings) -> void:
	var tiles := TetrisTiles.build(settings.piece_colors, settings.super_color)
	_board_layer.tile_set = tiles
	_ghost_layer.tile_set = tiles
	_hold_slot.tile_set = tiles
	_hold_slot.scale = Vector2(SLOT_SCALE, SLOT_SCALE)
	for slot in _next_slots:
		slot.tile_set = tiles
		slot.scale = Vector2(SLOT_SCALE, SLOT_SCALE)

	var size := Vector2(TetrisBoard.WIDTH, TetrisBoard.VISIBLE_ROWS) * settings.cell_size
	_frame.width = 2.0
	_frame.default_color = settings.grid_color
	_frame.points = PackedVector2Array([
		Vector2.ZERO,
		Vector2(size.x, 0.0),
		size,
		Vector2(0.0, size.y),
	])
	_frame.closed = true


## The landing preview shows something a player could work out anyway, so it is
## a readout rather than a rule. It starts ON, which is what the standard this
## game follows does.
func set_ghost_visible(shown: bool) -> void:
	_ghost_layer.visible = shown


## Draws where a piece would end up WITHOUT moving anything. The tutorial uses
## it to run through a lesson's moves before the player takes over.
func show_demo(cells: Array[Vector2i], kind: int) -> void:
	_ghost_layer.clear()
	for cell in cells:
		if cell.y >= TetrisBoard.SPAWN_ROWS:
			_paint(_ghost_layer, cell.x, cell.y, TetrisTiles.ghost_coords(kind))


func clear_demo() -> void:
	_ghost_layer.clear()


## Full repaint every frame. At 200 cells that is nothing, and unlike an
## incremental update it cannot leave a stale block behind after a clear.
func render_pile(
	board: TetrisBoard,
	active: Array[Vector2i],
	active_kind: int,
	ghost: Array[Vector2i],
	super_mode: bool
) -> void:
	_board_layer.clear()
	_ghost_layer.clear()
	for y in range(TetrisBoard.SPAWN_ROWS, TetrisBoard.TOTAL_ROWS):
		for x in TetrisBoard.WIDTH:
			var value := board.cell_at(x, y)
			if value != TetrisBoard.EMPTY:
				_paint(_board_layer, x, y, TetrisTiles.atlas_coords(value - 1))
	# The preview goes under the live piece so the two read as one shape once
	# the piece has actually landed on it.
	for cell in ghost:
		if cell.y >= TetrisBoard.SPAWN_ROWS:
			_paint(_ghost_layer, cell.x, cell.y, TetrisTiles.ghost_coords(active_kind))
	# Zero gravity paints the whole piece in the project's super colour, so what
	# has been taken over is visible at a glance.
	var active_coords := TetrisTiles.super_coords() if super_mode else TetrisTiles.atlas_coords(active_kind)
	for cell in active:
		if cell.y >= TetrisBoard.SPAWN_ROWS:
			_paint(_board_layer, cell.x, cell.y, active_coords)


func render_hold(kind: int) -> void:
	_fill_slot(_hold_slot, kind)


func render_next(queue: Array[int]) -> void:
	for index in _next_slots.size():
		var kind := queue[index] if index < queue.size() else -1
		_fill_slot(_next_slots[index], kind)


func _paint(layer: TileMapLayer, x: int, y: int, coords: Vector2i) -> void:
	layer.set_cell(Vector2i(x, y - TetrisBoard.SPAWN_ROWS), TetrisTiles.SOURCE_ID, coords)


func _fill_slot(slot: TileMapLayer, kind: int) -> void:
	slot.clear()
	if kind < 0:
		return
	for cell in _slot_cells(kind):
		slot.set_cell(cell, TetrisTiles.SOURCE_ID, TetrisTiles.atlas_coords(kind))


## Where a kind sits inside a four-by-four well. Centred on the cells it
## actually occupies rather than on its bounding box -- otherwise I would hang
## off the left edge while O sat in the middle.
func _slot_cells(kind: int) -> Array[Vector2i]:
	var cells := Tetromino.cells(kind, 0)
	var min_x := 1 << 30
	var max_x := -(1 << 30)
	var min_y := 1 << 30
	var max_y := -(1 << 30)
	for cell in cells:
		min_x = mini(min_x, cell.x)
		max_x = maxi(max_x, cell.x)
		min_y = mini(min_y, cell.y)
		max_y = maxi(max_y, cell.y)
	var offset := Vector2i(
		(SLOT_SIZE - (max_x - min_x + 1) + 1) / 2 - min_x,
		(SLOT_SIZE - (max_y - min_y + 1) + 1) / 2 - min_y
	)
	var result: Array[Vector2i] = []
	for cell in cells:
		result.append(cell + offset)
	return result
