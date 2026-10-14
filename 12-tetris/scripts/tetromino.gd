class_name Tetromino
extends RefCounted

## Shape, orientation and wall-kick data for the seven tetrominoes.
##
## Two coordinate conventions meet in this file and they must not be mixed up:
##
##   * Orientation cells use MATRIX ROWS -- row 0 is at the top, which is how
##     the pieces are drawn and how the board indexes them.
##   * The SRS wall-kick tables are published with y pointing UP. KICK_JLSTZ
##     and KICK_I below therefore hold the published numbers verbatim, and
##     kick_offsets() flips y on the way out.
##
## Flipping the tables in place instead would be a silent way to break exactly
## one direction of one rotation, and no amount of re-reading the table catches
## that -- only a test does.

enum Kind { I, O, T, S, Z, J, L }

const KIND_COUNT := 7
const ROTATIONS := 4

## One letter per kind, in Kind order. For the debug overlay's readout, which
## wants to say which piece is in flight in as few characters as possible.
const KIND_LETTERS := ["I", "O", "T", "S", "Z", "J", "L"]

## Bounding box edge, per kind. I and O get their own because their published
## shapes do not fit a 3x3 box.
const BOX_SIZE := {
	Kind.I: 4,
	Kind.O: 2,
	Kind.T: 3,
	Kind.S: 3,
	Kind.Z: 3,
	Kind.J: 3,
	Kind.L: 3,
}

## Cells at rotation 0, in matrix rows, inside each kind's own bounding box.
const BASE_CELLS := {
	Kind.I: [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)],
	Kind.O: [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
	Kind.T: [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
	Kind.S: [Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1)],
	Kind.Z: [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)],
	Kind.J: [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
	Kind.L: [Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
}

## SRS wall kicks, JLSTZ. Key is `from_rotation * ROTATIONS + to_rotation`.
## Values are the published ones: y points UP.
##
## Several rows repeat verbatim (R->0 and R->2, for instance). That is not a
## copy-paste slip -- SRS really does share one test set between the clockwise
## and counter-clockwise trip out of the same orientation. Do not "fix" it.
const KICK_JLSTZ := {
	1: [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, -2), Vector2i(-1, -2)],
	4: [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, 2), Vector2i(1, 2)],
	6: [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, 2), Vector2i(1, 2)],
	9: [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, -2), Vector2i(-1, -2)],
	11: [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, -2), Vector2i(1, -2)],
	14: [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, 2), Vector2i(-1, 2)],
	12: [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, 2), Vector2i(-1, 2)],
	3: [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, -2), Vector2i(1, -2)],
}

## SRS wall kicks, I. Same key scheme, same y-up convention.
const KICK_I := {
	1: [Vector2i(0, 0), Vector2i(-2, 0), Vector2i(1, 0), Vector2i(-2, -1), Vector2i(1, 2)],
	4: [Vector2i(0, 0), Vector2i(2, 0), Vector2i(-1, 0), Vector2i(2, 1), Vector2i(-1, -2)],
	6: [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(2, 0), Vector2i(-1, 2), Vector2i(2, -1)],
	9: [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-2, 0), Vector2i(1, -2), Vector2i(-2, 1)],
	11: [Vector2i(0, 0), Vector2i(2, 0), Vector2i(-1, 0), Vector2i(2, 1), Vector2i(-1, -2)],
	14: [Vector2i(0, 0), Vector2i(-2, 0), Vector2i(1, 0), Vector2i(-2, -1), Vector2i(1, 2)],
	12: [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-2, 0), Vector2i(1, -2), Vector2i(-2, 1)],
	3: [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(2, 0), Vector2i(-1, 2), Vector2i(2, -1)],
}


## The four cells around a T's bounding-box centre. Whether they are occupied
## is the geometric half of T-spin detection; the other half -- "the last thing
## that happened was a rotation" -- belongs to the play session.
##
## Keeping the ring here rather than in the board means the board only has to
## ask "is this cell taken", which it already knows how to answer.
const T_CORNER_RING := [Vector2i(0, 0), Vector2i(2, 0), Vector2i(0, 2), Vector2i(2, 2)]

## Index order into T_CORNER_RING, one row per rotation, nub-side pair first.
const T_CORNER_ORDER := [
	[0, 1, 2, 3],
	[1, 3, 0, 2],
	[3, 2, 1, 0],
	[2, 0, 3, 1],
]


## The four corners around a T's centre, ordered so the first two are the pair
## on the side the nub points at. Only meaningful for Kind.T.
static func t_corners(rotation: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for index in T_CORNER_ORDER[wrapi(rotation, 0, ROTATIONS)]:
		result.append(T_CORNER_RING[index])
	return result


## Cells of `kind` at `rotation`, in the piece's own bounding box.
static func cells(kind: Kind, rotation: int) -> Array[Vector2i]:
	var size: int = BOX_SIZE[kind]
	var normalized := wrapi(rotation, 0, ROTATIONS)
	var base: Array = BASE_CELLS[kind]
	var result: Array[Vector2i] = []
	for entry in base:
		var point: Vector2i = entry
		for _turn in normalized:
			point = Vector2i(size - 1 - point.y, point.x)
		result.append(point)
	return result


## Where the bounding box sits when the piece is freshly dealt. Only x is
## meaningful here; the row comes from the board's spawn line.
static func spawn_offset(kind: Kind) -> Vector2i:
	match kind:
		Kind.I:
			return Vector2i(3, 0)
		Kind.O:
			return Vector2i(4, 0)
		_:
			return Vector2i(3, 0)


static func rotation_step(from_rotation: int, clockwise: bool) -> int:
	var delta := 1 if clockwise else -1
	return wrapi(from_rotation + delta, 0, ROTATIONS)


## Kick offsets for one rotation, in BOARD coordinates (y already flipped).
## Empty for O, which never kicks.
static func kick_offsets(kind: Kind, from_rotation: int, to_rotation: int) -> Array[Vector2i]:
	var published: Array = _published_kicks(kind, from_rotation, to_rotation)
	var result: Array[Vector2i] = []
	for entry in published:
		var offset: Vector2i = entry
		result.append(Vector2i(offset.x, -offset.y))
	return result


static func _published_kicks(kind: Kind, from_rotation: int, to_rotation: int) -> Array:
	if kind == Kind.O:
		return [Vector2i(0, 0)]
	var from := wrapi(from_rotation, 0, ROTATIONS)
	var to := wrapi(to_rotation, 0, ROTATIONS)
	var table: Dictionary = KICK_I if kind == Kind.I else KICK_JLSTZ
	var key := from * ROTATIONS + to
	# SRS only publishes tests for a single 90 degree step. A two-step turn
	# (0 -> 2) has no row, and in play cannot happen -- every rotation goes
	# through rotation_step(), which moves by one. Fail loudly rather than
	# spin in place on a table lookup that will never grow.
	if not table.has(key):
		push_error("SRS kick table has no row for %d -> %d" % [from, to])
		return [Vector2i(0, 0)]
	return table[key]
