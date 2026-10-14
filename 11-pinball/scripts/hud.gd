class_name PinballHud
extends Control
## Score, balls, and the end-of-run card. Read-only in the strict sense: nothing
## here decides anything, it only shows what the run above tells it.

@onready var _run: Control = $Run
@onready var _running_score: Label = $Run/Score
@onready var _balls: Label = $Run/Balls
@onready var _result: Control = $Result
@onready var _title: Label = $Result/Center/Column/Title
@onready var _final_score: Label = $Result/Center/Column/Score
@onready var _best: Label = $Result/Center/Column/Best
@onready var _hint: Label = $Result/Center/Column/Hint


func configure(font_size: int) -> void:
	PixelFont.apply(_running_score, font_size)
	PixelFont.apply(_balls, font_size)
	PixelFont.apply(_title, font_size * 2)
	PixelFont.apply(_final_score, font_size)
	PixelFont.apply(_best, font_size)
	PixelFont.apply(_hint, font_size)


## The score and the ball count belong to a ball in play; the menu does not want
## them on screen.
func set_run_visible(on: bool) -> void:
	_run.visible = on


func set_run_state(balls_left: int, score: int) -> void:
	_balls.text = "BALLS %d" % balls_left
	_running_score.text = "SCORE %d" % score


func show_result(score: int, best: int, record: bool) -> void:
	_final_score.text = "SCORE %d" % score
	_best.text = "NEW RECORD" if record else "BEST %d" % best
	_result.visible = true


func hide_result() -> void:
	_result.visible = false
