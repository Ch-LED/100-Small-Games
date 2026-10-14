class_name TetrisHud
extends Control

## The run's numbers, down the left of the board. The nodes are declared in
## play.tscn; this script only places them and fills them in.

const LABEL_COLOR := Color("6E86B0")
const VALUE_COLOR := Color("E8F1FF")
## Brighter than the numbers on purpose: this line only appears when something
## worth noticing just happened.
const EVENT_COLOR := Color("FFD24A")

@onready var _score_label: Label = $ScoreLabel
@onready var _score_value: Label = $ScoreValue
@onready var _level_label: Label = $LevelLabel
@onready var _level_value: Label = $LevelValue
@onready var _lines_label: Label = $LinesLabel
@onready var _lines_value: Label = $LinesValue
@onready var _time_label: Label = $TimeLabel
@onready var _time_value: Label = $TimeValue
@onready var _event_value: Label = $EventValue


func build(settings: TetrisSettings) -> void:
	var size := settings.font_size
	var row := float(size) * 2.8
	_place(_score_label, _score_value, "SCORE", 0.0, size)
	_place(_level_label, _level_value, "LEVEL", row, size)
	_place(_lines_label, _lines_value, "LINES", row * 2.0, size)
	_place(_time_label, _time_value, "TIME", row * 3.0, size)
	PixelFont.apply(_event_value, size)
	_event_value.add_theme_color_override("font_color", EVENT_COLOR)
	_event_value.position = Vector2(0.0, row * 4.0)
	update_stats(0, 1, 0)
	update_clock(0)
	show_event("")
	set_sprint(false)


## Only a sprint is raced, so only a sprint shows a clock.
func set_sprint(shown: bool) -> void:
	_time_label.visible = shown
	_time_value.visible = shown


func update_stats(score: int, level: int, lines: int) -> void:
	_score_value.text = str(score)
	_level_value.text = str(level)
	_lines_value.text = str(lines)


func update_clock(milliseconds: int) -> void:
	_time_value.text = TetrisSave.format_time(milliseconds)


## Names whatever the last lock did. Cleared on anything unremarkable, so the
## line only ever lights up for something worth noticing.
func show_event(text: String) -> void:
	_event_value.text = text


func _place(label: Label, value: Label, title: String, y: float, font_size: int) -> void:
	PixelFont.apply(label, font_size)
	PixelFont.apply(value, font_size)
	label.text = title
	label.add_theme_color_override("font_color", LABEL_COLOR)
	label.position = Vector2(0.0, y)
	value.add_theme_color_override("font_color", VALUE_COLOR)
	value.position = Vector2(0.0, y + float(font_size) * 1.4)
