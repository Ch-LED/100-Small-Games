class_name BreakoutPaddle
extends Node2D
## The paddle. Two controls share it: the keyboard sets a direction, the mouse
## sets a target x. Whichever moved last wins — the controller decides which.

@onready var _face: ColorRect = $Face

var half_width := 70.0
var half_height := 9.0

var _width := 140.0
var _base_width := 140.0
var _height := 18.0
var _max_speed := 900.0
var _direction := 0.0
var _target_x := 0.0
var _following_pointer := false


func setup(paddle_cfg: Dictionary, face_color: Color) -> void:
	_height = float(paddle_cfg.height)
	_max_speed = float(paddle_cfg.max_speed)
	_direction = 0.0
	_following_pointer = false
	_face.color = face_color
	position = Vector2(BreakoutField.SIZE.x * 0.5,
			BreakoutField.SIZE.y - float(paddle_cfg.bottom_margin))
	_base_width = float(paddle_cfg.width)
	_set_width(_base_width)


## Absolute board rect, which is what the ball sweeps against.
func global_rect() -> Rect2:
	return Rect2(position - Vector2(half_width, half_height), Vector2(_width, _height))


func set_direction(direction: float) -> void:
	_direction = clampf(direction, -1.0, 1.0)
	_following_pointer = false


## Hands control to the pointer at `x`.
func follow_pointer(x: float) -> void:
	_target_x = x
	_following_pointer = true


func is_following_pointer() -> bool:
	return _following_pointer


## Also the cheat: a wider paddle is all it takes to make the game easy.
func set_width_scale(scale: float) -> void:
	_set_width(_base_width * scale)


func center_x() -> float:
	return position.x


func _process(delta: float) -> void:
	if _following_pointer:
		# Chase the pointer, but never faster than the keyboard could move.
		var limit := _max_speed * delta
		position.x += clampf(_target_x - position.x, -limit, limit)
	elif not is_zero_approx(_direction):
		position.x += _direction * _max_speed * delta
	position.x = clampf(position.x,
			BreakoutField.LEFT + half_width, BreakoutField.RIGHT - half_width)


func _set_width(width: float) -> void:
	_width = maxf(8.0, width)
	half_width = _width * 0.5
	half_height = _height * 0.5
	_face.size = Vector2(_width, _height)
	_face.position = Vector2(-half_width, -half_height)
	# Widening at the rim would leave the paddle half outside the play area.
	position.x = clampf(position.x,
			BreakoutField.LEFT + half_width, BreakoutField.RIGHT - half_width)
