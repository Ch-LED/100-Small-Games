extends Node
## The run, and everything around it: which screen is up, how many balls are
## left, what the score is, and what is remembered between runs.
##
## The table below knows physics and nothing else. When a ball is lost it says
## so and stops; whether that means another ball or the end of the run is
## decided here (spec 3.1).

@export var menu_scene: PackedScene
@export var table_scene: PackedScene
@export var hud_scene: PackedScene
@export var pause_scene: PackedScene

@onready var _screen_holder: Node = $ScreenHolder
@onready var _overlay_layer: CanvasLayer = $OverlayLayer
@onready var _audio: PinballAudio = $Audio
@onready var _save: PinballSaveStore = $SaveStore

var _settings: PinballSettings
var _menu: PinballMenu
var _table: PinballTable
var _hud: PinballHud
var _pause: PinballPauseMenu

var _balls_left := 0
var _score := 0
var _over := false


func _ready() -> void:
	_settings = PinballSettings.load_default()
	var font_size := int(_settings.hud.font_size)
	_hud = hud_scene.instantiate()
	_overlay_layer.add_child(_hud)
	_hud.configure(font_size)
	_pause = pause_scene.instantiate()
	_overlay_layer.add_child(_pause)
	_pause.configure(font_size)
	_pause.resume_requested.connect(_resume)
	_pause.restart_requested.connect(_start_run)
	_pause.quit_to_menu_requested.connect(_open_menu)
	_open_menu()


## Esc means whatever is on screen: back to the hub from the menu, out of a
## finished run to the menu, and into the pause menu from a ball in play. While
## the pause menu is up this does not run at all -- the tree is paused and this
## node is not set to keep processing -- so the pause menu answers for itself.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _menu != null:
			GameRouter.back_to_hub()
		elif _over:
			_open_menu()
		else:
			_pause.show_menu()
	elif _over and (event.is_action_pressed("fire") or event.is_action_pressed("ui_accept")):
		_start_run()


func _open_menu() -> void:
	_tear_down()
	_pause.hide_menu()
	_hud.set_run_visible(false)
	# Coming here from a finished run, the card is still up. Left alone it would
	# hang over the menu.
	_hud.hide_result()
	_menu = menu_scene.instantiate()
	_screen_holder.add_child(_menu)
	_menu.configure(int(_settings.hud.font_size))
	_menu.set_best(_save.best_score, _save.loaded)
	_menu.start_requested.connect(_start_run)
	_menu.back_requested.connect(_back_to_hub)


func _start_run() -> void:
	_tear_down()
	_pause.hide_menu()
	_table = table_scene.instantiate()
	_screen_holder.add_child(_table)
	_table.ball_drained.connect(_on_ball_drained)
	_table.scored.connect(_on_scored)
	_table.flipper_clacked.connect(_on_flipper_clacked)
	_table.launched.connect(_on_launched)
	_balls_left = int(_settings.rules.starting_balls)
	_score = 0
	_over = false
	_hud.hide_result()
	_hud.set_run_visible(true)
	_refresh_hud()


## The table has already stopped itself and frozen the ball; this only decides
## what it means.
func _on_ball_drained() -> void:
	if _over:
		return
	_balls_left -= 1
	_refresh_hud()
	_audio.play_drain()
	if _balls_left > 0:
		_table.reset_ball()
	else:
		_over = true
		var beat_it := _save.record(_score)
		if beat_it:
			_audio.play_record()
		_hud.show_result(_score, _save.best_score, beat_it)


func _on_flipper_clacked(raised: bool) -> void:
	_audio.play_flipper(raised)


func _on_launched(charge: float) -> void:
	_audio.play_launch(charge)


func _on_scored(amount: int, tone: float) -> void:
	_score += amount
	_refresh_hud()
	_audio.play_hit(tone)


func _resume() -> void:
	_pause.hide_menu()


func _back_to_hub() -> void:
	GameRouter.back_to_hub()


func _refresh_hud() -> void:
	_hud.set_run_state(_balls_left, _score)


## Screens are replaced whole, and the outgoing one is unhooked from before it
## goes: a queued-free node is still alive for the rest of the frame, and its
## signals would still be wired to handlers that no longer have a run to act on.
func _tear_down() -> void:
	if _table != null and is_instance_valid(_table):
		if _table.ball_drained.is_connected(_on_ball_drained):
			_table.ball_drained.disconnect(_on_ball_drained)
		if _table.scored.is_connected(_on_scored):
			_table.scored.disconnect(_on_scored)
		if _table.flipper_clacked.is_connected(_on_flipper_clacked):
			_table.flipper_clacked.disconnect(_on_flipper_clacked)
		if _table.launched.is_connected(_on_launched):
			_table.launched.disconnect(_on_launched)
	_table = null
	_menu = null
	for child in _screen_holder.get_children():
		_screen_holder.remove_child(child)
		child.queue_free()
