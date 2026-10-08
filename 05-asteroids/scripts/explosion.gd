class_name AsteroidsExplosion
extends Node2D
## A short burst of line shards flying apart and fading out. Purely visual —
## it holds no collision and never touches gameplay.

@onready var _shards: Node2D = $Shards

var _duration := 0.6
var _life := 0.6
var _velocities: Array[Vector2] = []
var _spins: Array[float] = []


## `count` is the number of shards, `length` how long each one is.
func setup(at: Vector2, count: int, length: float, color: Color, duration: float,
		spread: float) -> void:
	position = at
	_duration = maxf(0.05, duration)
	_life = _duration

	for i in maxi(1, count):
		var shard := Line2D.new()
		shard.width = 2.0
		shard.default_color = color
		var half := length * 0.5
		shard.points = PackedVector2Array([Vector2(-half, 0.0), Vector2(half, 0.0)])

		var angle := TAU * float(i) / float(maxi(1, count)) + randf_range(-0.35, 0.35)
		shard.rotation = angle
		_shards.add_child(shard)
		_velocities.append(Vector2.RIGHT.rotated(angle) * randf_range(spread * 0.35, spread))
		_spins.append(randf_range(-7.0, 7.0))


func _process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return

	var children := _shards.get_children()
	for i in children.size():
		var shard: Node2D = children[i]
		shard.position += _velocities[i] * delta
		shard.rotation += _spins[i] * delta

	modulate.a = clampf(_life / _duration, 0.0, 1.0)
