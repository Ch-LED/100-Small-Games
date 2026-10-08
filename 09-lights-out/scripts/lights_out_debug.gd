class_name LightsOutDebug
extends Node2D
## Read-only overlay for `P`: how many presses this puzzle has taken, how many
## lights are still lit, and the fewest presses that could still finish it. It
## reports numbers only — never positions — so it is a diagnostic rather than a
## spoiler (the `[` overlay is the one that gives the answer away).
##
## The flag redraws on the way *out* as well: drawing commands are cached on the
## canvas until a redraw is requested, so turning it off without one would leave
## the last frame on screen. Same setter approach as pacman_debug.gd
## (DECISION_LOG 029).

## A loud colour that appears nowhere in the board palette, so the overlay can be
## pixel-counted on and off.
const COLOR := Color("FF3FA4")
const FONT_SIZE := 12

var enabled := false:
	set(value):
		if enabled == value:
			return
		enabled = value
		queue_redraw()

var text := ""
var origin := Vector2.ZERO


func _process(_delta: float) -> void:
	if enabled:
		queue_redraw()


func _draw() -> void:
	if not enabled or text.is_empty():
		return
	draw_string(PixelFont.get_font(), origin, text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, COLOR)
