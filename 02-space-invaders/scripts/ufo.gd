class_name InvaderUfo
extends Area2D
## High-value target crossing the top. Destroyed -> score popup only
## (no explosion), per design.

signal escaped
signal destroyed(score: int, at: Vector2)

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
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)

	add_child(sprites.make_sprite("UFO", 0, factor))


func _process(delta: float) -> void:
	position.x += _dir * _speed * delta
	if position.x < SpaceField.PLAY_RECT.position.x - 48.0 \
			or position.x > SpaceField.PLAY_RECT.end.x + 48.0:
		escaped.emit()
		queue_free()


func kill() -> void:
	destroyed.emit(_score, global_position)
	queue_free()
