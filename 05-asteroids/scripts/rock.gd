class_name AsteroidsRock
extends Area2D
## One drifting rock. Its outline is generated per instance, so no two look
## alike. It never monitors anything: bullets and the ship detect it, and it
## only reports that it was hit.

signal shattered(kind: int, at: Vector2)

@onready var _collision: CollisionShape2D = $Collision
@onready var _hull: Polygon2D = $Hull
@onready var _outline: Line2D = $Outline

## Size index: AsteroidsSettings.LARGE / MEDIUM / SMALL.
var kind: int = AsteroidsSettings.LARGE
var radius := 46.0
var score := 20

var _velocity := Vector2.ZERO
var _spin := 0.0
var _shattered := false


func setup(size_kind: int, at: Vector2, velocity: Vector2, spin: float,
		rock_cfg: Dictionary, color: Color) -> void:
	kind = size_kind
	position = at
	_velocity = velocity
	_spin = spin
	radius = float(rock_cfg.radius[size_kind])
	score = int(rock_cfg.score[size_kind])
	_outline.default_color = color
	_hull.color = color.darkened(0.72)

	collision_layer = AsteroidsLayers.ROCK
	collision_mask = 0
	monitoring = false
	monitorable = true

	var shape := CircleShape2D.new()
	shape.radius = radius
	_collision.shape = shape

	_build_outline(int(rock_cfg.vertices_min), int(rock_cfg.vertices_max),
			float(rock_cfg.jaggedness))


func velocity() -> Vector2:
	return _velocity


## Returns false when this rock was already broken this frame, so a bullet and
## the ship landing on the same rock cannot both claim it.
func shatter() -> bool:
	if _shattered:
		return false
	_shattered = true
	shattered.emit(kind, position)
	queue_free()
	return true


func is_shattered() -> bool:
	return _shattered


## A closed polygon whose vertices wander inward from `radius`; the fill and the
## outline are built from the same points so they always agree. The jitter only
## ever shortens a vertex, so the collision circle always circumscribes the
## drawn rock — a shot that looks like it connected never slips past.
func _build_outline(vertices_min: int, vertices_max: int, jaggedness: float) -> void:
	var count := randi_range(maxi(3, vertices_min), maxi(3, vertices_max))
	var points := PackedVector2Array()
	for i in count:
		var angle := TAU * float(i) / float(count)
		var r := radius * (1.0 - jaggedness * randf())
		points.append(Vector2.RIGHT.rotated(angle) * r)

	_hull.polygon = points
	var closed := points.duplicate()
	closed.append(points[0])
	_outline.points = closed


func _process(delta: float) -> void:
	position = AsteroidsField.wrap_point(position + _velocity * delta)
	rotation += _spin * delta
