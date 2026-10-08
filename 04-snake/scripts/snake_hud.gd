class_name SnakeHud
extends Control
## Top information band: score, level and length on the left, best on the right.
## The nodes are declared in snake.tscn; this script only positions and fills
## them (their layout depends on the runtime board size).

const LABEL_COLOR := Color("8FA3BF")
const VALUE_COLOR := Color(1, 1, 1)
const COLUMN_X: Array[float] = [0.0, 360.0, 680.0]
const BEST_WIDTH := 320.0

@onready var _score_label: Label = $ScoreLabel
@onready var _score_value: Label = $ScoreValue
@onready var _level_label: Label = $LevelLabel
@onready var _level_value: Label = $LevelValue
@onready var _length_label: Label = $LengthLabel
@onready var _length_value: Label = $LengthValue
@onready var _best_label: Label = $BestLabel
@onready var _best_value: Label = $BestValue


func build(cfg: Dictionary) -> void:
	var size := int(cfg.hud.font_size)
	var margin: float = cfg.hud.margin
	var band := SnakeGrid.ORIGIN.y
	var label_y := band * 0.16
	var value_y := band * 0.50

	_column(_score_label, _score_value, "SCORE", margin, label_y, value_y, size,
			HORIZONTAL_ALIGNMENT_LEFT)
	_column(_level_label, _level_value, "LEVEL", COLUMN_X[1], label_y, value_y, size,
			HORIZONTAL_ALIGNMENT_LEFT)
	_column(_length_label, _length_value, "LENGTH", COLUMN_X[2], label_y, value_y, size,
			HORIZONTAL_ALIGNMENT_LEFT)

	var right_x := SnakeGrid.FIELD.x - margin - BEST_WIDTH
	_column(_best_label, _best_value, "BEST", right_x, label_y, value_y, size,
			HORIZONTAL_ALIGNMENT_RIGHT, BEST_WIDTH)
	set_score(0, 0)


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


func set_score(score: int, best: int) -> void:
	_score_value.text = "%06d" % score
	_best_value.text = "%06d" % best


func set_level(level: int) -> void:
	_level_value.text = "%02d" % level


func set_length(length: int) -> void:
	_length_value.text = "%03d" % length
