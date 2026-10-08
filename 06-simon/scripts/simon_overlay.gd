class_name SimonOverlay
extends Node2D
## The two optional read-only overlays:
##   `[` (cheat) draws the current sequence as coloured dots — PEEK.
##   `P` (debug) draws a one-line state readout.
## Neither touches gameplay; they only render what the controller hands them.
##
## Both flags redraw on the way *out* as well. Drawing commands are cached on
## the canvas until a redraw is requested, so turning an overlay off without one
## would leave its last frame on screen — it would look frozen, not hidden.
## This is the same setter approach as 03-pacman/scripts/pacman_debug.gd
## (DECISION_LOG 029).

const STATE_COLOR := Color("8FA3BF")
const PEEK_FADED_ALPHA := 0.35

var show_peek := false:
	set(value):
		if show_peek == value:
			return
		show_peek = value
		queue_redraw()

var show_state := false:
	set(value):
		if show_state == value:
			return
		show_state = value
		queue_redraw()

## Pushed by the controller.
var sequence: Array[int] = []
var pad_colors: Array[Color] = []
## How many of the dots the player has already reproduced.
var peek_progress := 0
var state_text := ""

var _dot_size := 14.0
var _dot_gap := 8.0
var _dot_y_margin := 64.0
var _font_size := 10
var _state_x := 10.0
var _state_y := 72.0


func configure(cfg: Dictionary) -> void:
	var overlay: Dictionary = cfg.overlay
	_dot_size = float(overlay.dot_size)
	_dot_gap = float(overlay.dot_gap)
	_dot_y_margin = float(overlay.dot_y_margin)
	_font_size = int(overlay.state_font_size)
	_state_x = float(overlay.state_x)
	_state_y = float(overlay.state_y)


func _process(_delta: float) -> void:
	if show_peek or show_state:
		queue_redraw()


func _draw() -> void:
	if show_state:
		_draw_state()
	if show_peek:
		_draw_peek()


func _draw_state() -> void:
	if state_text.is_empty():
		return
	draw_string(PixelFont.get_font(), Vector2(_state_x, _state_y),
			state_text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, STATE_COLOR)


## A row of dots under the disc: full colour for the steps already reproduced,
## faded for the ones still to come.
func _draw_peek() -> void:
	if sequence.is_empty():
		return
	var step := _dot_size + _dot_gap
	var total := float(sequence.size()) * step - _dot_gap
	var left := (SimonBoard.SIZE.x - total) * 0.5
	var top := SimonBoard.SIZE.y - _dot_y_margin

	for i in sequence.size():
		var color := _pad_color(sequence[i])
		if i >= peek_progress:
			color.a = PEEK_FADED_ALPHA
		draw_rect(Rect2(left + float(i) * step, top, _dot_size, _dot_size), color, true)


func _pad_color(pad: int) -> Color:
	if pad < 0 or pad >= pad_colors.size():
		return Color.WHITE
	return pad_colors[pad]
