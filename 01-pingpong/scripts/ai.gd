class_name PongAi
extends Node
## Paddle AI: eases toward the ball's y with exponential smoothing, so the
## pursuit is continuous rather than a stepped command queue.
##
## `follow_rate` is the tuning knob — it is how fast the paddle closes the
## remaining gap, so higher values chase tighter and lower values are easier
## to beat. `dead_zone` stops it jittering once it is roughly lined up.

var _follow_rate := 6.0
var _dead_zone := 6.0
var _ball: PongBall
var _paddle: PongPaddle


func setup(ball: PongBall, paddle: PongPaddle, ai_cfg: Dictionary) -> void:
	_ball = ball
	_paddle = paddle
	_follow_rate = ai_cfg.follow_rate
	_dead_zone = ai_cfg.dead_zone


func _physics_process(delta: float) -> void:
	var ball_y := _ball.global_position.y
	var dy := ball_y - _paddle.global_position.y
	if absf(dy) <= _dead_zone:
		return
	# 1 - exp(-k*dt) closes the same fraction of the gap per second whatever
	# the frame rate, unlike a raw lerp weight.
	var t := 1.0 - exp(-_follow_rate * delta)
	_paddle.ease_toward(ball_y, t)
