class_name AsteroidsHud
extends Control
## Top bar: score, high score and wave as text, remaining lives as little ship
## triangles along the bottom left. The nodes are declared in asteroids.tscn;
## this script only positions and fills them.

const LABEL_COLOR := Color("6E86B0")
const VALUE_COLOR := Color("E8F1FF")
const SHIP_SHAPE: Array[Vector2] = [
	Vector2(18.0, 0.0), Vector2(-12.0, 12.0), Vector2(-7.0, 0.0), Vector2(-12.0, -12.0),
]
const SHIP_SHAPE_UNIT := 14.0

@onready var _score_label: Label = $ScoreLabel
@onready var _score_value: Label = $ScoreValue
@onready var _high_label: Label = $HighLabel
@onready var _high_value: Label = $HighValue
@onready var _wave_label: Label = $WaveLabel
@onready var _wave_value: Label = $WaveValue
@onready var _lives: Node2D = $Lives

var _icon_color := Color("E8F1FF")
var _icon_polygon := PackedVector2Array()
var _icon_step := 26.0
var _icons: Array[Polygon2D] = []
var _lives_shown := -1


func build(cfg: Dictionary) -> void:
	var size := int(cfg.hud.font_size)
	var margin: float = cfg.hud.margin
	var line_h := float(size) * 1.6
	var label_y := margin * 0.55
	var value_y := label_y + line_h

	_icon_color = cfg.field.ship_color
	var icon_radius: float = float(cfg.ship.radius) * float(cfg.hud.lives_icon_scale)
	_icon_polygon = _build_icon(icon_radius)
	_icon_step = icon_radius * 2.8

	_column(_score_label, _score_value, "SCORE", margin, label_y, value_y, size,
			HORIZONTAL_ALIGNMENT_LEFT)
	_column(_high_label, _high_value, "HIGH", margin + 330.0, label_y, value_y, size,
			HORIZONTAL_ALIGNMENT_LEFT)

	var right_w := 260.0
	var right_x := AsteroidsField.SIZE.x - margin - right_w
	_column(_wave_label, _wave_value, "WAVE", right_x, label_y, value_y, size,
			HORIZONTAL_ALIGNMENT_RIGHT, right_w)

	_lives.position = Vector2(margin, AsteroidsField.SIZE.y - margin - icon_radius * 1.2)
	set_score(0, 0)
	set_wave(1)
	set_lives(0)


func _column(label: Label, value: Label, title: String, x: float, label_y: float,
		value_y: float, size: int, align: int, width: float = 0.0) -> void:
	var line_h := float(size) * 1.6
	PixelFont.apply(label, size)
	label.add_theme_color_override("font_color", LABEL_COLOR)
	label.text = title
	label.horizontal_alignment = align
	label.position = Vector2(x, label_y)

	PixelFont.apply(value, size)
	value.add_theme_color_override("font_color", VALUE_COLOR)
	value.horizontal_alignment = align
	value.position = Vector2(x, value_y)

	if width > 0.0:
		label.size = Vector2(width, line_h)
		value.size = Vector2(width, line_h)


func set_score(score: int, high: int) -> void:
	_score_value.text = "%06d" % score
	_high_value.text = "%06d" % high


func set_wave(wave: int) -> void:
	_wave_value.text = "%02d" % wave


## Small ship triangles, one per remaining life.
func set_lives(count: int) -> void:
	if count == _lives_shown:
		return
	_lives_shown = count
	while _icons.size() < count:
		var icon := Polygon2D.new()
		icon.polygon = _icon_polygon
		icon.color = _icon_color
		icon.position = Vector2(_icon_step * float(_icons.size()), 0.0)
		_lives.add_child(icon)
		_icons.append(icon)
	for i in _icons.size():
		_icons[i].visible = i < count


func _build_icon(radius: float) -> PackedVector2Array:
	var factor := radius / SHIP_SHAPE_UNIT
	var out := PackedVector2Array()
	for point in SHIP_SHAPE:
		out.append(point * factor)
	return out
