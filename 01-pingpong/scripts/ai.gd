class_name PongAi
extends Node
## Throttled AI (decision log 010): each cooldown the pending direction lands
## on the paddle, then a fresh sample starts the next cooldown. So the paddle
## chases a target that is about one cooldown old — a readable 0.3-0.5s lag.
## When cooldown_enabled is off the delay collapses and the AI tracks in real
## time.

var _cooldown_enabled := true
var _reaction_min := 0.3
var _reaction_max := 0.5
var _dead_zone := 6.0
var _ball: PongBall
var _paddle: PongPaddle
var _cooldown := 0.0
var _pending := 0


func setup(ball: PongBall, paddle: PongPaddle, ai_cfg: Dictionary) -> void:
	_ball = ball
	_paddle = paddle
	_cooldown_enabled = ai_cfg.cooldown_enabled
	_reaction_min = ai_cfg.reaction_min
	_reaction_max = ai_cfg.reaction_max
	_dead_zone = ai_cfg.dead_zone


func _physics_process(delta: float) -> void:
	if _cooldown_enabled:
		if _cooldown > 0.0:
			_cooldown -= delta
			return

	_paddle.set_target(_pending)

	var dy := _ball.global_position.y - _paddle.global_position.y
	_pending = 0
	if absf(dy) > _dead_zone:
		_pending = 1 if dy > 0.0 else -1
	if _cooldown_enabled:
		_cooldown = randf_range(_reaction_min, _reaction_max)
