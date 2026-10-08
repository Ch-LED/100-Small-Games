class_name LightsOutHud
extends Control
## Top bar: the level, how many presses this puzzle has taken, and how many
## puzzles this run has solved. The nodes are declared in lights-out.tscn; this
## script only positions and fills them.

const LABEL_COLOR := Color("6E86B0")
const VALUE_COLOR := Color("E8F1FF")

@onready var _level_label: Label = $LevelLabel
@onready var _level_value: Label = $LevelValue
@onready var _press_label: Label = $PressLabel
@onready var _press_value: Label = $PressValue
@onready var _solved_label: Label = $SolvedLabel
@onready var _solved_value: Label = $SolvedValue


func build(cfg: Dictionary) -> void:
	var size := int(cfg.hud.font_size)
	var margin: float = cfg.hud.margin
	var line_h := float(size) * 1.6
	var label_y := margin * 0.4
	var value_y := label_y + line_h

	_column(_level_label, _level_value, "LEVEL", margin, label_y, value_y, size)
	_column(_press_label, _press_value, "PRESSES", margin + 300.0, label_y, value_y, size)

	var right_w := 260.0
	var right_x := LightsOutSettings.FIELD.x - margin - right_w
	_column(_solved_label, _solved_value, "SOLVED", right_x, label_y, value_y, size, right_w)

	set_level(1)
	set_presses(0)
	set_solved(0)


func _column(label: Label, value: Label, title: String, x: float, label_y: float,
		value_y: float, size: int, width: float = 0.0) -> void:
	var line_h := float(size) * 1.6
	PixelFont.apply(label, size)
	label.add_theme_color_override("font_color", LABEL_COLOR)
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.position = Vector2(x, label_y)

	PixelFont.apply(value, size)
	value.add_theme_color_override("font_color", VALUE_COLOR)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	value.position = Vector2(x, value_y)

	if width > 0.0:
		label.size = Vector2(width, line_h)
		value.size = Vector2(width, line_h)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func set_level(level: int) -> void:
	_level_value.text = "%02d" % level


func set_presses(presses: int) -> void:
	_press_value.text = "%03d" % presses


func set_solved(solved: int) -> void:
	_solved_value.text = "%02d" % solved
