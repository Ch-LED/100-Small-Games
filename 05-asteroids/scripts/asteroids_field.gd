class_name AsteroidsField
## Fixed logical playfield. canvas_items stretch maps it to the window, so
## gameplay layout stays deterministic regardless of window size or aspect.
##
## There are no walls: every moving thing is folded back into the field, so it
## leaves one edge and appears at the opposite one.

const SIZE := Vector2(1280.0, 720.0)


## Folds a point back into the field. fposmod (rather than a one-shot shift when
## crossing) is what makes an object appear at the far edge as it leaves this
## one, which is how the arcade original reads.
static func wrap_point(point: Vector2) -> Vector2:
	return Vector2(fposmod(point.x, SIZE.x), fposmod(point.y, SIZE.y))


## Random point at least `margin` away from every edge.
static func random_point(margin: float) -> Vector2:
	return Vector2(
			randf_range(margin, SIZE.x - margin),
			randf_range(margin, SIZE.y - margin))


## Shortest delta from `from` to `to` across the wrap, so distance checks and
## aiming do not treat the seam as a gap.
static func wrapped_delta(from: Vector2, to: Vector2) -> Vector2:
	var delta := to - from
	if absf(delta.x) > SIZE.x * 0.5:
		delta.x -= signf(delta.x) * SIZE.x
	if absf(delta.y) > SIZE.y * 0.5:
		delta.y -= signf(delta.y) * SIZE.y
	return delta


static func wrapped_distance(from: Vector2, to: Vector2) -> float:
	return wrapped_delta(from, to).length()
