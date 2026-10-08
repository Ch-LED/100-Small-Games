class_name BreakoutDebug
extends Node2D
## Read-only overlay for `P`: the ball's collision circle and velocity, the
## paddle rect, and the area the ball can bounce inside. It answers "why did
## that shot bounce like that" without touching gameplay.
##
## Everything is drawn in ONE loud colour rather than in each entity's own
## colour: an outline in the entity's colour disappears into the entity it is
## supposed to be describing.
##
## The flag redraws on the way *out* as well: drawing commands are cached on the
## canvas until a redraw is requested, so turning it off without one would leave
## the last frame on screen. Same setter approach as pacman_debug.gd
## (DECISION_LOG 029).

const COLOR := Color("FFE066")
const LINE_WIDTH := 1.5
const ARC_POINTS := 28
const VELOCITY_SCALE := 0.12
const DOT_RADIUS := 2.5

var enabled := false:
	set(value):
		if enabled == value:
			return
		enabled = value
		queue_redraw()

## Pushed by the controller each frame.
var ball_position := Vector2.ZERO
var ball_radius := 9.0
var ball_velocity := Vector2.ZERO
var ball_speed := 0.0
var paddle_rect := Rect2()
var play_rect := Rect2()


func _process(_delta: float) -> void:
	if enabled:
		queue_redraw()


func _draw() -> void:
	if not enabled:
		return
	draw_rect(play_rect, COLOR, false, LINE_WIDTH)
	draw_rect(paddle_rect, COLOR, false, LINE_WIDTH)
	draw_arc(ball_position, ball_radius, 0.0, TAU, ARC_POINTS, COLOR, LINE_WIDTH)

	var tip := ball_position + ball_velocity * ball_speed * VELOCITY_SCALE
	draw_line(ball_position, tip, COLOR, LINE_WIDTH)
	draw_circle(tip, DOT_RADIUS, COLOR)
