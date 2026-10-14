class_name TetrisTutorial
extends Node2D

## The lessons. Each one wraps an ORDINARY run and watches its `locked` signal.
##
## The rules are not special-cased anywhere: a lesson only hands the run a
## starting position, a fixed deal order, and a goal to watch for. That is what
## makes anything learned here carry over to a real game.

signal finished
signal quit_requested

const PLAY_SCENE := preload("res://12-tetris/scenes/play.tscn")
## How long each half of a demonstration step is held: the ghost first, then
## the key that performs it. Long enough to read, short enough not to nag.
const DEMO_HOLD := 0.8

@onready var _banner_title: Label = $Banner/Title
@onready var _banner_hint: Label = $Banner/Hint
@onready var _demo_key: Label = $Banner/DemoKey
@onready var _message: CanvasLayer = $Message
@onready var _message_text: Label = $Message/Panel/Text
@onready var _message_hint: Label = $Message/Panel/Hint

var _settings: TetrisSettings
var _audio: TetrisAudio
var _levels: Array[Dictionary] = []
var _index: int = 0
var _play: TetrisPlay
## Whether the previous lock cleared anything, which is what a combo is.
var _cleared_last: bool = false
var _passed: bool = false
var _missed: bool = false
## Bumped on every lesson load, so a demonstration still waiting on a timer
## knows it has been superseded and stops writing to the screen.
var _demo_token: int = 0


func begin(settings: TetrisSettings, audio: TetrisAudio, index: int = 0) -> void:
	_settings = settings
	_audio = audio
	_levels = TutorialLevels.all()
	_configure_text()
	_load_lesson(index)


func _load_lesson(index: int) -> void:
	_index = index
	_passed = false
	_missed = false
	_cleared_last = false
	_demo_token += 1
	_message.visible = false
	_discard_run()

	_play = PLAY_SCENE.instantiate()
	add_child(_play)
	_play.begin(_settings, TetrisPlay.Mode.TUTORIAL, _audio, _levels[_index])
	_play.locked.connect(_on_locked)
	_play.finished.connect(_on_finished)
	_play.restart_requested.connect(_restart_lesson)

	var level := _levels[_index]
	_banner_title.text = level["title"]
	_banner_hint.text = level["hint"]
	_play_demo(level)


## Holds the run while the lesson's moves play out, then hands over.
##
## Each step shows the ghost first and the key second: the position is
## understood before the instruction to make it is read. The last step is also
## the solution, which is what a miss is measured against.
func _play_demo(level: Dictionary) -> void:
	var steps: Array = level.get("demo", [])
	if steps.is_empty():
		return
	var token := _demo_token
	_play.set_frozen(true)
	_play.field().set_ghost_visible(true)
	for step in steps:
		_play.field().show_demo(TutorialLevels.step_cells(step), step["kind"])
		_demo_key.text = ""
		await get_tree().create_timer(DEMO_HOLD).timeout
		if token != _demo_token:
			return
		_demo_key.text = step["key"]
		await get_tree().create_timer(DEMO_HOLD).timeout
		if token != _demo_token:
			return
	_play.field().clear_demo()
	_demo_key.text = ""
	_play.set_frozen(false)


func _on_locked(lines: int, spin: int) -> void:
	if _passed or _missed:
		return
	if not _landed_where_shown():
		_miss()
		return
	var hit := TutorialLevels.is_passed(_levels[_index]["goal"], lines, spin, _cleared_last)
	# Updated after the check: a combo needs the PREVIOUS lock to have cleared.
	_cleared_last = lines > 0
	if hit:
		_pass()


func _landed_where_shown() -> bool:
	return TutorialLevels.is_solution(_levels[_index], _play.last_locked_cells())


func _pass() -> void:
	_passed = true
	_play.stop()
	_message_text.text = _levels[_index]["done"]
	_message_hint.text = "SPACE to continue   /   ESC for the menu"
	_message.visible = true
	_audio.play(TetrisAudio.LEVEL)


## A lock somewhere the demonstration did not show. The position is fixed, so
## there is nothing to recover: say so plainly and start the lesson over.
func _miss() -> void:
	_missed = true
	_play.stop()
	_message_text.text = "Not the spot — watch the demonstration again."
	_message_hint.text = "SPACE to start this lesson over"
	_message.visible = true


## Topping out before the goal is met restarts the lesson rather than ending
## it: there is nothing to report and nothing else to do with a fixed position.
func _on_finished(_outcome: int, _score: int, _lines: int, _elapsed: int) -> void:
	if not _passed and not _missed:
		_load_lesson(_index)


## The pause menu's RESTART means "this lesson" in a tutorial, not "the whole
## tutorial" -- being sent back to lesson one is not what a stuck player asked
## for.
func _restart_lesson() -> void:
	_load_lesson(_index)


func _advance() -> void:
	if _index + 1 < _levels.size():
		_load_lesson(_index + 1)
	else:
		finished.emit()


func _discard_run() -> void:
	if _play == null:
		return
	remove_child(_play)
	_play.queue_free()
	_play = null


func _configure_text() -> void:
	var size := _settings.font_size
	for label in [_banner_title, _banner_hint, _demo_key, _message_text, _message_hint]:
		PixelFont.apply(label, size)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		quit_requested.emit()
		return
	if not (_passed or _missed):
		return
	if event.is_action_pressed("fire") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		if _missed:
			_load_lesson(_index)
		else:
			_advance()
