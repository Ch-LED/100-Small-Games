class_name PacmanMaze
extends Node2D
## Parses the ASCII maze layout, answers gameplay queries about a cell, and
## renders the walls by auto-tiling (4-bit neighbour mask -> tile index).
##
## Layout characters: '#' wall, '.' pellet, 'o' power pellet, ' ' empty,
## '=' ghost door. Lines starting with ';' are comments.

const CHAR_WALL := "#"
const CHAR_PELLET := "."
const CHAR_POWER := "o"
const CHAR_EMPTY := " "
const CHAR_DOOR := "="

const PELLET_NONE := 0
const PELLET_SMALL := 1
const PELLET_POWER := 2

## Emitted whenever a pellet is taken, so the pellet layer redraws.
signal pellets_changed

## World = the real grid (1 cell per maze cell, tiles centred on cells).
## View  = the dual-grid art derived from World (tiles offset half a cell).
@onready var _world_layer: TileMapLayer = $World
@onready var _view_layer: TileMapLayer = $View
@onready var _doors_layer: TileMapLayer = $Doors

var _walls: PackedByteArray = PackedByteArray()
var _pellets: PackedByteArray = PackedByteArray()
var _doors: PackedByteArray = PackedByteArray()
var _remaining := 0
var _eaten := 0


func load_layout(path: String) -> bool:
	var grid := _read_grid(path)
	if grid.size() != PacmanGrid.ROWS:
		push_error("PacmanMaze: expected %d rows, got %d in %s" %
				[PacmanGrid.ROWS, grid.size(), path])
		return false
	var total := PacmanGrid.COLS * PacmanGrid.ROWS
	_walls.resize(total)
	_pellets.resize(total)
	_doors.resize(total)
	_remaining = 0
	_eaten = 0
	for row in PacmanGrid.ROWS:
		var line: String = grid[row]
		if line.length() != PacmanGrid.COLS:
			push_error("PacmanMaze: row %d has %d cells, expected %d" %
					[row, line.length(), PacmanGrid.COLS])
			return false
		for col in PacmanGrid.COLS:
			var i := row * PacmanGrid.COLS + col
			match line[col]:
				CHAR_WALL:
					_walls[i] = 1
				CHAR_DOOR:
					_doors[i] = 1
				CHAR_PELLET:
					_pellets[i] = PELLET_SMALL
					_remaining += 1
				CHAR_POWER:
					_pellets[i] = PELLET_POWER
					_remaining += 1
				_:
					pass
	pellets_changed.emit()
	return true


func _read_grid(path: String) -> Array[String]:
	var grid: Array[String] = []
	if not FileAccess.file_exists(path):
		push_error("PacmanMaze: layout not found at %s" % path)
		return grid
	var file := FileAccess.open(path, FileAccess.READ)
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty() or line.begins_with(";"):
			continue
		grid.append(line)
	file.close()
	return grid


# --- queries ----------------------------------------------------------------

## Walls are read straight off the World layer, so the baked map is the single
## source of truth (no separate layout file for the geometry).
func is_wall(cell: Vector2i) -> bool:
	var c := PacmanGrid.wrap(cell)
	if not PacmanGrid.in_bounds(c):
		return true
	return _world_layer.get_cell_source_id(c) != -1


func is_door(cell: Vector2i) -> bool:
	if not PacmanGrid.in_bounds(cell):
		return false
	return _doors[PacmanGrid.index(cell)] == 1


## Actors may enter anything that is not a wall — ghosts additionally pass doors.
func is_open(cell: Vector2i, allow_door := false) -> bool:
	if is_wall(cell):
		return false
	if is_door(cell) and not allow_door:
		return false
	return true


func pellet_at(cell: Vector2i) -> int:
	if not PacmanGrid.in_bounds(cell):
		return PELLET_NONE
	return _pellets[PacmanGrid.index(cell)]


## Removes and returns the pellet kind at the cell (0 if it was already empty).
func take_pellet(cell: Vector2i) -> int:
	if not PacmanGrid.in_bounds(cell):
		return PELLET_NONE
	var i := PacmanGrid.index(cell)
	var kind := _pellets[i]
	if kind != PELLET_NONE:
		_pellets[i] = PELLET_NONE
		_remaining -= 1
		_eaten += 1
		pellets_changed.emit()
	return kind


func remaining_pellets() -> int:
	return _remaining


func eaten_pellets() -> int:
	return _eaten


func cleared() -> bool:
	return _remaining <= 0


# --- rendering (dual grid) --------------------------------------------------

## Walls are drawn with a dual grid: a tile sits on every cell CORNER (offset
## half a cell), and its four 8x8 quadrants describe the four cells that meet
## there. So a 4-bit mask of "which of those cells is a wall" selects the tile.
##
## The sheet only ships a handful of base shapes; the rest of the 16 masks are
## reached by mirroring (and, for the two half-fills, a 90 degree rotation),
## which keeps the 2px highlight on the outward edge.
const QUAD_NW := 8
const QUAD_NE := 4
const QUAD_SW := 2
const QUAD_SE := 1

## mask -> [atlas column, alternative id] inside maze_tileset.tres. The sheet
## only ships 7 drawn shapes; the TileSet carries the mirror/rotation variants
## as alternative tiles, so the mapping stays data.
const TILE_FOR_MASK := {
	0: [0, 0],
	1: [1, 0],    # SE
	2: [1, 1],    # SW            (flip_h)
	3: [2, 0],    # SW+SE
	4: [1, 2],    # NE            (flip_v)
	5: [2, 2],    # NE+SE         (transpose: bottom half -> right half)
	6: [3, 0],    # NE+SW
	7: [4, 3],    # all but NW    (flip_h + flip_v)
	8: [1, 3],    # NW            (flip_h + flip_v)
	9: [3, 1],    # NW+SE         (flip_h)
	10: [2, 3],   # NW+SW         (flip_h + transpose -> left half)
	11: [4, 2],   # all but NE    (flip_v)
	12: [2, 1],   # NW+NE         (flip_v)
	13: [4, 1],   # all but SW    (flip_h)
	14: [4, 0],   # all but SE
	15: [5, 0],   # solid
}
const TILE_SOURCE := 0
const TILE_PX := 16.0
const DOOR_ATLAS := Vector2i(6, 0)


## Lays out the three layers for the current cell size.
##
## World holds the real grid: one tile per cell, centred on the cell, so it
## doubles as the collision/authoring source. View is derived from World by the
## dual-grid step below — that derivation is the only procedural part left.
func build_tiles(cell_size: float) -> void:
	var s := cell_size / TILE_PX
	var cell_vec := Vector2(TILE_PX, TILE_PX) * s
	# A TileMapLayer puts cell (c,r) centred at (c+0.5, r+0.5) tiles, so:
	#   World wants tiles centred on maze cells      -> offset 0
	#   View  wants them centred on cell corners     -> offset -half a cell
	_world_layer.scale = Vector2.ONE * s
	_world_layer.position = PacmanGrid.ORIGIN
	_doors_layer.scale = Vector2.ONE * s
	_doors_layer.position = PacmanGrid.ORIGIN
	_view_layer.scale = Vector2.ONE * s
	_view_layer.position = PacmanGrid.ORIGIN - cell_vec * 0.5
	_rebuild_view()


## World -> View: every corner looks at the four World cells meeting there and
## picks the matching dual-grid tile.
func _rebuild_view() -> void:
	_view_layer.clear()
	for row in range(PacmanGrid.ROWS + 1):
		for col in range(PacmanGrid.COLS + 1):
			var spec: Array = TILE_FOR_MASK.get(_corner_mask(col, row), [])
			if spec.is_empty():
				continue
			_view_layer.set_cell(Vector2i(col, row), TILE_SOURCE,
					Vector2i(int(spec[0]), 0), int(spec[1]))


## Writes the baked World layer from the ASCII layout. Editor/tool use only —
## the shipped scene already has it painted.
func bake_world_from_layout(path: String) -> void:
	if not load_layout(path):
		return
	# Resolved by path (not @onready) so the tool can bake a scene that was
	# instantiated but never added to the tree.
	var world: TileMapLayer = get_node("World")
	var doors: TileMapLayer = get_node("Doors")
	for row in PacmanGrid.ROWS:
		for col in PacmanGrid.COLS:
			var cell := Vector2i(col, row)
			if _walls[PacmanGrid.index(cell)] == 1:
				world.set_cell(cell, TILE_SOURCE, Vector2i(5, 0), 0)
			if _doors[PacmanGrid.index(cell)] == 1:
				doors.set_cell(cell, TILE_SOURCE, DOOR_ATLAS, 0)


## A corner is a wall-quadrant when the cell on that side is wall or off-map.
func _corner_mask(col: int, row: int) -> int:
	var mask := 0
	if is_wall(Vector2i(col - 1, row - 1)):
		mask |= QUAD_NW
	if is_wall(Vector2i(col, row - 1)):
		mask |= QUAD_NE
	if is_wall(Vector2i(col - 1, row)):
		mask |= QUAD_SW
	if is_wall(Vector2i(col, row)):
		mask |= QUAD_SE
	return mask


## Debug helper: how many corners fall into each mask (0..15).
func mask_histogram() -> Dictionary:
	var counts := {}
	for row in range(PacmanGrid.ROWS + 1):
		for col in range(PacmanGrid.COLS + 1):
			var mask := _corner_mask(col, row)
			counts[mask] = int(counts.get(mask, 0)) + 1
	return counts
