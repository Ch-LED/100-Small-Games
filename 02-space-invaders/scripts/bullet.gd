class_name InvaderBullet
extends Area2D
## Straight-flying bullet. Player bullets travel up, enemy bullets down.
## Resolves whatever it touches by type, then frees itself once.

const KIND_LAZER := "lazer"
const KIND_ENERGY := "plaz"
const KIND_DART := "drat"
## The `]` super cheat's colour, the same in every game in this project.
const SUPER_COLOR := Color("00E676")

@onready var _collision: CollisionShape2D = $Collision
@onready var _sprite: Sprite2D = $Sprite

var is_player := false

var _speed := 900.0
var _dir := -1.0
## Travels along this, so homing can bend it. Straight up or straight down
## unless the super cheat is aiming it.
var _direction := Vector2.ZERO
## The `]` super cheat: chase the nearest invader. `_fleet` is handed over by
## whoever spawned the shot.
var _homing := false
var _seek: Homing = null
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
	_direction = Vector2(0.0, _dir)

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
	_steer_home(delta)
	position += _direction * _speed * delta
	_animate(delta)
	if _is_offscreen():
		queue_free()


## The super cheat: turn toward the nearest living invader, so a wave can be
## cleared without aiming. Green, so the state is visible in flight.
func set_homing(fleet: EnemyGrid, rate: float) -> void:
	_homing = true
	_seek = Homing.new(_nearest_target.bind(fleet), rate)
	_sprite.modulate = SUPER_COLOR


## What a shot aims at: the nearest living invader, or null when the formation is
## empty — the plugin then leaves the shot flying straight on.
func _nearest_target(_from: Vector2, fleet: EnemyGrid):
	var enemy := fleet.nearest_alive_to(global_position)
	return null if enemy == null else enemy.global_position


## Chases the nearest invader, and straightens back out to fly on when there is
## nothing left to chase.
func _steer_home(delta: float) -> void:
	if _seek == null:
		return
	_direction = _seek.steer(global_position, _direction, delta)


func _animate(delta: float) -> void:
	if _frames.size() < 2:
		return
	_anim_t += delta
	if _anim_t < 1.0 / _anim_fps:
		return
	_anim_t = 0.0
	_index += 1
	_sprite.texture = _frames[_index % _frames.size()]


## The x bounds matter once a shot is homing: a bent shot can leave the field
## sideways without ever reaching the top or bottom.
func _is_offscreen() -> bool:
	return position.y < -32.0 or position.y > SpaceField.SIZE.y + 32.0 \
			or position.x < -32.0 or position.x > SpaceField.SIZE.x + 32.0


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
