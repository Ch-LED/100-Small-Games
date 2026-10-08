class_name Game2048Debug
extends Node2D
## Read-only overlay for `P`: the move count, the empty-cell count, the largest
## tile, and which of the four directions would actually do something. It
## answers "why did nothing happen when I pressed a key" without touching
## gameplay.
##
## The flag redraws on the way *out* as well: drawing commands are cached on the
## canvas until a redraw is requested, so turning it off without one would leave
## the last frame on screen. Same setter approach as pacman_debug.gd
## (DECISION_LOG 029).

## A loud cyan that appears nowhere in the board's palette, so the overlay can be
## pixel-counted on and off.
const COLOR := Color("FF3FA4")
const LEGAL_COLOR := Color("4BD37B")
const BLOCKED_COLOR := Color("8C4A5A")
const FONT_SIZE := 12
const LETTER_GAP := 22.0

## Direction letters in the order the model numbers them: L R U D.
const LETTERS := ["L", "R", "U", "D"]

var enabled := false:
	set(value):
		if enabled == value:
			return
		enabled = value
		queue_redraw()

## Pushed by the controller each frame.
var text := ""
## One bool per direction: whether that move would change the board.
var legal: Array[bool] = [false, false, false, false]
var origin := Vector2.ZERO


func _process(_delta: float) -> void:
	if enabled:
		queue_redraw()


func _draw() -> void:
	if not enabled:
		return
	var font := PixelFont.get_font()
	draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, COLOR)

	# Ask the font how wide the readout actually is instead of guessing from the
	# character count: a guess that comes up short draws the letters on top of
	# the text they are meant to follow.
	var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			FONT_SIZE).x
	var letters_at := origin + Vector2(text_width + LETTER_GAP, 0.0)
	for i in LETTERS.size():
		var color: Color = LEGAL_COLOR if i < legal.size() and legal[i] else BLOCKED_COLOR
		draw_string(font, letters_at + Vector2(float(i) * LETTER_GAP, 0.0),
				LETTERS[i], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)
