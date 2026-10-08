class_name SimonHud
extends Control
## Top bar: the round being attempted on the left, the best run on the right.
## The nodes are declared in simon.tscn; this script only positions and fills
## them.

const LABEL_COLOR := Color("6E86B0")
const VALUE_COLOR := Color("E8F1FF")

@onready var _round_label: Label = $RoundLabel
@onready var _round_value: Label = $RoundValue
@onready var _best_label: Label = $BestLabel
@onready var _best_value: Label = $BestValue


func build(cfg: Dictionary) -> void:
	var size := int(cfg.hud.font_size)
	var margin: float = cfg.hud.margin
	var line_h := float(size) * 1.6
	var label_y := margin * 0.5
	var value_y := label_y + line_h

	_column(_round_label, _round_value, "ROUND", margin, label_y, value_y, size,
			HORIZONTAL_ALIGNMENT_LEFT)

	var right_w := 260.0
	var right_x := SimonBoard.SIZE.x - margin - right_w
	_column(_best_label, _best_value, "BEST", right_x, label_y, value_y, size,
			HORIZONTAL_ALIGNMENT_RIGHT, right_w)

	set_round(1)
	set_best(0)


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


func set_round(round_number: int) -> void:
	_round_value.text = "%02d" % round_number


## Best is counted in sequences cleared, so it starts at 0.
func set_best(sequences_cleared: int) -> void:
	_best_value.text = "%02d" % sequences_cleared
