class_name PongBall
extends Area2D
## The ball: sole Area2D with monitoring enabled. It identifies what it
## touched by comparing against named sibling nodes via @onready references.

signal scored(side: String)

const MAX_DIR_Y := 0.97

@onready var _paddle_left: PongPaddle = $"../PaddleLeft"
@onready var _paddle_right: PongPaddle = $"../PaddleRight"
@onready var _wall_top: Area2D = $"../WallTop"
@onready var _wall_bottom: Area2D = $"../WallBottom"
@onready var _zone_left: Area2D = $"../ZoneLeft"
@onready var _zone_right: Area2D = $"../ZoneRight"

var _cfg := {}
var _vx := 0.0
var _vy := 0.0
var _speed := 520.0
var _radius := 11.0
var _active := false
var _collision: CollisionShape2D
var _visual: ColorRect


func setup(cfg: Dictionary) -> void:
	_cfg = cfg
	_radius = cfg.radius
	_speed = cfg.speed


func _ready() -> void:
	monitoring = true
	monitorable = false
	area_entered.connect(_on_area_entered)
	_collision = CollisionShape2D.new()
	add_child(_collision)
	_visual = ColorRect.new()
	add_child(_visual)
	_apply_geometry()


func _physics_process(delta: float) -> void:
	if not _active:
		return
	position += Vector2(_vx, _vy) * _speed * delta


func _apply_geometry() -> void:
	var shape := CircleShape2D.new()
	shape.radius = _radius
	_collision.shape = shape
	_collision.position = Vector2.ZERO
	var diameter := _radius * 2.0
	_visual.size = Vector2(diameter, diameter)
	_visual.position = Vector2(-_radius, -_radius)
	var ball_color: Color = _cfg.color
	_visual.color = Color(ball_color.r, ball_color.g, ball_color.b, _cfg.color_alpha)
	_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_center(at: Vector2) -> void:
	_active = false
	position = at


func launch_random() -> void:
	var horizontal := 1.0 if randi() % 2 == 0 else -1.0
	var angle := deg_to_rad(randf_range(_cfg.serve_min_deg, _cfg.serve_max_deg))
	var vertical := 1.0 if randi() % 2 == 0 else -1.0
	_vx = cos(angle) * horizontal
	_vy = sin(angle) * vertical
	_speed = _cfg.speed
	_active = true


func _on_area_entered(area: Area2D) -> void:
	if not _active:
		return
	if area == _wall_top or area == _wall_bottom:
		_vy = -_vy
		return
	if area == _paddle_left:
		_bounce_off_paddle(_paddle_left, 1.0)
		return
	if area == _paddle_right:
		_bounce_off_paddle(_paddle_right, -1.0)
		return
	if area == _zone_left:
		_active = false
		scored.emit("left")
		return
	if area == _zone_right:
		_active = false
		scored.emit("right")


## Curved reflection: the bounce normal rotates with the contact offset from
## the paddle center, plus a small random kick, then the ball is pushed back
## toward the court with a constant-speed, angle-bounded direction.
func _bounce_off_paddle(paddle: PongPaddle, outward: float) -> void:
	var dy := global_position.y - paddle.global_position.y
	var edge := clampf(dy / maxf(paddle.half_height, 0.001), -1.0, 1.0)

	var normal := Vector2(outward, 0.0)
	normal = normal.rotated(_cfg.reflect_curve * edge
			+ deg_to_rad(randf_range(-_cfg.random_deflect_deg, _cfg.random_deflect_deg)))
	var reflected := Vector2(_vx, _vy).reflect(normal)
	_vx = reflected.x
	_vy = reflected.y
	_speed *= 1.0 + _cfg.speed_boost_per_hit
	_set_dir_away_from(outward)


## Guarantee the ball travels back toward the court after a paddle hit and
## never degenerates into a pure vertical/horizontal loop.
func _set_dir_away_from(outward: float) -> void:
	if outward == 1.0 and _vx < 0.0:
		_vx = -_vx
	elif outward == -1.0 and _vx > 0.0:
		_vx = -_vx

	var x := _vx
	var y := _vy
	if absf(x) < _cfg.min_dir_x:
		x = _cfg.min_dir_x if x >= 0.0 else -_cfg.min_dir_x
	if absf(y) > MAX_DIR_Y:
		y = MAX_DIR_Y if y >= 0.0 else -MAX_DIR_Y
	x = signf(x) * maxf(absf(x), _cfg.min_dir_x)
	var magnitude := sqrt(x * x + y * y)
	_vx = x / magnitude
	_vy = y / magnitude
