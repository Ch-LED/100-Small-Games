class_name BreakoutPaddle
extends Node2D
## The paddle. Two controls share it: the keyboard sets a direction, the mouse
## sets a target x. Whichever moved last wins — the controller decides which.
##
## It also owns the swing: a quick lunge upward that smashes the ball back, then
## a decelerating retract during which a landing ball is caught instead of
## bounced. See swing() for why the collision box steps rather than slides.

## LUNGE = box up (a hit smashes); RETRACT = box back at rest (a hit catches).
enum Swing { NONE, LUNGE, RETRACT }

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

var _swing: int = Swing.NONE
var _swing_timer := 0.0
var _reach := 54.0
var _lunge_time := 0.16
var _retract_time := 0.22
var _rise_time := 0.05
## How far the drawn face is from its resting place. Pure animation; the
## collision box uses box_offset() instead.
var _visual_offset := 0.0


func setup(paddle_cfg: Dictionary, face_color: Color) -> void:
	_height = float(paddle_cfg.height)
	_max_speed = float(paddle_cfg.max_speed)
	_reach = float(paddle_cfg.swing_reach)
	_lunge_time = float(paddle_cfg.swing_lunge_time)
	_retract_time = float(paddle_cfg.swing_retract_time)
	_rise_time = float(paddle_cfg.swing_rise_time)
	_direction = 0.0
	_following_pointer = false
	_swing = Swing.NONE
	_swing_timer = 0.0
	_visual_offset = 0.0
	_face.color = face_color
	position = Vector2(BreakoutField.SIZE.x * 0.5,
			BreakoutField.SIZE.y - float(paddle_cfg.bottom_margin))
	_base_width = float(paddle_cfg.width)
	_set_width(_base_width)


## Absolute board rect, which is what the ball sweeps against. Its y already
## includes the swing, so the ball always meets the box where the swing put it.
func global_rect() -> Rect2:
	var offset := Vector2(0.0, box_offset())
	return Rect2(position - Vector2(half_width, half_height) + offset,
			Vector2(_width, _height))


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


# --- swing ---# --- swing ------------------------------------------------------------------

## Starts the lunge. Returns false when one is already running, so the key can
## be held without stacking them up.
func swing() -> bool:
	if _swing != Swing.NONE:
		return false
	_swing = Swing.LUNGE
	_swing_timer = _lunge_time
	return true


func is_swinging() -> bool:
	return _swing != Swing.NONE


## True on the way back: the window in which a ball landing on the paddle is
## caught rather than bounced.
func is_retracting() -> bool:
	return _swing == Swing.RETRACT


## Where the collision box sits right now, relative to the resting place.
##
## ⚠️ A STEP, not a slide, and deliberately so: for the whole lunge the box is
## at the raised position and for the whole retract it is back at rest. Sliding
## it would mean the ball can meet a box that is somewhere other than where the
## paddle looks, and at these speeds that reads as a phantom hit.
func box_offset() -> float:
	match _swing:
		Swing.LUNGE:
			return -_reach
		Swing.RETRACT:
			return 0.0
	return 0.0


func _tick_swing(delta: float) -> void:
	match _swing:
		Swing.LUNGE:
			_swing_timer -= delta
			var elapsed := _lunge_time - maxf(0.0, _swing_timer)
			var t := clampf(elapsed / maxf(0.001, _rise_time), 0.0, 1.0)
			# Snaps up and settles: the lunge has to read as a strike.
			_visual_offset = -_reach * (1.0 - pow(1.0 - t, 3.0))
			if _swing_timer <= 0.0:
				_swing = Swing.RETRACT
				_swing_timer = _retract_time
		Swing.RETRACT:
			_swing_timer -= delta
			var elapsed := _retract_time - maxf(0.0, _swing_timer)
			var t := clampf(elapsed / maxf(0.001, _retract_time), 0.0, 1.0)
			# Decelerating: fast at first, gentle as it settles back.
			_visual_offset = -_reach * pow(1.0 - t, 2.0)
			if _swing_timer <= 0.0:
				_swing = Swing.NONE
				_visual_offset = 0.0
	_face.position.y = -half_height + _visual_offset


func _process(delta: float) -> void:
	_tick_swing(delta)
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
