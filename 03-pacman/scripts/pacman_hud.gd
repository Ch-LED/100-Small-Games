class_name PacmanHud
extends Control
## HUD lives in the side margins left over once the maze is scaled to fill the
## window: score and lives on the left, high score and fruit on the right.
##
## The nodes themselves are declared in pacman.tscn; this script only positions
## them (their layout depends on the runtime maze size) and fills them in.

const COLOR := Color(1, 1, 1)
const LABEL_COLOR := Color("9BA4C8")

@onready var _score_label: Label = $ScoreLabel
@onready var _score_value: Label = $ScoreValue
@onready var _lives_box: VBoxContainer = $Lives
@onready var _high_label: Label = $HighLabel
@onready var _high_value: Label = $HighValue
@onready var _fruit_box: VBoxContainer = $Fruits

var _sprites: PacmanSprites
var _lives_icons: Array[TextureRect] = []
var _fruit_icons: Array[TextureRect] = []
var _lives_shown := -1
var _fruits_shown := -1


func build(cfg: Dictionary, sprites: PacmanSprites) -> void:
	_sprites = sprites
	var size := int(cfg.hud.font_size)
	var margin: float = cfg.hud.margin
	var top := PacmanGrid.ORIGIN.y
	var bottom := PacmanGrid.ORIGIN.y + PacmanGrid.MAZE_SIZE.y
	var left_x := margin
	var right_x := PacmanGrid.ORIGIN.x + PacmanGrid.MAZE_SIZE.x + margin
	var right_w := PacmanGrid.FIELD.x - right_x - margin
	var line_h := size * 1.3

	_style(_score_label, size, LABEL_COLOR, HORIZONTAL_ALIGNMENT_LEFT)
	_score_label.text = "SCORE"
	_score_label.position = Vector2(left_x, top)

	_style(_score_value, size, COLOR, HORIZONTAL_ALIGNMENT_LEFT)
	_score_value.position = Vector2(left_x, top + line_h)

	_style(_high_label, size, LABEL_COLOR, HORIZONTAL_ALIGNMENT_RIGHT)
	_high_label.text = "HIGH"
	_high_label.position = Vector2(right_x, top)
	_high_label.size = Vector2(right_w, line_h)

	_style(_high_value, size, COLOR, HORIZONTAL_ALIGNMENT_RIGHT)
	_high_value.position = Vector2(right_x, top + line_h)
	_high_value.size = Vector2(right_w, line_h)

	_lives_box.position = Vector2(left_x, bottom - PacmanGrid.CELL * 2.2)
	_lives_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	_fruit_box.position = Vector2(right_x, bottom - PacmanGrid.CELL * 2.2)
	_fruit_box.alignment = BoxContainer.ALIGNMENT_END

	set_score(0, 0)


func _style(label: Label, size: int, color: Color, align: int) -> void:
	PixelFont.apply(label, size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = align


func set_score(score: int, high: int) -> void:
	_score_value.text = "%06d" % score
	_high_value.text = "%06d" % high


## Lives stack downward in the left margin.
func set_lives(count: int) -> void:
	if count == _lives_shown:
		return
	_lives_shown = count
	while _lives_icons.size() < count:
		var icon := _make_icon(_sprites.texture("pacman", "right", 0))
		_lives_box.add_child(icon)
		_lives_icons.append(icon)
	for i in _lives_icons.size():
		_lives_icons[i].visible = i < count


## Fruits collected this level stack downward in the right margin.
func set_level_fruits(count: int) -> void:
	if count == _fruits_shown:
		return
	_fruits_shown = count
	while _fruit_icons.size() < count:
		var icon := _make_icon(_sprites.texture("fruit", "cherry", 0))
		_fruit_box.add_child(icon)
		_fruit_icons.append(icon)
	for i in _fruit_icons.size():
		_fruit_icons[i].visible = i < count


func _make_icon(texture: Texture2D) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(PacmanGrid.CELL, PacmanGrid.CELL)
	return icon
