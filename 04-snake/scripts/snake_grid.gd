class_name SnakeGrid
## Grid geometry: COLS x ROWS cells of CELL px, centred in the 1280x720 field.
## Everything (board, snake, food) works in cell coords and converts here.

const FIELD := Vector2(1280.0, 720.0)

const DIR_NONE := Vector2i.ZERO
const DIR_UP := Vector2i(0, -1)
const DIR_RIGHT := Vector2i(1, 0)
const DIR_DOWN := Vector2i(0, 1)
const DIR_LEFT := Vector2i(-1, 0)
const DIRECTIONS: Array[Vector2i] = [DIR_UP, DIR_LEFT, DIR_DOWN, DIR_RIGHT]

## Set once at boot via configure() before any layout happens.
static var CELL := 40.0
static var COLS := 30
static var ROWS := 15
static var BOARD_SIZE := Vector2(COLS, ROWS) * CELL
## Top-left of the board in field coordinates. The margins it leaves are the
## HUD band (top) and the same amount again below, keeping the board centred.
static var ORIGIN := (FIELD - BOARD_SIZE) * 0.5


static func configure(cell_size: float, cols: int, rows: int) -> void:
	CELL = cell_size
	COLS = cols
	ROWS = rows
	BOARD_SIZE = Vector2(COLS, ROWS) * CELL
	ORIGIN = (FIELD - BOARD_SIZE) * 0.5


## Centre of a cell in field coordinates.
static func cell_center(cell: Vector2i) -> Vector2:
	return ORIGIN + (Vector2(cell) + Vector2(0.5, 0.5)) * CELL


static func cell_of(local: Vector2) -> Vector2i:
	return Vector2i(((local - ORIGIN) / CELL).floor())


static func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < COLS and cell.y >= 0 and cell.y < ROWS


## Wraps a cell to the opposite edge (only used when wrap_edges is on).
static func wrap(cell: Vector2i) -> Vector2i:
	return Vector2i(posmod(cell.x, COLS), posmod(cell.y, ROWS))


static func index(cell: Vector2i) -> int:
	return cell.y * COLS + cell.x


static func dir_from_name(name: String) -> Vector2i:
	match name:
		"up": return DIR_UP
		"right": return DIR_RIGHT
		"down": return DIR_DOWN
		"left": return DIR_LEFT
	return DIR_NONE


static func dir_name(dir: Vector2i) -> String:
	match dir:
		DIR_UP: return "up"
		DIR_RIGHT: return "right"
		DIR_DOWN: return "down"
		DIR_LEFT: return "left"
	return ""


static func is_opposite(a: Vector2i, b: Vector2i) -> bool:
	return a != DIR_NONE and b != DIR_NONE and a == -b
