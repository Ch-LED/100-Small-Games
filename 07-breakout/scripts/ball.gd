class_name BreakoutBall
extends Node2D
## The ball. Collision is the swept analytic solver from 01-pingpong (see
## DECISION_LOG 013), generalised from "four fixed colliders" to "a list built
## fresh each step". No speed can tunnel, and a corner takes its normal from the
## real contact face rather than from a signal's timing.
##
## `velocity` is a unit direction; `_speed` carries the magnitude, so speed-ups
## never disturb the direction.

signal brick_hit(brick: BreakoutBrick)
## `smashed` is true when the paddle was mid-swing. A smash is the player's own
## doing rather than the ball coming home, so it does not break a combo — the
## receiver needs to know which one it was (DECISION_LOG 050).
signal paddle_hit(smashed: bool)
signal wall_hit
signal lost
## The swing's retract caught the ball instead of bouncing it.
signal caught

## Nudged along the contact normal so the reflected ball does not immediately
## re-hit the same face at t = 0.
const SEPARATION := 0.05
## Below this leftover distance the rest of the step is dropped.
const MIN_STEP := 0.0001

const VISUAL_SEGMENTS := 16
## Every game's `]` cheat draws in this same green, the way every game's debug
## overlay draws in the same yellow. It is a convention rather than a knob.
const SUPER_COLOR := Color("00E676")

@onready var _visual: Polygon2D = $Visual

var radius := 9.0
var velocity := Vector2.RIGHT

var _base_color := Color.WHITE
var _hot_color := Color("FFC24A")
var _homing_rate := 8.0

var _cfg := {}
var _base_speed := 430.0
var _speed := 430.0
var _max_speed := 760.0
var _attach_offset := 24.0
var _attached := true
var _frozen := false
## True from a swing smash until the next ordinary contact. The ball is drawn hot
## while it lasts, which is the tell that a smash is still carrying the combo.
var _hot := false
## The super cheat (`]`): a descending ball past the bricks steers onto the
## paddle. It cannot be lost, and it is drawn in its own colour while it is on.
var _super_homing := false
## The next launch comes off a swing's catch, so it is aimed tighter.
var _from_catch := false
## Set for the rest of the sweep once the paddle catches the ball: there is
## nothing left to bounce off, the step is over.
var _caught_this_step := false
var _paddle: BreakoutPaddle = null
var _bricks: Node2D = null
var _walls: Array[Rect2] = []


func setup(ball_cfg: Dictionary, paddle: BreakoutPaddle, bricks: Node2D,
		color: Color) -> void:
	_cfg = ball_cfg
	radius = float(ball_cfg.radius)
	_base_speed = float(ball_cfg.speed)
	_speed = _base_speed
	_max_speed = float(ball_cfg.max_speed)
	_attach_offset = float(ball_cfg.attach_offset)
	_base_color = color
	_hot_color = ball_cfg.hot_color
	_homing_rate = float(ball_cfg.super_homing_rate)
	_paddle = paddle
	_bricks = bricks
	_walls = BreakoutField.wall_rects()

	# A drawn circle, so what you see is exactly the collision circle.
	_visual.polygon = _circle_polygon()
	attach_to_paddle()


func _circle_polygon() -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in VISUAL_SEGMENTS:
		points.append(Vector2.RIGHT.rotated(TAU * float(i) / float(VISUAL_SEGMENTS)) * radius)
	return points


## Per-level speed-up, applied on top of the configured base speed.
func set_level_multiplier(multiplier: float) -> void:
	_base_speed = float(_cfg.speed) * multiplier
	_speed = _base_speed


func speed() -> float:
	return _speed


func is_attached() -> bool:
	return _attached


## Loose and moving: not stuck to the paddle, not held still between balls.
func is_in_play() -> bool:
	return not _attached and not _frozen


## A smashed ball is drawn gold, and carries the combo on. Cleared by the next
## ordinary paddle contact, by a catch, and by every fresh launch.
func is_hot() -> bool:
	return _hot


func is_super_homing() -> bool:
	return _super_homing


func set_super_homing(value: bool) -> void:
	_super_homing = value
	_apply_color()


func attach_to_paddle() -> void:
	_attached = true
	_speed = _base_speed
	velocity = Vector2.RIGHT
	_from_catch = false
	_set_hot(false)
	_snap_to_paddle()


func launch() -> void:
	if not _attached:
		return
	_attached = false
	# A ball handed back by a swing's catch is aimed tighter than a fresh one:
	# tighter aim is the whole point of catching it, and the wide band was making
	# the catch worth nothing but the speed reset.
	var low := float(_cfg.launch_min_deg)
	var high := float(_cfg.launch_max_deg)
	if _from_catch:
		var middle := (low + high) * 0.5
		var half := (high - low) * 0.5 * float(_cfg.caught_spread_scale)
		low = middle - half
		high = middle + half
	_from_catch = false

	var angle := deg_to_rad(randf_range(low, high))
	var side := 1.0 if randf() < 0.5 else -1.0
	velocity = with_min_angle(Vector2(cos(angle) * side, -sin(angle)))


## Held still while the game is between balls or between levels.
func set_frozen(value: bool) -> void:
	_frozen = value


func _physics_process(delta: float) -> void:
	if _frozen:
		return
	if _attached:
		_snap_to_paddle()
		return
	_steer_home(delta)
	_push_out_of_overlaps()
	_sweep(velocity * _speed * delta)
	_check_lost()


## The super cheat. Once a descending ball is past the brick block the only things
## left for it to meet are the paddle and the walls, so it may as well aim itself
## at the paddle. Bends the direction and never the speed.
func _steer_home(delta: float) -> void:
	if not _super_homing or _paddle == null or velocity.y <= 0.0:
		return
	if position.y <= BreakoutField.brick_block_bottom():
		return
	var target := Vector2(_paddle.center_x() - position.x,
			_paddle.position.y - _paddle.half_height - position.y)
	if target.length() < 1.0:
		return
	var weight := clampf(_homing_rate * delta, 0.0, 1.0)
	velocity = with_min_angle(velocity.slerp(target.normalized(), weight).normalized())


# --- sweep ------------------------------------------------------------------

## Marches along `step`, reflecting at the first contact and continuing with the
## leftover distance, until the step is spent or the bounce cap hits.
func _sweep(step: Vector2) -> void:
	var remaining := step
	_caught_this_step = false
	for _bounce_index in int(_cfg.max_bounces):
		var hit := _earliest_hit(remaining)
		if hit.is_empty():
			position += remaining
			return
		var t: float = hit.t
		var normal: Vector2 = hit.normal
		position += remaining * t
		var leftover := remaining.length() * (1.0 - t)
		_bounce(normal, hit.target)
		if _caught_this_step:
			return
		position += normal * SEPARATION
		if leftover < MIN_STEP:
			return
		remaining = velocity * leftover


## Time of the earliest contact along `step`, or {} when the sweep is clear.
func _earliest_hit(step: Vector2) -> Dictionary:
	var best := {}
	for wall in _walls:
		best = _keep_nearer(best, _sweep_rect(wall, step), null)
	if _paddle != null:
		var paddle_hit := _sweep_rect(_paddle.global_rect(), step)
		# The paddle's underside is transparent to a ball on its way UP and solid
		# to one on its way DOWN. Whatever face a descending ball meets, the
		# paddle sends it back up — a paddle may not lose you a ball that came to
		# it. A rising ball passing under a raised paddle carries on and comes out
		# on top, where the next contact is an ordinary front-face one.
		if not paddle_hit.is_empty() and float(paddle_hit.normal.y) > 0.0 \
				and velocity.y < 0.0:
			paddle_hit = {}
		best = _keep_nearer(best, paddle_hit, _paddle)
	if _bricks != null:
		for child in _bricks.get_children():
			var brick := child as BreakoutBrick
			# Retired bricks are still children until the frame ends, so they must
			# be skipped explicitly or the ball would bounce off one twice.
			if brick == null or brick.is_out_of_play():
				continue
			best = _keep_nearer(best, _sweep_rect(brick.global_rect(), step), brick)
	return best


func _keep_nearer(best: Dictionary, hit: Dictionary, target) -> Dictionary:
	if hit.is_empty():
		return best
	if best.is_empty() or float(hit.t) < float(best.t):
		return {"t": hit.t, "normal": hit.normal, "target": target}
	return best


## Swept circle vs axis-aligned rect: grow the rect by the radius (Minkowski)
## and ray-cast the step through it. Returns {t, normal} or {}.
func _sweep_rect(rect: Rect2, step: Vector2) -> Dictionary:
	if step == Vector2.ZERO:
		return {}
	var expanded := rect.grow(radius)
	var t_near := 0.0
	var t_far := 1.0
	var normal := Vector2.ZERO

	var x_clip := _clip_axis(position.x, step.x, expanded.position.x, expanded.end.x,
			t_near, t_far)
	if x_clip.is_empty():
		return {}
	t_near = x_clip.t_near
	t_far = x_clip.t_far
	if x_clip.hit_normal != 0.0:
		normal = Vector2(x_clip.hit_normal, 0.0)

	var y_clip := _clip_axis(position.y, step.y, expanded.position.y, expanded.end.y,
			t_near, t_far)
	if y_clip.is_empty():
		return {}
	t_near = y_clip.t_near
	t_far = y_clip.t_far
	if y_clip.hit_normal != 0.0:
		normal = Vector2(0.0, y_clip.hit_normal)

	if normal == Vector2.ZERO or t_near < 0.0 or t_near > 1.0:
		return {}
	return {"t": t_near, "normal": normal}


## One slab of the test. `hit_normal` is non-zero only when this axis supplied
## the entry face — that axis is the contact normal, which is what makes a
## brick's corner bounce come out right without a special case.
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


## The direction the ball leaves the paddle with, given where on the paddle it
## landed. `jitter` is the random wobble in radians.
##
## ⚠️ The tilt is applied to the contact NORMAL, and a bounce doubles a normal's
## tilt, so the outgoing angle off vertical is roughly `2 * paddle_curve * edge`.
## That factor of two is why the curve has to stay modest: at 0.9 rad the edge
## would fling the ball past the horizontal entirely, which is what made the
## paddle feel like a lens rather than a bat (DECISION_LOG 046).
func paddle_return_direction(paddle: BreakoutPaddle, jitter: float) -> Vector2:
	var edge := clampf((position.x - paddle.center_x())
			/ maxf(paddle.half_width, 0.001), -1.0, 1.0)
	var tilt: float = float(_cfg.paddle_curve) * edge + jitter
	var direction := velocity.bounce(Vector2.UP.rotated(tilt))
	# The tilt must never drive the ball back down into the paddle.
	if direction.y > 0.0:
		direction.y = -direction.y
	return with_min_angle(direction.normalized())


## Clamps a direction to at least `min_angle_from_horizontal_deg` off the
## horizontal, keeping both signs.
##
## A shallow ball can otherwise rattle between the side walls forever without
## ever reaching the bricks. (Note this is the mirror image of pong's rule,
## which had to avoid near-vertical wall-to-wall loops instead.)
##
## A dead-horizontal ball is nudged *up*: it has no vertical momentum to
## preserve, and down would dive it at the paddle for no reason. Real play
## never produces exactly horizontal — a launch is steep and bounces keep
## |v.y| >= sin(min) — but the tiebreak should not point the wrong way.
func with_min_angle(direction: Vector2) -> Vector2:
	var min_angle := deg_to_rad(float(_cfg.min_angle_from_horizontal_deg))
	if asin(clampf(absf(direction.y), 0.0, 1.0)) >= min_angle:
		return direction
	var upward := direction.y < 0.0 or is_zero_approx(direction.y)
	var y := sin(min_angle) * (-1.0 if upward else 1.0)
	var x := sqrt(maxf(0.0, 1.0 - y * y)) * (1.0 if direction.x >= 0.0 else -1.0)
	return Vector2(x, y)


func _bounce(normal: Vector2, target) -> void:
	if target is BreakoutPaddle and (target as BreakoutPaddle).is_retracting():
		# The retract is a catch, not a bounce: a falling ball becomes one you
		# can aim again instead of the one that ends the run.
		attach_to_paddle()
		_from_catch = true
		_caught_this_step = true
		caught.emit()
		return

	var direction := velocity.bounce(normal)
	var smashed := false
	if target is BreakoutPaddle:
		var paddle: BreakoutPaddle = target
		# A swung paddle hits harder than a parked one, and is allowed past the
		# speed ceiling a parked paddle respects.
		smashed = paddle.is_swinging()
		var boost: float = float(_cfg.swing_boost) if smashed \
				else 1.0 + float(_cfg.speed_boost_per_hit)
		var ceiling: float = float(_cfg.swing_max_speed) if smashed else _max_speed
		_speed = minf(ceiling, _speed * boost)
		_set_hot(smashed)
		if absf(normal.y) > 0.5:
			# Front face: where it landed on the paddle steers the return angle.
			var jitter := deg_to_rad(randf_range(
					-float(_cfg.random_deflect_deg), float(_cfg.random_deflect_deg)))
			direction = paddle_return_direction(paddle, jitter)

	_set_direction(direction)

	if target is BreakoutPaddle:
		paddle_hit.emit(smashed)
	elif target is BreakoutBrick:
		brick_hit.emit(target)
	else:
		wall_hit.emit()


func _set_hot(value: bool) -> void:
	_hot = value
	_apply_color()


## Super beats hot for the drawing: the cheat is the state the player has to be
## able to see from across the room.
func _apply_color() -> void:
	if _super_homing:
		_visual.color = SUPER_COLOR
	elif _hot:
		_visual.color = _hot_color
	else:
		_visual.color = _base_color


func _set_direction(direction: Vector2) -> void:
	if direction.length() <= 0.0:
		return
	velocity = with_min_angle(direction.normalized())


## A paddle moving onto the ball between frames can leave it buried; push it back
## out along the shallowest face so no step ever starts inside something.
func _push_out_of_overlaps() -> void:
	for wall in _walls:
		_push_out(wall)
	if _paddle != null:
		_resolve_paddle_overlap()


## The one case the shallowest-face rule gets wrong: a lunging box can close
## around a descending ball (or pull the floor out from under one), and pushing
## that ball out the underside is pushing it into the floor. A swinging paddle
## lifts it onto its top face instead, keeping the velocity — so it lands on the
## top face next step and is smashed like any other save. Otherwise the ordinary
## rule applies, minus any downward answer.
func _resolve_paddle_overlap() -> void:
	var rect := _paddle.global_rect()
	var rest_top := _paddle.position.y - _paddle.half_height
	if _paddle.is_swinging() and velocity.y > 0.0 and _in_lunge_path(rect, rest_top):
		position = Vector2(position.x, rect.position.y - radius - SEPARATION)
		return
	_push_out(rect, true)


## True when a descending ball sits in the volume the box swept through on its
## way up — where it is now, plus the space it vacated — and has not yet passed
## the resting surface. Every such ball was on its way to the resting top face,
## which would have returned it; the lunge has to return it too. Without this,
## swinging would be a way to LOSE a ball you were about to save, because the box
## steps out from under it and it falls through the gap where the paddle was.
func _in_lunge_path(raised: Rect2, rest_top: float) -> bool:
	if position.y > rest_top - radius:
		return false
	var vacated := _paddle.position.y + _paddle.half_height
	return _overlaps(Rect2(raised.position,
			Vector2(raised.size.x, vacated - raised.position.y)))


func _overlaps(rect: Rect2) -> bool:
	var closest := Vector2(
			clampf(position.x, rect.position.x, rect.end.x),
			clampf(position.y, rect.position.y, rect.end.y))
	return position.distance_to(closest) < radius


func _push_out(rect: Rect2, one_way := false) -> void:
	var closest := Vector2(
			clampf(position.x, rect.position.x, rect.end.x),
			clampf(position.y, rect.position.y, rect.end.y))
	var offset := position - closest
	var distance := offset.length()
	if distance >= radius:
		return
	var normal := offset / distance if distance > 0.0001 else _shallow_face(rect)
	if one_way and normal.y > 0.0:
		return
	position = closest + normal * (radius + SEPARATION)
	if velocity.dot(normal) < 0.0:
		_set_direction(velocity.bounce(normal))


## Outward normal of the face nearest to a centre that sits inside `rect`.
func _shallow_face(rect: Rect2) -> Vector2:
	var gaps := [
		position.x - rect.position.x,
		rect.end.x - position.x,
		position.y - rect.position.y,
		rect.end.y - position.y,
	]
	var normals := [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]
	var index := 0
	for i in gaps.size():
		if gaps[i] < gaps[index]:
			index = i
	return normals[index]


func _check_lost() -> void:
	if position.y - radius > BreakoutField.SIZE.y:
		lost.emit()


func _snap_to_paddle() -> void:
	if _paddle == null:
		return
	position = _paddle.position + Vector2(0.0, -(_paddle.half_height + _attach_offset))
