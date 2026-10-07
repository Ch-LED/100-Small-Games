class_name PongPaddle
extends Area2D
## One paddle: an Area2D that is visible via a ColorRect child and moves
## vertically toward _target (-1/0/+1) at max_speed, clamped to field bounds.

@onready var _collision: CollisionShape2D = $Collision
@onready var _visual: ColorRect = $Visual

var side := ""
var half_height := 60.0
var _cfg := {}
var _target := 0
var _min_y := 0.0
var _max_y := 0.0


func _ready() -> void:
	monitoring = false
	monitorable = true


## Geometry is built here rather than in _ready: the scene instance enters the
## tree before Game has had a chance to hand over the config.
func setup(paddle_side: String, cfg: Dictionary) -> void:
	side = paddle_side
	_cfg = cfg
	half_height = cfg.height * 0.5
	_apply_geometry()


func _physics_process(delta: float) -> void:
	if _target == 0:
		return
	position.y = clampf(position.y + _target * _cfg.max_speed * delta, _min_y, _max_y)


func _apply_geometry() -> void:
	var width: float = _cfg.width
	var height: float = _cfg.height
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width, height)
	_collision.shape = shape
	_collision.position = Vector2.ZERO
	_visual.size = Vector2(width, height)
	_visual.position = Vector2(-width * 0.5, -height * 0.5)
	_visual.color = _cfg.left_color if side == "left" else _cfg.right_color
	_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_target(dir: int) -> void:
	_target = clampi(dir, -1, 1)


## Eases by `t` of the remaining distance to a target y (0..1), clamped to the
## field. The AI drives the paddle this way; the player uses set_target.
func ease_toward(target_y: float, t: float) -> void:
	position.y = clampf(lerpf(position.y, target_y, t), _min_y, _max_y)


func refresh_bounds(min_y: float, max_y: float) -> void:
	_min_y = min_y
	_max_y = max_y
