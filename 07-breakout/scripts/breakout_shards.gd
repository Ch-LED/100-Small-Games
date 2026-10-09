class_name BreakoutShards
extends Node2D
## A short burst of line shards flying out of a broken brick, in that brick's own
## colour. Purely visual — it holds no collision and never touches gameplay.
##
## Same shape as 05-asteroids' explosion (DECISION_LOG 015 note: the family is a
## candidate for plugins/, but extraction is its own activity, not a side effect
## of writing one more of them).

@onready var _shards: Node2D = $Shards

var _duration := 0.34
var _life := 0.34
var _velocities: Array[Vector2] = []
var _spins: Array[float] = []


## `cfg` is the [shards] section. `at` is where the brick was; `away` is the
## direction the ball was travelling, and the burst fans out AROUND it — the
## shards should look like they were carried through the brick by the ball, not
## like they were let off in place.
func setup(at: Vector2, color: Color, away: Vector2, cfg: Dictionary) -> void:
	position = at
	_duration = maxf(0.05, float(cfg.duration))
	_life = _duration

	var count := maxi(1, int(cfg.count))
	var half := float(cfg.length) * 0.5
	var spread := deg_to_rad(float(cfg.spread_deg))
	# A 180-degree fan centred on the travel direction.
	var base := away.angle() if away != Vector2.ZERO else Vector2.DOWN.angle()
	for i in count:
		var t := float(i) / float(maxi(1, count - 1))
		var angle := base - PI * 0.5 + t * PI + randf_range(-spread, spread)

		var shard := Line2D.new()
		shard.width = float(cfg.width)
		shard.default_color = color
		shard.points = PackedVector2Array([Vector2(-half, 0.0), Vector2(half, 0.0)])
		shard.rotation = angle
		_shards.add_child(shard)

		_velocities.append(Vector2.RIGHT.rotated(angle)
				* randf_range(float(cfg.speed) * 0.35, float(cfg.speed)))
		_spins.append(randf_range(-9.0, 9.0))


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
