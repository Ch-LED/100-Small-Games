class_name AsteroidsSaucer
extends Area2D
## The saucer: crosses the field once, firing as it goes, then leaves.
## It never monitors — player bullets and the ship detect it.

signal destroyed(score: int, at: Vector2)
signal fired(at: Vector2, direction: Vector2)

const OFFSCREEN_MARGIN := 70.0

@onready var _collision: CollisionShape2D = $Collision
@onready var _hull: Polygon2D = $Hull
@onready var _outline: Line2D = $Outline

## Set by the controller to a callable returning the ship's position; used for
## aimed shots. Null means every shot is fired at random.
var target_provider := Callable()

var _velocity := Vector2.ZERO
var _score := 200
var _radius := 16.0
var _fire_interval := 1.35
var _fire_timer := 0.0
var _aim_chance := 0.55
var _alive := true


func setup(from_left: bool, y: float, saucer_cfg: Dictionary, color: Color) -> void:
	_velocity = Vector2(1.0 if from_left else -1.0, 0.0) * float(saucer_cfg.speed)
	_score = int(saucer_cfg.score)
	_radius = float(saucer_cfg.radius)
	_fire_interval = float(saucer_cfg.fire_interval)
	_aim_chance = float(saucer_cfg.aim_chance)
	_fire_timer = _fire_interval
	_outline.default_color = color
	_hull.color = color.darkened(0.72)

	position = Vector2(
			-OFFSCREEN_MARGIN if from_left else AsteroidsField.SIZE.x + OFFSCREEN_MARGIN, y)

	collision_layer = AsteroidsLayers.SAUCER
	collision_mask = 0
	monitoring = false
	monitorable = true

	var shape := CircleShape2D.new()
	shape.radius = _radius
	_collision.shape = shape

	_build_outline()


## Returns false when it was already destroyed (e.g. a bullet and the ship both
## reached it in the same frame).
func kill() -> bool:
	if not _alive:
		return false
	_alive = false
	destroyed.emit(_score, position)
	queue_free()
	return true


func _process(delta: float) -> void:
	if not _alive:
		return
	# No wrapping: the saucer is meant to cross and leave.
	position += _velocity * delta
	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_fire_timer = _fire_interval
		_fire()
	if position.x < -OFFSCREEN_MARGIN or position.x > AsteroidsField.SIZE.x + OFFSCREEN_MARGIN:
		queue_free()


func _fire() -> void:
	var direction := Vector2.RIGHT.rotated(randf() * TAU)
	if target_provider.is_valid() and randf() < _aim_chance:
		var target: Vector2 = target_provider.call()
		var aim := AsteroidsField.wrapped_delta(position, target)
		if aim.length() > 1.0:
			direction = aim.normalized()
			direction = direction.rotated(randf_range(-0.22, 0.22))
	fired.emit(position, direction)


func _build_outline() -> void:
	var r := _radius
	var hull := PackedVector2Array([
		Vector2(-r, -r * 0.22), Vector2(-r * 0.5, -r * 0.62), Vector2(r * 0.5, -r * 0.62),
		Vector2(r, -r * 0.22), Vector2(r * 0.62, r * 0.42), Vector2(-r * 0.62, r * 0.42),
	])
	_hull.polygon = hull
	var closed := hull.duplicate()
	closed.append(hull[0])
	_outline.points = closed
