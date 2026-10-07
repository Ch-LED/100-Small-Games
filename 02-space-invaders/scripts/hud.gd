class_name InvaderHud
extends Control
## Top bar: six-digit score on the left, remaining lives on the right.
## The two holders are scene nodes with their anchors already set
## (CONSTITUTION 5.5); this only fills in the font, digits and life icons.

@onready var _score_label: Label = %ScoreLabel
@onready var _lives_box: HBoxContainer = %LivesBox

var _sprites: SpaceSprites
var _factor := 4.0
var _lives_icons: Array[TextureRect] = []


func build(cfg: Dictionary, sprites: SpaceSprites, factor: float) -> void:
	_sprites = sprites
	_factor = factor
	var margin: float = cfg.hud.margin

	PixelFont.apply(_score_label, int(cfg.hud.score_size))
	_score_label.add_theme_color_override("font_color", Color(0.93, 0.96, 1.0))
	_score_label.text = "000000"
	_score_label.position = Vector2(margin, margin)

	_lives_box.offset_top = margin
	_lives_box.offset_right = -margin


func set_score(value: int) -> void:
	_score_label.text = "%06d" % value


func set_lives(count: int) -> void:
	while _lives_icons.size() < count:
		var icon := TextureRect.new()
		icon.texture = _sprites.make_atlas("player", 0)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = _sprites.content_size("player", 0, _factor)
		_lives_box.add_child(icon)
		_lives_icons.append(icon)
	for i in _lives_icons.size():
		_lives_icons[i].visible = i < count
