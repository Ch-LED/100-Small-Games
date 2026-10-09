class_name BreakoutBrick
extends Node2D
## One brick. It holds its own rectangle so the ball can sweep it, how many
## layers it has left, and whether it is already out of play this frame.
##
## A brick with more than one layer stays put when hit and takes on the look of
## the layer underneath, so damage is visible rather than counted.

@onready var _face: ColorRect = $Face

## Layers left. Never 0 for a live brick: the last hit retires it.
var hp := 1

var _layer_colors: Array[Color] = []
var _rect := Rect2()
var _out_of_play := false


## `hits` is the level file's digit; `layer_colors[i]` is the look of a brick with
## `i + 1` layers left, so the palette is indexed by remaining layers, not by row.
func setup(rect: Rect2, layer_colors: Array[Color], hits: int) -> void:
	_layer_colors = layer_colors
	hp = clampi(hits, 1, maxi(1, layer_colors.size()))
	_rect = rect
	_out_of_play = false

	position = rect.position
	_face.position = Vector2.ZERO
	_face.size = rect.size
	_paint()
	visible = true


func global_rect() -> Rect2:
	return _rect


## The colour it currently wears. The shards of a hit are thrown in this colour,
## so they match the layer that just came off.
func color() -> Color:
	return _face.color


## One hit. Returns true when that was the last layer and the brick is gone.
##
## A surviving brick must still bounce the ball: the ball reflects off whatever
## it hit, and "chipped but standing" is still a thing it hit.
func hit() -> bool:
	if _out_of_play:
		return false
	hp -= 1
	if hp <= 0:
		_retire()
		return true
	_paint()
	return false


## Takes the brick out of play without any of the "hit" side effects. Used when a
## board is rebuilt: the outgoing bricks must leave the ball's collision set
## immediately, not at the end of the frame.
func retire() -> void:
	_retire()


func is_out_of_play() -> bool:
	return _out_of_play


func _paint() -> void:
	_face.color = _layer_colors[clampi(hp - 1, 0, _layer_colors.size() - 1)]


func _retire() -> void:
	_out_of_play = true
	visible = false
	queue_free()
