class_name AsteroidsBullet
extends Area2D
## A single shot. Player and saucer shots share this scene; only the collision
## layer and mask differ.
##
## Saucer shots never monitor: the ship resolves that contact from its own side,
## so one hit is never counted twice.

@onready var _collision: CollisionShape2D = $Collision
@onready var _visual: Polygon2D = $Visual

var is_player := true

const SUPER_COLOR := Color("00E676")

var _velocity := Vector2.ZERO
var _life := 0.0
## Super cheat: a Callable that answers "what should a shot from this point aim
## at?" with a Vector2, or null when there is nothing left to aim at. The caller
## hands it over, so a bullet never goes looking for the fleet itself.
var _homing: Homing = null


func setup(from: Vector2, direction: Vector2, speed: float, player_owned: bool,
		radius: float, length: float, lifetime: float, color: Color) -> void:
	is_player = player_owned
	position = from
	_life = lifetime
	_velocity = direction.normalized() * speed
	_visual.color = color

	collision_layer = AsteroidsLayers.BULLET if player_owned else AsteroidsLayers.SAUCER_BULLET
	collision_mask = (AsteroidsLayers.ROCK | AsteroidsLayers.SAUCER) if player_owned else 0
	monitoring = player_owned
	monitorable = not player_owned

	var shape := CircleShape2D.new()
	shape.radius = radius
	_collision.shape = shape

	rotation = direction.angle()
	_visual.polygon = PackedVector2Array([
		Vector2(-length * 0.5, -radius),
		Vector2(length * 0.5, 0.0),
		Vector2(-length * 0.5, radius),
	])


## Connected once, here rather than in setup(): setup() is a parameter call and
## would reconnect if it ever ran twice on the same instance.
func _ready() -> void:
	area_entered.connect(_on_area_entered)


func velocity() -> Vector2:
	return _velocity


## Turns this shot into a homing one, and repaints it so the cheat is visible on
## the thing it actually changes. Saucer shots are never given a seeker.
func set_homing(seek: Callable, rate: float) -> void:
	_homing = Homing.new(seek, rate)
	_visual.color = SUPER_COLOR


func _process(delta: float) -> void:
	_steer(delta)
	position = AsteroidsField.wrap_point(position + _velocity * delta)
	_life -= delta
	if _life <= 0.0:
		queue_free()


## Bends the direction toward the target and never the speed.
func _steer(delta: float) -> void:
	if _homing == null:
		return
	_velocity = _homing.steer(position, _velocity, delta)
	rotation = _velocity.angle()


func _on_area_entered(area: Area2D) -> void:
	if not is_player:
		return
	if area is AsteroidsRock:
		if not (area as AsteroidsRock).shatter():
			return
	elif area is AsteroidsSaucer:
		if not (area as AsteroidsSaucer).kill():
			return
	else:
		return
	queue_free()
