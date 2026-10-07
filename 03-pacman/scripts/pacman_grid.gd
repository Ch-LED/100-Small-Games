class_name PacmanGrid
## Grid geometry: 28x31 cells of 16 px, centred in the 1280x720 logical field.
## Everything (maze, pellets, actors) works in cell coords and converts here.

const COLS := 28
const ROWS := 31
const FIELD := Vector2(1280.0, 720.0)

## Display size of one cell. The art is authored at 16px; this scales the maze
## up to fill the window, and everything else derives from it. Set once at boot
## via configure() before any layout happens.
static var CELL := 16.0
static var MAZE_SIZE := Vector2(COLS, ROWS) * 16.0
## Top-left of the maze in field coordinates (maze is centred; UI lives in the
## side margins).
static var ORIGIN := (FIELD - MAZE_SIZE) * 0.5


static func configure(cell_size: float) -> void:
	CELL = cell_size
	MAZE_SIZE = Vector2(COLS, ROWS) * cell_size
	ORIGIN = (FIELD - MAZE_SIZE) * 0.5

## Column of the tunnel row (walking off either end wraps around).
const TUNNEL_ROW := 14
const SCATTER_TARGETS := {
	"blinky": Vector2i(25, 0),
	"pinky": Vector2i(2, 0),
	"inky": Vector2i(27, 30),
	"clyde": Vector2i(0, 30),
}


## Centre of a cell in local (field) coordinates.
static func cell_center(cell: Vector2i) -> Vector2:
	return ORIGIN + (Vector2(cell) + Vector2(0.5, 0.5)) * CELL


static func cell_of(local: Vector2) -> Vector2i:
	return Vector2i(((local - ORIGIN) / CELL).floor())


static func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < COLS and cell.y >= 0 and cell.y < ROWS


## Tunnel wrap: only the tunnel row connects the two edges.
static func wrap(cell: Vector2i) -> Vector2i:
	if cell.y == TUNNEL_ROW:
		if cell.x < 0:
			return Vector2i(COLS - 1, cell.y)
		if cell.x >= COLS:
			return Vector2i(0, cell.y)
	return cell


## Pixel offset that carries an actor out of one side of the maze and into the
## other. Actors keep walking past the edge (cell coords go out of bounds) and
## this shifts both the cell and the position by exactly one maze width, so the
## motion stays continuous instead of teleporting across the screen.
static func tunnel_shift(cell: Vector2i) -> Vector2:
	if cell.y != TUNNEL_ROW:
		return Vector2.ZERO
	if cell.x < 0:
		return Vector2(MAZE_SIZE.x, 0.0)
	if cell.x >= COLS:
		return Vector2(-MAZE_SIZE.x, 0.0)
	return Vector2.ZERO


## Cell-space equivalent of tunnel_shift.
static func tunnel_shift_cells(cell: Vector2i) -> Vector2i:
	if cell.y != TUNNEL_ROW:
		return Vector2i.ZERO
	if cell.x < 0:
		return Vector2i(COLS, 0)
	if cell.x >= COLS:
		return Vector2i(-COLS, 0)
	return Vector2i.ZERO


static func index(cell: Vector2i) -> int:
	return cell.y * COLS + cell.x


static func same_row_or_col(from: Vector2i, to: Vector2i) -> bool:
	return from.x == to.x or from.y == to.y


## Squared distance, used by the ghost target pickers.
static func distance_sq(from: Vector2i, to: Vector2i) -> int:
	var d := to - from
	return d.x * d.x + d.y * d.y


const DIR_NONE := Vector2i.ZERO
const DIR_UP := Vector2i(0, -1)
const DIR_RIGHT := Vector2i(1, 0)
const DIR_DOWN := Vector2i(0, 1)
const DIR_LEFT := Vector2i(-1, 0)
const DIRECTIONS: Array[Vector2i] = [DIR_UP, DIR_LEFT, DIR_DOWN, DIR_RIGHT]


## "up"/"right"/"down"/"left" for a direction vector, or "" when idle.
static func dir_name(dir: Vector2i) -> String:
	match dir:
		DIR_UP: return "up"
		DIR_RIGHT: return "right"
		DIR_DOWN: return "down"
		DIR_LEFT: return "left"
	return ""
