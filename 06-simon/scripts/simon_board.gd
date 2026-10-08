class_name SimonBoard
## Static geometry of the four-pad disc. Everything is angle-based: a pad is an
## annular sector, so a click is resolved by looking at the angle and radius of
## the point. That is a pure geometry question — giving each pad a collision
## shape would only add a physics cost without making the answer any truer.

const SIZE := Vector2(1280.0, 720.0)
const PAD_COUNT := 4

## Pad order. It matches both the node order in simon.tscn and the arrow keys,
## so reordering the pads means reordering the scene plus these constants.
const PAD_UP := 0
const PAD_RIGHT := 1
const PAD_DOWN := 2
const PAD_LEFT := 3

## Centre angle of each pad in degrees, in pad order. Screen space has +y down,
## so -90 points up.
const PAD_CENTRE_DEG: Array[float] = [-90.0, 0.0, 90.0, 180.0]

static var CENTER := SIZE * 0.5
static var OUTER := 236.0
static var INNER := 96.0
## Degrees one pad opens across (90 minus the slit).
static var SPAN := 85.0


static func configure(outer: float, inner: float, gap_deg: float) -> void:
	OUTER = outer
	INNER = inner
	SPAN = 90.0 - gap_deg
	CENTER = SIZE * 0.5


## Which pad a point falls in, or -1 outside the ring (the hub and the slack
## between pads both answer -1, i.e. "no pad").
static func pad_at(point: Vector2) -> int:
	var offset := point - CENTER
	var distance := offset.length()
	if distance < INNER or distance > OUTER:
		return -1
	return pad_at_angle(rad_to_deg(offset.angle()))


static func pad_at_angle(angle_deg: float) -> int:
	for pad in PAD_COUNT:
		if absf(_delta_deg(PAD_CENTRE_DEG[pad], angle_deg)) <= SPAN * 0.5:
			return pad
	return -1


## Annular sector outline: the outer arc one way, the inner arc back. Local to
## the disc centre, so a pad node sits at CENTER and uses this as-is.
static func pad_polygon(pad: int, segments: int) -> PackedVector2Array:
	var centre := PAD_CENTRE_DEG[pad]
	var half := SPAN * 0.5
	var steps := maxi(2, segments)
	var points := PackedVector2Array()
	for i in steps + 1:
		var t := float(i) / float(steps)
		points.append(Vector2.RIGHT.rotated(deg_to_rad(centre - half + SPAN * t)) * OUTER)
	for i in steps + 1:
		var t := float(i) / float(steps)
		points.append(Vector2.RIGHT.rotated(deg_to_rad(centre + half - SPAN * t)) * INNER)
	return points


## Regular polygon used for the dark hub in the middle of the disc.
static func circle_polygon(radius: float, segments: int) -> PackedVector2Array:
	var count := maxi(3, segments)
	var points := PackedVector2Array()
	for i in count:
		points.append(Vector2.RIGHT.rotated(TAU * float(i) / float(count)) * radius)
	return points


## Shortest signed difference `a - b`, in degrees.
static func _delta_deg(a: float, b: float) -> float:
	return rad_to_deg(angle_difference(deg_to_rad(a), deg_to_rad(b)))
