class_name PongBall
extends Area2D
## The ball. Collision is solved by sweeping its circle along each frame's step
## and reflecting at the earliest contact, so no speed can tunnel and the corner
## where a paddle meets a wall can never be slipped through. The walls and
## paddles stay scene nodes and own their rectangles (CONSTITUTION 5.5); the ball
## only reads those rects, it does not use area signals.

signal scored(side: String)
## Emitted on each paddle contact, carrying the post-boost speed (Game turns it
## into a pitch). Walls get their own, quieter cue.
signal paddle_hit(speed: float)
signal wall_hit

## Small clearance pushed along the contact normal so the reflected ball does not
## immediately re-hit the same face at t = 0.
const SEPARATION := 0.05
## Cap on reflections within one frame (a wedge can otherwise loop forever).
const MAX_BOUNCES := 8
## The `]` super cheat's colour, the same in every game in this project.
const SUPER_COLOR := Color("00E676")

@onready var _paddle_left: PongPaddle = $"../PaddleLeft"
@onready var _paddle_right: PongPaddle = $"../PaddleRight"
@onready var _wall_top: PongBarrier = $"../WallTop"
@onready var _wall_bottom: PongBarrier = $"../WallBottom"
@onready var _zone_left: PongBarrier = $"../ZoneLeft"
@onready var _zone_right: PongBarrier = $"../ZoneRight"
@onready var _collision: CollisionShape2D = $Collision
@onready var _visual: ColorRect = $Visual

var _cfg := {}
var _vx := 0.0
var _vy := 0.0
var _speed := 520.0
var _radius := 11.0
var _active := false
## The `]` super cheat: on the way back to the player the ball aims itself at
## that paddle, so the player cannot be scored on.
var _super_homing := false
var _homing_rate := 6.0


func _ready() -> void:
	monitoring = false
	monitorable = false


## Geometry is built here rather than in _ready: the scene instance enters the
## tree before Game has had a chance to hand over the config.
func setup(cfg: Dictionary, cheat_cfg: Dictionary = {}) -> void:
	_cfg = cfg
	_radius = cfg.radius
	_speed = cfg.speed
	_homing_rate = float(cheat_cfg.get("homing_rate", 6.0))
	_apply_geometry()


func _physics_process(delta: float) -> void:
	if not _active:
		return
	_steer_home(delta)
	_push_out_of_overlaps()
	_sweep(Vector2(_vx, _vy) * _speed * delta)
	_check_goal()


func set_super_homing(value: bool) -> void:
	_super_homing = value
	_apply_visual_color()


## The super cheat. Once the ball is on its way to the player's paddle the only
## things left for it to meet are that paddle and the walls, so it may as well aim
## itself at the paddle. Bends the direction and never the speed.
func _steer_home(delta: float) -> void:
	if not _super_homing or _vx <= 0.0:
		return
	var target := _paddle_right.global_position - global_position
	if target.length() < 1.0:
		return
	var weight := clampf(_homing_rate * delta, 0.0, 1.0)
	_set_direction(Vector2(_vx, _vy).slerp(target.normalized(), weight))


func set_center(at: Vector2) -> void:
	_active = false
	global_position = at


func launch_random() -> void:
	var horizontal := 1.0 if randi() % 2 == 0 else -1.0
	var vertical := 1.0 if randi() % 2 == 0 else -1.0
	var angle := deg_to_rad(randf_range(_cfg.serve_min_deg, _cfg.serve_max_deg))
	_vx = cos(angle) * horizontal
	_vy = sin(angle) * vertical
	_speed = _cfg.speed
	_active = true


func _apply_geometry() -> void:
	var shape := CircleShape2D.new()
	shape.radius = _radius
	_collision.shape = shape
	_collision.position = Vector2.ZERO
	var diameter := _radius * 2.0
	_visual.size = Vector2(diameter, diameter)
	_visual.position = Vector2(-_radius, -_radius)
	_apply_visual_color()
	_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Green while the super cheat is on: the colour is the whole explanation, so it
## replaces the ball's own.
func _apply_visual_color() -> void:
	var tint: Color = SUPER_COLOR if _super_homing else _cfg.color
	_visual.color = Color(tint.r, tint.g, tint.b, _cfg.color_alpha)


# --- collision --------------------------------------------------------------

## Marches the ball along `step`, reflecting at the first contact and continuing
## with the leftover distance, until the step is consumed or the bounce cap hits.
func _sweep(step: Vector2) -> void:
	for _bounce_index in MAX_BOUNCES:
		var hit := _earliest_hit(step)
		if hit.is_empty():
			global_position += step
			return
		var t: float = hit.t
		var normal: Vector2 = hit.normal
		global_position += step * t
		var remaining := step.length() * (1.0 - t)
		_bounce(normal, hit.target)
		global_position += normal * SEPARATION
		step = Vector2(_vx, _vy) * remaining


## Time of the earliest contact along `step`, or {} if the sweep is clear.
func _earliest_hit(step: Vector2) -> Dictionary:
	var best := {}
	var walls: Array[PongBarrier] = [_wall_top, _wall_bottom]
	for wall in walls:
		best = _keep_nearer(best, _sweep_rect(wall.global_rect(), step), wall)
	var paddles: Array[PongPaddle] = [_paddle_left, _paddle_right]
	for paddle in paddles:
		best = _keep_nearer(best, _sweep_rect(paddle.global_rect(), step), paddle)
	return best


func _keep_nearer(best: Dictionary, hit: Dictionary, target) -> Dictionary:
	if hit.is_empty():
		return best
	if best.is_empty() or float(hit.t) < float(best.t):
		return {"t": hit.t, "normal": hit.normal, "target": target}
	return best


## Swept-circle vs axis-aligned rect: grow the rect by the radius (Minkowski)
## and ray-cast the step through it. Returns {t, normal} or {}.
func _sweep_rect(rect: Rect2, step: Vector2) -> Dictionary:
	if step == Vector2.ZERO:
		return {}
	var expanded := rect.grow(_radius)
	var t_near := 0.0
	var t_far := 1.0
	var normal := Vector2.ZERO

	var x_clip := _clip_axis(global_position.x, step.x, expanded.position.x, expanded.end.x, t_near, t_far)
	if x_clip.is_empty():
		return {}
	t_near = x_clip.t_near
	t_far = x_clip.t_far
	if x_clip.hit_normal != 0.0:
		normal = Vector2(x_clip.hit_normal, 0.0)

	var y_clip := _clip_axis(global_position.y, step.y, expanded.position.y, expanded.end.y, t_near, t_far)
	if y_clip.is_empty():
		return {}
	t_near = y_clip.t_near
	t_far = y_clip.t_far
	if y_clip.hit_normal != 0.0:
		normal = Vector2(0.0, y_clip.hit_normal)

	if normal == Vector2.ZERO or t_near < 0.0 or t_near > 1.0:
		return {}
	return {"t": t_near, "normal": normal}


## One slab of the test. `hit_normal` is non-zero only when this axis supplies
## the entry face (i.e. it raised t_near) — that axis is the contact normal.
func _clip_axis(origin: float, delta: float, lo: float, hi: float,
		t_near_in: float, t_far_in: float) -> Dictionary:
	var t_near := t_near_in
	var t_far := t_far_in
	var hit_normal := 0.0
	if absf(delta) < 0.000001:
		if origin < lo or origin > hi:
			return {}
	else:
		var inv := 1.0 / delta
		var t1 := (lo - origin) * inv
		var t2 := (hi - origin) * inv
		var entry_sign := -1.0 if delta > 0.0 else 1.0
		if t1 > t2:
			var swap := t1
			t1 = t2
			t2 = swap
		if t1 > t_near:
			t_near = t1
			hit_normal = entry_sign
		if t2 < t_far:
			t_far = t2
	if t_near > t_far:
		return {}
	return {"t_near": t_near, "t_far": t_far, "hit_normal": hit_normal}


## Reflects the velocity off `normal`. A front-face hit on a paddle keeps the
## arc feel; every other contact (wall, paddle edge, paddle top/bottom) is a
## plain mirror.
func _bounce(normal: Vector2, target) -> void:
	var v := Vector2(_vx, _vy)
	if target is PongPaddle:
		_speed *= 1.0 + _cfg.speed_boost_per_hit
	if target is PongPaddle and absf(normal.x) > 0.5:
		var paddle: PongPaddle = target
		var edge := clampf((global_position.y - paddle.global_position.y)
				/ maxf(paddle.half_height, 0.001), -1.0, 1.0)
		var kick: float = _cfg.reflect_curve * edge
		kick += deg_to_rad(randf_range(-_cfg.random_deflect_deg, _cfg.random_deflect_deg))
		v = v.bounce(normal.rotated(kick))
		# Hold the ball on the court side of the paddle even if the tilt tried to
		# send it back through.
		var outward := signf(normal.x)
		if v.x * outward < 0.0:
			v.x = -v.x
	else:
		v = v.bounce(normal)
	_set_direction(v)
	if target is PongPaddle:
		paddle_hit.emit(_speed)
	else:
		wall_hit.emit()


func _set_direction(v: Vector2) -> void:
	var magnitude := v.length()
	if magnitude <= 0.0:
		return
	_vx = v.x / magnitude
	_vy = v.y / magnitude
	_enforce_min_angle()


## Keep the direction at least `min_bounce_angle_from_vertical_deg` away from the
## vertical, so a rally can never settle into a near-vertical wall-to-wall loop.
func _enforce_min_angle() -> void:
	var min_angle := deg_to_rad(_cfg.min_bounce_angle_from_vertical_deg)
	if acos(clampf(absf(_vy), 0.0, 1.0)) >= min_angle:
		return
	var y_mag := cos(min_angle)
	_vx = sqrt(maxf(0.0, 1.0 - y_mag * y_mag)) * (1.0 if _vx >= 0.0 else -1.0)
	_vy = y_mag * (1.0 if _vy >= 0.0 else -1.0)


## A moving paddle can close onto the ball between frames; push the ball back
## out along the shallowest face so a step never starts with the ball buried.
func _push_out_of_overlaps() -> void:
	var walls: Array[PongBarrier] = [_wall_top, _wall_bottom]
	var paddles: Array[PongPaddle] = [_paddle_left, _paddle_right]
	for wall in walls:
		_push_out(wall.global_rect())
	for paddle in paddles:
		_push_out(paddle.global_rect())


func _push_out(rect: Rect2) -> void:
	var closest := Vector2(clampf(global_position.x, rect.position.x, rect.end.x),
			clampf(global_position.y, rect.position.y, rect.end.y))
	var offset := global_position - closest
	var dist := offset.length()
	if dist >= _radius:
		return
	var normal := offset / dist if dist > 0.0001 else _shallow_face(rect)
	global_position = closest + normal * (_radius + SEPARATION)
	var v := Vector2(_vx, _vy)
	if v.dot(normal) < 0.0:
		_set_direction(v.bounce(normal))


## Outward normal of the face nearest to a ball centre that sits inside `rect`.
func _shallow_face(rect: Rect2) -> Vector2:
	var gaps := [
		global_position.x - rect.position.x,
		rect.end.x - global_position.x,
		global_position.y - rect.position.y,
		rect.end.y - global_position.y,
	]
	var normals := [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]
	var index := 0
	for i in gaps.size():
		if gaps[i] < gaps[index]:
			index = i
	return normals[index]


## The ball scores once its edge reaches a goal plane behind a paddle.
func _check_goal() -> void:
	if global_position.x - _radius <= _zone_left.global_rect().end.x:
		_active = false
		scored.emit("left")
	elif global_position.x + _radius >= _zone_right.global_rect().position.x:
		_active = false
		scored.emit("right")
