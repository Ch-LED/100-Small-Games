class_name InvaderBullet
extends Area2D
## Straight-flying bullet. Player bullets travel up, enemy bullets down.
## Resolves whatever it touches by type, then frees itself once.

const KIND_LAZER := "lazer"
const KIND_ENERGY := "plaz"
const KIND_DART := "drat"

@onready var _collision: CollisionShape2D = $Collision
@onready var _sprite: Sprite2D = $Sprite

var is_player := false

var _speed := 900.0
var _dir := -1.0
var _frames: Array[AtlasTexture] = []
var _index := 0
var _anim_t := 0.0
var _anim_fps := 8.0
var _consumed := false


func setup(tag: String, speed: float, travel_up: bool, sprites: SpaceSprites, factor: float,
		min_size := Vector2.ZERO) -> void:
	is_player = travel_up
	_speed = speed
	_dir = -1.0 if travel_up else 1.0

	collision_layer = SpaceLayers.PLAYER_BULLET if travel_up else SpaceLayers.ENEMY_BULLET
	if travel_up:
		collision_mask = SpaceLayers.ENEMY | SpaceLayers.SHIELD | SpaceLayers.UFO
	else:
		collision_mask = SpaceLayers.PLAYER | SpaceLayers.SHIELD
	monitoring = true
	monitorable = false

	for i in sprites.frame_count(tag):
		_frames.append(sprites.make_atlas(tag, i))

	var body := sprites.content_size(tag, 0, factor)
	body.x = maxf(body.x, min_size.x)
	body.y = maxf(body.y, min_size.y)
	var shape := RectangleShape2D.new()
	shape.size = body
	_collision.shape = shape
	_sprite.texture = _frames[0] if not _frames.is_empty() else null
	_sprite.scale = Vector2(factor, factor)

	area_entered.connect(_on_area_entered)


func _process(delta: float) -> void:
	position.y += _dir * _speed * delta
	_animate(delta)
	if _is_offscreen():
		queue_free()


func _animate(delta: float) -> void:
	if _frames.size() < 2:
		return
	_anim_t += delta
	if _anim_t < 1.0 / _anim_fps:
		return
	_anim_t = 0.0
	_index += 1
	_sprite.texture = _frames[_index % _frames.size()]


func _is_offscreen() -> bool:
	return position.y < -32.0 or position.y > SpaceField.SIZE.y + 32.0


func _on_area_entered(area: Area2D) -> void:
	if _consumed:
		return
	_consumed = true
	if area is FortTile:
		area.take_hit()
	elif is_player and area is InvaderEnemy:
		area.kill()
	elif is_player and area is InvaderUfo:
		area.kill()
	elif not is_player and area is InvaderPlayer:
		area.take_hit()
	queue_free()
