class_name PongPaddle
extends Area2D
## One paddle: an Area2D that is visible via a ColorRect child and moves
## vertically toward _target (-1/0/+1) at max_speed, clamped to field bounds.

var side := ""
var half_height := 60.0
var _cfg := {}
var _target := 0
var _min_y := 0.0
var _max_y := 0.0
var _collision: CollisionShape2D
var _visual: ColorRect


func setup(paddle_side: String, cfg: Dictionary) -> void:
	side = paddle_side
	_cfg = cfg
	half_height = cfg.height * 0.5


func _ready() -> void:
	monitoring = false
	monitorable = true
	_collision = CollisionShape2D.new()
	add_child(_collision)
	_visual = ColorRect.new()
	add_child(_visual)
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


func refresh_bounds(min_y: float, max_y: float) -> void:
	_min_y = min_y
	_max_y = max_y
