class_name SnakeSegment
extends Node2D
## One snake body cell: a centred square block. Pooled by SnakeBody and only
## repositioned / recoloured, never rebuilt mid-run.

@onready var _block: ColorRect = $Block


## `inset` is the gap kept on every side so neighbouring cells stay readable.
func configure(side: float, inset: float, color: Color) -> void:
	var inner := maxf(1.0, side - inset * 2.0)
	_block.size = Vector2(inner, inner)
	_block.position = -_block.size * 0.5
	_block.color = color


func set_color(color: Color) -> void:
	_block.color = color
