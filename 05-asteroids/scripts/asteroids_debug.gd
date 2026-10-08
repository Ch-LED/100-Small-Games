class_name AsteroidsDebug
extends Node2D
## Read-only collision overlay: outlines the actual collision circles and draws
## each rock's velocity. It never touches gameplay, so what you see is exactly
## what the physics sees.

const VELOCITY_SCALE := 0.25
const ARC_POINTS := 32
const LINE_WIDTH := 1.5
const DOT_RADIUS := 2.5

## Toggling must redraw on the way *out* too, otherwise the last drawn frame
## stays on the canvas after the overlay is turned off (drawing commands are
## cached until a redraw is requested). Same fix as `pacman_debug.gd`.
var enabled := false:
	set(value):
		if enabled == value:
			return
		enabled = value
		queue_redraw()

## Snapshot pushed by the controller each frame:
## [{position: Vector2, radius: float, color: Color, velocity: Vector2}]
var shapes: Array[Dictionary] = []


func _process(_delta: float) -> void:
	if enabled:
		queue_redraw()


func _draw() -> void:
	if not enabled:
		return
	for entry in shapes:
		var at: Vector2 = entry["position"]
		var radius: float = entry["radius"]
		var color: Color = entry["color"]
		draw_arc(at, radius, 0.0, TAU, ARC_POINTS, color, LINE_WIDTH)

		var velocity: Vector2 = entry["velocity"]
		if velocity.length() > 1.0:
			var tip := at + velocity * VELOCITY_SCALE
			draw_line(at, tip, color, LINE_WIDTH)
			draw_circle(tip, DOT_RADIUS, color)
