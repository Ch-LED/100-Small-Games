class_name PongBarrier
extends Area2D
## A passive strip (top/bottom wall or a scoring zone behind the paddles).
## It never monitors: the ball senses it. Game drives its size, centre and
## colour; the collision shape and the visual always share the same box.

@onready var _collision: CollisionShape2D = $Collision
@onready var _visual: ColorRect = $Visual

var _color := Color.WHITE


func set_color(color: Color) -> void:
	_color = color
	_visual.color = color


## Resizes both the collision box and the visual to one shared rectangle,
## centred on this node.
func set_strip(strip_size: Vector2, center: Vector2) -> void:
	position = center
	var shape := _collision.shape as RectangleShape2D
	shape.size = strip_size
	_visual.size = strip_size
	_visual.position = -strip_size * 0.5
	_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE


## The strip as a world-space box; the ball sweeps against this instead of
## relying on area signals (see ball.gd).
func global_rect() -> Rect2:
	var box := (_collision.shape as RectangleShape2D).size
	return Rect2(global_position - box * 0.5, box)
