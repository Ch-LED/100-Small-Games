class_name InvaderPlayer
extends Area2D
## Player ship: horizontal movement (input aggregated by Game) plus an
## invulnerability window after being hit, shown as a blink.

signal hit_taken

var _speed := 320.0
var _sprites: SpaceSprites
var _factor := 4.0
var _sprite: Sprite2D
var _dir := 0.0
var _invuln := 0.0
var _blink_t := 0.0


func setup(speed: float, sprites: SpaceSprites, factor: float) -> void:
	_speed = speed
	_sprites = sprites
	_factor = factor

	collision_layer = SpaceLayers.PLAYER
	collision_mask = 0
	monitoring = false
	monitorable = true

	var shape := RectangleShape2D.new()
	shape.size = sprites.content_size("player", 0, factor)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)

	_sprite = sprites.make_sprite("player", 0, factor)
	add_child(_sprite)


func _process(delta: float) -> void:
	_move(delta)
	_tick_invulnerability(delta)


func set_direction(dir: float) -> void:
	_dir = clampf(dir, -1.0, 1.0)


func set_invulnerable(seconds: float) -> void:
	_invuln = maxf(_invuln, seconds)


func is_invulnerable() -> bool:
	return _invuln > 0.0


func take_hit() -> void:
	if is_invulnerable():
		return
	hit_taken.emit()


## Swaps the ship for the explosion frame; also cancels any blink-invulnerability
## so the wreck stays solidly visible.
func explode() -> void:
	_invuln = 0.0
	_sprite.visible = true
	_sprite.texture = _sprites.make_atlas("explode", 0)


func _move(delta: float) -> void:
	if is_zero_approx(_dir):
		return
	var half_width := _sprites.content_size("player", 0, _factor).x * 0.5
	var play := SpaceField.PLAY_RECT
	position.x = clampf(position.x + _dir * _speed * delta,
			play.position.x + half_width, play.end.x - half_width)


func _tick_invulnerability(delta: float) -> void:
	if _invuln <= 0.0:
		return
	_invuln -= delta
	_blink_t += delta
	_sprite.visible = fmod(_blink_t, 0.16) < 0.08
	if _invuln <= 0.0:
		_sprite.visible = true
