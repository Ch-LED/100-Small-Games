class_name TetrisResult
extends Control

## What the run came to, and whether it beat what was there.
##
## The two modes report different things: a marathon is a score, a sprint is a
## time. Both show the record they were measured against, because a number with
## nothing to compare it to says very little.

signal again_requested
signal menu_requested

@onready var _backdrop: ColorRect = $Backdrop
@onready var _outcome: Label = $Center/Column/Outcome
@onready var _figure: Label = $Center/Column/Figure
@onready var _detail: Label = $Center/Column/Detail
@onready var _record: Label = $Center/Column/Record
@onready var _hint: Label = $Center/Column/Hint


func configure(
	settings: TetrisSettings,
	mode: int,
	outcome: int,
	score: int,
	lines: int,
	elapsed_ms: int,
	is_record: bool,
	save: TetrisSave
) -> void:
	var size := settings.font_size
	_backdrop.color = settings.board_bg
	PixelFont.apply(_outcome, size * 2)
	PixelFont.apply(_figure, size * 2)
	PixelFont.apply(_detail, size)
	PixelFont.apply(_record, size)
	PixelFont.apply(_hint, size)

	var sprint := mode == TetrisPlay.Mode.SPRINT
	_outcome.text = _outcome_text(sprint, outcome)
	if sprint:
		_figure.text = TetrisSave.format_time(elapsed_ms)
		_detail.text = "%d / %d ROWS" % [lines, settings.sprint_lines]
		_record.text = (
			"NEW RECORD" if is_record
			else "FASTEST  %s" % TetrisSave.format_time(save.best_sprint_ms)
		)
	else:
		_figure.text = "%d" % score
		_detail.text = "%d LINES   LEVEL %d" % [lines, 1 + lines / TetrisScoring.LINES_PER_LEVEL]
		_record.text = "NEW RECORD" if is_record else "BEST  %d" % save.best_score
	_record.add_theme_color_override("font_color", settings.super_color if is_record else Color("6E86B0"))
	_hint.text = "SPACE to play again   /   ESC for the menu"


func _outcome_text(sprint: bool, outcome: int) -> String:
	if sprint:
		return "SPRINT COMPLETE" if outcome == TetrisPlay.Outcome.SPRINT_DONE else "TOPPED OUT"
	return "GAME OVER"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fire") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		again_requested.emit()
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		menu_requested.emit()
