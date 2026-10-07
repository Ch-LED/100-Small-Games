class_name FortTile
extends Area2D
## One destructible shield tile. Takes `max_hp` hits; the frame index advances
## with damage and the tile frees itself at zero.

## Tag names as authored in the aseprite file (kept verbatim).
const TAG_SQUARE := "frot_sqr"
const TAG_TRIANGLE := "frot_tri"

var _sprites: SpaceSprites
var _tag := TAG_SQUARE
var _factor := 4.0
var _hp := 4
var _max_hp := 4
var _sprite: Sprite2D
var _body_size := Vector2.ZERO


func setup(tag: String, hp: int, sprites: SpaceSprites, factor: float) -> void:
	_tag = tag
	_hp = hp
	_max_hp = hp
	_sprites = sprites
	_factor = factor

	collision_layer = SpaceLayers.SHIELD
	collision_mask = 0
	monitoring = false
	monitorable = true

	_body_size = sprites.content_size(tag, 0, factor)
	var shape := RectangleShape2D.new()
	shape.size = _body_size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)

	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2(factor, factor)
	add_child(_sprite)
	_refresh()


func take_hit() -> void:
	_hp -= 1
	if _hp <= 0:
		queue_free()
		return
	_refresh()


func set_flip(flip_h: bool, flip_v: bool) -> void:
	_sprite.flip_h = flip_h
	_sprite.flip_v = flip_v


func global_rect() -> Rect2:
	return Rect2(global_position - _body_size * 0.5, _body_size)


func _refresh() -> void:
	_sprite.texture = _sprites.make_atlas(_tag, _max_hp - _hp)
