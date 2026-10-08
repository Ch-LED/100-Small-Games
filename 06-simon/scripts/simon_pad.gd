class_name SimonPad
extends Node2D
## One annular sector of the disc. It only knows how to look dim or lit — the
## controller decides when.

@onready var _face: Polygon2D = $Face

var index := 0

var _dim := Color.WHITE
var _lit := Color.WHITE
var _is_lit := false


## At rest the pad is its colour darkened by `dim_amount`; lit it is the colour
## at full strength. Going the other way (brightening the lit state toward
## white) washes the hue out — red reads as pink, i.e. "faded" not "lit".
func setup(pad_index: int, color: Color, dim_amount: float, segments: int) -> void:
	index = pad_index
	position = SimonBoard.CENTER
	_dim = color.darkened(dim_amount)
	_lit = color
	_face.polygon = SimonBoard.pad_polygon(pad_index, segments)
	_face.color = _dim
	_is_lit = false


## Only the colour changes when lit, never the shape: lighting up has to read at
## a glance without the pad visibly jumping.
func set_lit(on: bool) -> void:
	if _is_lit == on:
		return
	_is_lit = on
	_face.color = _lit if on else _dim


func is_lit() -> bool:
	return _is_lit
