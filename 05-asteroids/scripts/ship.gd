class_name AsteroidsShip
extends Area2D
## The player's ship: it owns its own inertia, rotation and firing cooldown.
## The controller feeds it steering each frame and reads back when it may fire.

## Hull and rear flame, in units of a 14px radius ship; scaled to `_radius`.
const HULL_SHAPE: Array[Vector2] = [
	Vector2(18.0, 0.0), Vector2(-12.0, 12.0), Vector2(-7.0, 0.0), Vector2(-12.0, -12.0),
]
const FLAME_SHAPE: Array[Vector2] = [
	Vector2(-9.0, 5.0), Vector2(-20.0, 0.0), Vector2(-9.0, -5.0),
]
const SHAPE_UNIT := 14.0

@onready var _collision: CollisionShape2D = $Collision
@onready var _hull: Polygon2D = $Hull
@onready var _outline: Line2D = $Outline
@onready var _flame: Polygon2D = $Flame

## Inertial velocity, in pixels per second. Read by the debug overlay.
var velocity := Vector2.ZERO
var radius := 14.0

var _rotate_speed := 250.0
var _thrust_accel := 380.0
var _drag := 0.45
var _max_speed := 430.0
var _fire_cooldown := 0.16
var _cooldown := 0.0
var _invuln := 0.0
var _blink_t := 0.0
var _steer := 0.0
var _thrusting := false
var _alive := true
## Cheat state: never dies, and the hull turns green to say so.
var _invincible := false
var _ship_color := Color("E8F1FF")
var _invuln_color := Color("57D97B")
var _thrust_color := Color("FFB84D")


func setup(ship_cfg: Dictionary, field_cfg: Dictionary) -> void:
	radius = float(ship_cfg.radius)
	_rotate_speed = float(ship_cfg.rotate_speed)
	_thrust_accel = float(ship_cfg.thrust_accel)
	_drag = float(ship_cfg.drag)
	_max_speed = float(ship_cfg.max_speed)
	_fire_cooldown = float(ship_cfg.fire_cooldown)
	_ship_color = field_cfg.ship_color
	_invuln_color = field_cfg.invuln_color
	_thrust_color = field_cfg.thrust_color

	collision_layer = AsteroidsLayers.SHIP
	collision_mask = AsteroidsLayers.ROCK | AsteroidsLayers.SAUCER | AsteroidsLayers.SAUCER_BULLET
	monitoring = true
	monitorable = true

	var shape := CircleShape2D.new()
	shape.radius = radius
	_collision.shape = shape

	_build_visuals()
	_apply_colors()


func forward() -> Vector2:
	return Vector2.RIGHT.rotated(rotation)


## Where a shot leaves the hull.
func nose() -> Vector2:
	return position + forward() * radius * 1.3


func is_alive() -> bool:
	return _alive


func is_protected() -> bool:
	return _invincible or _invuln > 0.0


func set_controls(steer: float, thrusting: bool) -> void:
	_steer = clampf(steer, -1.0, 1.0)
	_thrusting = thrusting


func set_invincible(enabled: bool) -> void:
	_invincible = enabled
	_apply_colors()


func make_invulnerable(seconds: float) -> void:
	_invuln = maxf(_invuln, seconds)
	_blink_t = 0.0


## True when the cooldown has elapsed; a successful call starts the next one.
func try_fire() -> bool:
	if not _alive or _cooldown > 0.0:
		return false
	_cooldown = _fire_cooldown
	return true


## Places the ship ready to fly, clearing velocity.
func respawn(at: Vector2, facing: float) -> void:
	_alive = true
	visible = true
	position = at
	rotation = facing
	velocity = Vector2.ZERO
	_steer = 0.0
	_thrusting = false
	_flame.visible = false
	_cooldown = 0.0
	_invuln = 0.0
	_hull.visible = true
	_outline.visible = true
	monitoring = true
	_collision.set_deferred("disabled", false)


## Hides the ship and stops it responding; the controller runs the death beat.
## Reached from a collision callback, so the physics flags are changed deferred.
func hide_wreck() -> void:
	_alive = false
	velocity = Vector2.ZERO
	_steer = 0.0
	_thrusting = false
	visible = false
	_flame.visible = false
	set_deferred("monitoring", false)
	_collision.set_deferred("disabled", true)


func _process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if not _alive:
		return

	rotation += _steer * deg_to_rad(_rotate_speed) * delta

	if _thrusting:
		velocity += forward() * _thrust_accel * delta
	# Frame-rate independent damping, then the hard speed ceiling.
	velocity *= exp(-_drag * delta)
	if velocity.length() > _max_speed:
		velocity = velocity.normalized() * _max_speed

	position = AsteroidsField.wrap_point(position + velocity * delta)
	_flame.visible = _thrusting
	if _thrusting:
		_flame.scale = Vector2(1.0, randf_range(0.75, 1.1))

	_tick_invulnerability(delta)


func _tick_invulnerability(delta: float) -> void:
	if _invuln <= 0.0:
		return
	_invuln -= delta
	_blink_t += delta
	if _invuln <= 0.0:
		_hull.visible = true
		_outline.visible = true
		return
	var shown := fmod(_blink_t, 0.2) < 0.13
	_hull.visible = shown
	_outline.visible = shown


func _build_visuals() -> void:
	var scale_factor := radius / SHAPE_UNIT
	_hull.polygon = _scaled(HULL_SHAPE, scale_factor)
	var closed := _scaled(HULL_SHAPE, scale_factor)
	closed.append(closed[0])
	_outline.points = closed
	_flame.polygon = _scaled(FLAME_SHAPE, scale_factor)
	_flame.visible = false


func _scaled(shape: Array[Vector2], factor: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for point in shape:
		out.append(point * factor)
	return out


func _apply_colors() -> void:
	var edge := _invuln_color if _invincible else _ship_color
	_outline.default_color = edge
	_hull.color = edge.darkened(0.72)
	_flame.color = _thrust_color
