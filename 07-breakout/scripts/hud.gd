class_name BreakoutHud
extends Control
## Top bar: score and level on the left, high score and lives on the right.
## The nodes are declared in breakout.tscn; this script only positions and fills
## them.

const LABEL_COLOR := Color("6E86B0")
const VALUE_COLOR := Color("E8F1FF")

@onready var _score_label: Label = $ScoreLabel
@onready var _score_value: Label = $ScoreValue
@onready var _high_label: Label = $HighLabel
@onready var _high_value: Label = $HighValue
@onready var _level_label: Label = $LevelLabel
@onready var _level_value: Label = $LevelValue
@onready var _lives_label: Label = $LivesLabel
@onready var _lives_value: Label = $LivesValue
@onready var _combo_label: Label = $ComboLabel


func build(cfg: Dictionary) -> void:
	var size := int(cfg.hud.font_size)
	var margin: float = cfg.hud.margin
	var line_h := float(size) * 1.6
	var label_y := margin * 0.4
	var value_y := label_y + line_h

	_column(_score_label, _score_value, "SCORE", margin, label_y, value_y, size,
			HORIZONTAL_ALIGNMENT_LEFT)
	_column(_high_label, _high_value, "HIGH", margin + 300.0, label_y, value_y, size,
			HORIZONTAL_ALIGNMENT_LEFT)
	_column(_level_label, _level_value, "LEVEL", margin + 620.0, label_y, value_y, size,
			HORIZONTAL_ALIGNMENT_LEFT)

	var right_w := 220.0
	var right_x := BreakoutField.SIZE.x - margin - right_w
	_column(_lives_label, _lives_value, "LIVES", right_x, label_y, value_y, size,
			HORIZONTAL_ALIGNMENT_RIGHT, right_w)

	# The combo sits under the score row, centred: it only appears while a run
	# is actually paying, so it never competes with the standing readouts.
	PixelFont.apply(_combo_label, size)
	_combo_label.add_theme_color_override("font_color", cfg.hud.combo_color)
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combo_label.position = Vector2(0.0, value_y + line_h * 0.9)
	_combo_label.size = Vector2(BreakoutField.SIZE.x, line_h)
	_combo_label.text = ""

	set_score(0, 0)
	set_level(1)
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


func set_level(level: int) -> void:
	_level_value.text = "%02d" % level


func set_lives(lives: int) -> void:
	_lives_value.text = "%02d" % lives


## Only speaks up once the run is worth something: `multiplier` of 1 is just
## ordinary play, so the badge stays away.
func set_combo(combo: int, multiplier: int) -> void:
	if combo <= 0 or multiplier <= 1:
		_combo_label.text = ""
		return
	_combo_label.text = "COMBO %d   x%d" % [combo, multiplier]
