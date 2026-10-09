class_name SnakeFood
extends Node2D
## A single food cell. Pulses gently so it reads as "collect me".

const SIZE_RATIO := 0.72

@onready var _block: ColorRect = $Block

var _pulse_speed := 5.0
var _pulse_min := 0.75
var _time := 0.0


func configure(cell: Vector2i, side: float, color: Color,
		pulse_speed: float, pulse_min: float) -> void:
	var inner := maxf(1.0, side * SIZE_RATIO)
	_block.size = Vector2(inner, inner)
	_block.position = -_block.size * 0.5
	_block.color = color
	_pulse_speed = pulse_speed
	_pulse_min = pulse_min
	_time = 0.0
	scale = Vector2.ONE
	position = SnakeGrid.cell_center(cell)


func cell() -> Vector2i:
	return SnakeGrid.cell_of(position)


## Steps to another cell without disturbing the pulse, so a food that walks
## reads as one food moving rather than as food being respawned.
func move_to(cell: Vector2i) -> void:
	position = SnakeGrid.cell_center(cell)


## Recolours in place. Used by the super cheat, which re-dresses the food.
func set_color(color: Color) -> void:
	_block.color = color


func _process(delta: float) -> void:
	_time += delta
	var wave := 0.5 + 0.5 * sin(_time * _pulse_speed)
	scale = Vector2.ONE * lerpf(_pulse_min, 1.0, wave)
