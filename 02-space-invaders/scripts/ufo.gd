class_name InvaderUfo
extends Area2D
## High-value target crossing the top. Destroyed -> score popup only
## (no explosion), per design.

signal escaped
signal destroyed(score: int, at: Vector2)

@onready var _collision: CollisionShape2D = $Collision
@onready var _sprite: Sprite2D = $Sprite

var _speed := 160.0
var _dir := 1.0
var _score := 50


func setup(speed: float, score: int, from_left: bool, sprites: SpaceSprites, factor: float) -> void:
	_speed = speed
	_score = score
	_dir = 1.0 if from_left else -1.0

	collision_layer = SpaceLayers.UFO
	collision_mask = 0
	monitoring = false
	monitorable = true

	var shape := RectangleShape2D.new()
	shape.size = sprites.content_size("UFO", 0, factor)
	_collision.shape = shape
	_sprite.texture = sprites.make_atlas("UFO", 0)
	_sprite.scale = Vector2(factor, factor)


func _process(delta: float) -> void:
	position.x += _dir * _speed * delta
	if position.x < SpaceField.PLAY_RECT.position.x - 48.0 \
			or position.x > SpaceField.PLAY_RECT.end.x + 48.0:
		escaped.emit()
		queue_free()


func kill() -> void:
	destroyed.emit(_score, global_position)
	queue_free()
