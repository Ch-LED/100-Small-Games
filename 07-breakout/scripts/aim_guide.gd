class_name BreakoutAimGuide
extends Node2D
## A fixed legend on the paddle: a handful of short rays, one per contact point,
## showing which way the ball leaves for each. It says nothing about the ball in
## flight — that is the point.
##
## A live fan was tried first and thrown out in playtesting: a readout that
## shifts while you are already steering with it costs attention and jumps
## around as the ball closes in (DECISION_LOG 043). What was actually missing was
## not a prediction but a way to see the mapping, and a mapping only has to be
## learned once.
##
## It only paints the rays the controller hands it; it computes no angles itself.
##
## The flag redraws on the way *out* as well: drawing commands are cached on the
## canvas until a redraw is requested, so switching the legend off without one
## would leave the last rays on screen. Same setter approach as pacman_debug.gd
## (DECISION_LOG 029).

const DOT_RADIUS := 2.5

var enabled := false:
	set(value):
		if enabled == value:
			return
		enabled = value
		queue_redraw()

## [{origin: Vector2, direction: Vector2}, ...]
var _rays: Array[Dictionary] = []
var _length := 70.0
var _color := Color(1, 1, 1, 0.3)
var _width := 2.0


func configure(length: float, color: Color, alpha: float, width: float) -> void:
	_length = length
	_color = Color(color.r, color.g, color.b, alpha)
	_width = width


func set_rays(rays: Array[Dictionary]) -> void:
	_rays = rays
	if enabled:
		queue_redraw()


func _draw() -> void:
	if not enabled:
		return
	for ray in _rays:
		var origin: Vector2 = ray["origin"]
		var direction: Vector2 = ray["direction"]
		draw_line(origin, origin + direction * _length, _color, _width)
		# A dot marks the contact point itself, so the ray reads as "hit here".
		draw_circle(origin, DOT_RADIUS, _color)
