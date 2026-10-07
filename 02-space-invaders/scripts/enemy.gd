class_name InvaderEnemy
extends Area2D
## One invader. Animation frames are pushed by EnemyGrid via set_frame() so
## the whole formation animates in lockstep.

const KIND_SQUID := "squid"
const KIND_CLAUDE := "claude"
const KIND_JELLY := "jelly"

## Emitted only when shot down, never on wave cleanup.
signal killed(score: int, at: Vector2)

var kind := KIND_JELLY
var score := 10

var _frames: Array[AtlasTexture] = []
var _sprite: Sprite2D
var _dead := false


func setup(kind_name: String, score_value: int, sprites: SpaceSprites, factor: float) -> void:
	kind = kind_name
	score = score_value

	collision_layer = SpaceLayers.ENEMY
	collision_mask = 0
	monitoring = false
	monitorable = true

	for i in sprites.frame_count(kind):
		_frames.append(sprites.make_atlas(kind, i))

	var shape := RectangleShape2D.new()
	shape.size = sprites.content_size(kind, 0, factor)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)

	_sprite = sprites.make_sprite(kind, 0, factor)
	add_child(_sprite)


func set_frame(index: int) -> void:
	if _frames.is_empty():
		return
	_sprite.texture = _frames[posmod(index, _frames.size())]


func kill() -> void:
	if _dead:
		return
	_dead = true
	killed.emit(score, global_position)
	queue_free()
