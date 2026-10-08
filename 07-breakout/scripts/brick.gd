class_name BreakoutBrick
extends Node2D
## One brick. It holds its own rectangle so the ball can sweep it, and it knows
## whether it has already been broken this frame.

@onready var _face: ColorRect = $Face

var row := 0
var score := 1

var _rect := Rect2()
var _out_of_play := false


## `rect` is in absolute board coordinates (nothing under Board has a transform).
func setup(rect: Rect2, color: Color, row_index: int, value: int) -> void:
	row = row_index
	score = value
	_rect = rect
	_out_of_play = false

	position = rect.position
	_face.position = Vector2.ZERO
	_face.size = rect.size
	_face.color = color
	visible = true


func global_rect() -> Rect2:
	return _rect


## Returns false when this brick is already out of play. The ball sweeps against
## the live bricks each step, and queue_free() only takes effect at the end of
## the frame, so without this flag the same brick could be bounced off twice in
## one frame.
func break_brick() -> bool:
	if _out_of_play:
		return false
	_retire()
	return true


## Takes the brick out of play without any of the "hit" side effects. Used when a
## board is rebuilt: the outgoing bricks must leave the ball's collision set
## immediately, not at the end of the frame.
func retire() -> void:
	_retire()


func is_out_of_play() -> bool:
	return _out_of_play


func _retire() -> void:
	_out_of_play = true
	visible = false
	queue_free()
