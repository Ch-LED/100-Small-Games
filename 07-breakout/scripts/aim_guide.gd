class_name BreakoutAimGuide
extends Node2D
## The fan over the paddle's top half showing where the ball is about to go.
##
## It only paints what the controller hands it: an origin (the top of the
## paddle), a centre angle and a half-width. It computes nothing about the ball
## itself, so it cannot quietly disagree with the bounce it is predicting.
##
## Two nested wedges, not one: a faint outer one for "it could go anywhere in
## here" and a firmer core for "most likely about here". That is what makes the
## spread read as uncertainty rather than as a measurement.
##
## The flag redraws on the way *out* as well: drawing commands are cached on the
## canvas until a redraw is requested, so switching the fan off without one would
## leave the last fan on screen. Same setter approach as pacman_debug.gd
## (DECISION_LOG 029).

var enabled := false:
	set(value):
		if enabled == value:
			return
		enabled = value
		queue_redraw()

var _origin := Vector2.ZERO
var _from := 0.0
var _to := 0.0
var _radius := 86.0
var _segments := 16
var _core_ratio := 0.45
var _fill := Color(1, 1, 1, 0.22)
var _core := Color(1, 1, 1, 0.5)
var _edge := Color(1, 1, 1, 0.55)


func configure(radius: float, color: Color, alpha: float, core_alpha: float,
		outline_alpha: float, segments: int, core_ratio: float) -> void:
	_radius = radius
	_segments = maxi(2, segments)
	_core_ratio = clampf(core_ratio, 0.1, 0.95)
	_fill = Color(color.r, color.g, color.b, alpha)
	_core = Color(color.r, color.g, color.b, core_alpha)
	_edge = Color(color.r, color.g, color.b, outline_alpha)


## `half_width` is in radians; the fan would span `angle ± half_width`.
func set_fan(origin: Vector2, angle: float, half_width: float) -> void:
	_origin = origin
	# Never paint below the paddle's horizon. The real bounce always leaves
	# upward (see BreakoutBall.with_min_angle), so a fan reaching below the
	# horizontal would only overstate the uncertainty.
	_from = clampf(angle - half_width, -PI, 0.0)
	_to = clampf(angle + half_width, -PI, 0.0)
	if enabled:
		queue_redraw()


func _draw() -> void:
	if not enabled or _to <= _from:
		return
	draw_colored_polygon(_wedge(_from, _to), _fill)
	var middle := (_from + _to) * 0.5
	var half := (_to - _from) * 0.5 * _core_ratio
	draw_colored_polygon(_wedge(middle - half, middle + half), _core)
	draw_polyline(_wedge(_from, _to), _edge, 2.0)


## The fan outline: the origin, then the arc, so a polyline through the points
## draws both straight edges and the curve.
func _wedge(from_angle: float, to_angle: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.append(_origin)
	for i in _segments + 1:
		var t := float(i) / float(_segments)
		out.append(_origin + Vector2.RIGHT.rotated(lerpf(from_angle, to_angle, t)) * _radius)
	return out
