class_name Game2048Hud
extends Control
## Top bar: score, best and the largest tile of this run on the left, and a tag
## naming whichever cheats are on. The nodes are declared in twenty48.tscn; this
## script only positions and fills them.

const LABEL_COLOR := Color("8A7F73")
const VALUE_COLOR := Color("4A423A")
const CHEAT_COLOR := Color("C2472F")
## The super cheat reads in the colour it wears in every game of the collection.
const SUPER_COLOR := Color("00E676")

@onready var _score_label: Label = $ScoreLabel
@onready var _score_value: Label = $ScoreValue
@onready var _best_label: Label = $BestLabel
@onready var _best_value: Label = $BestValue
@onready var _max_label: Label = $MaxLabel
@onready var _max_value: Label = $MaxValue
@onready var _cheat_label: Label = $CheatLabel


func build(cfg: Dictionary) -> void:
	var size := int(cfg.hud.font_size)
	var margin: float = cfg.hud.margin
	var line_h := float(size) * 1.6
	var label_y := margin * 0.4
	var value_y := label_y + line_h

	var column := margin
	for pair in [["SCORE", _score_label, _score_value],
			["BEST", _best_label, _best_value],
			["MAX", _max_label, _max_value]]:
		_column(pair[1], pair[2], str(pair[0]), column, label_y, value_y, size,
				HORIZONTAL_ALIGNMENT_LEFT)
		column += 260.0

	var right_w := 220.0
	PixelFont.apply(_cheat_label, size)
	_cheat_label.add_theme_color_override("font_color", CHEAT_COLOR)
	_cheat_label.text = ""
	_cheat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_cheat_label.position = Vector2(
			Game2048Settings.FIELD.x - margin - right_w, value_y)
	_cheat_label.size = Vector2(right_w, line_h)

	set_score(0, 0)
	set_max(0)


func _column(label: Label, value: Label, title: String, x: float, label_y: float,
		value_y: float, size: int, align: int) -> void:
	PixelFont.apply(label, size)
	label.add_theme_color_override("font_color", LABEL_COLOR)
	label.text = title
	label.horizontal_alignment = align
	label.position = Vector2(x, label_y)

	PixelFont.apply(value, size)
	value.add_theme_color_override("font_color", VALUE_COLOR)
	value.horizontal_alignment = align
	value.position = Vector2(x, value_y)


func set_score(score: int, best: int) -> void:
	_score_value.text = "%06d" % score
	_best_value.text = "%06d" % best


func set_max(value: int) -> void:
	_max_value.text = "%d" % value


## The tag is the only place either cheat is named, and the two are independent
## toggles, so it composes from both. The super one takes the colour because it is
## the one that changes what the game does.
func set_cheat(no_spawn: bool, max_spawn: bool) -> void:
	var parts := PackedStringArray()
	if no_spawn:
		parts.append("NO SPAWN")
	if max_spawn:
		parts.append("MAX SPAWN")
	_cheat_label.text = " + ".join(parts)
	_cheat_label.add_theme_color_override("font_color",
			SUPER_COLOR if max_spawn else CHEAT_COLOR)
