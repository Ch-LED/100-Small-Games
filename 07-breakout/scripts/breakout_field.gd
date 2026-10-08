class_name BreakoutField
## Static geometry: the play area the ball bounces inside, the three wall rects,
## and the brick grid metrics.
##
## The brick width is DERIVED from the column count and the play area width, so
## changing `cols` or `margin_x` re-tiles the board with no other edit.

const SIZE := Vector2(1280.0, 720.0)

static var LEFT := 40.0
static var RIGHT := 1240.0
static var TOP := 40.0
static var WALL_THICKNESS := 40.0
static var BRICK_SIZE := Vector2(80.0, 26.0)
static var BRICK_GAP := 6.0
static var BRICK_TOP := 120.0
static var COLS := 14
static var ROWS := 8


## `rows` is passed in rather than read from cfg here, so the single source of
## the row count stays the brick tables in `BreakoutGame`.
static func configure(field: Dictionary, rows: int) -> void:
	LEFT = float(field.margin_x)
	RIGHT = SIZE.x - float(field.margin_x)
	TOP = float(field.wall_top)
	WALL_THICKNESS = float(field.wall_thickness)
	BRICK_GAP = float(field.brick_gap)
	BRICK_TOP = TOP + float(field.brick_top)
	COLS = int(field.cols)
	ROWS = rows

	var usable: float = (RIGHT - LEFT) - float(COLS - 1) * BRICK_GAP
	BRICK_SIZE = Vector2(usable / float(COLS), float(field.brick_height))


## Where one brick sits. Absolute board coordinates: nothing under Board has a
## transform, so local and global are the same thing here.
static func brick_rect(row: int, col: int) -> Rect2:
	return Rect2(
			LEFT + float(col) * (BRICK_SIZE.x + BRICK_GAP),
			BRICK_TOP + float(row) * (BRICK_SIZE.y + BRICK_GAP),
			BRICK_SIZE.x, BRICK_SIZE.y)


## The three walls as rects, so the ball sweeps them with the same code it uses
## for the paddle and the bricks. They sit just outside the play area; their
## inner faces are exactly LEFT / RIGHT / TOP.
static func wall_rects() -> Array[Rect2]:
	var t := WALL_THICKNESS
	var height: float = SIZE.y - TOP + 2.0 * t
	return [
		Rect2(LEFT - t, TOP - t, t, height),
		Rect2(RIGHT, TOP - t, t, height),
		Rect2(LEFT - t, TOP - t, RIGHT - LEFT + 2.0 * t, t),
	]


## The bounce area, for the debug overlay.
static func play_rect() -> Rect2:
	return Rect2(LEFT, TOP, RIGHT - LEFT, SIZE.y - TOP)


## How far down the brick block reaches, used to sanity-check the layout.
static func brick_block_bottom() -> float:
	return BRICK_TOP + float(ROWS) * BRICK_SIZE.y + float(ROWS - 1) * BRICK_GAP
