class_name SimonGame
extends Control
## Simon controller: the play-the-sequence / repeat-it loop, the round and speed
## curve, and the two read-only overlays.

enum State { TITLE, PLAYBACK, INPUT, ROUND_CLEAR, FAILED, OVER }

const MESSAGE_FONT_SIZE := 24
const NOTICE_TIME := 1.0
## Pad i answers to both of these actions. Order is PAD_UP / RIGHT / DOWN / LEFT.
const PAD_ACTIONS: Array = [
	["wasd_up", "arrow_up"],
	["wasd_right", "arrow_right"],
	["wasd_down", "arrow_down"],
	["wasd_left", "arrow_left"],
]

@onready var _background: ColorRect = $Background
@onready var _hub: Polygon2D = $Board/Hub
@onready var _pads: Array[SimonPad] = [
	$Board/PadUp, $Board/PadRight, $Board/PadDown, $Board/PadLeft,
]
@onready var _readout: SimonOverlay = $Readout
@onready var _hud: SimonHud = $Hud
@onready var _message: Label = $Overlay/Message
@onready var _audio: SimonAudio = $Audio

var _cfg := {}
var _rng := RandomNumberGenerator.new()

var _state: int = State.TITLE
var _sequence: Array[int] = []
## 1-based: the sequence you are currently being asked for is this long.
var _round := 1
var _best := 0

var _playback_index := 0
var _input_index := 0
var _play_timer := 0.0
var _state_timer := 0.0
var _notice_timer := 0.0
var _lit_timers: Array[float] = [0.0, 0.0, 0.0, 0.0]


func _ready() -> void:
	_cfg = SimonSettings.load_all()
	SimonBoard.configure(float(_cfg.field.outer_radius), float(_cfg.field.inner_radius),
			float(_cfg.field.gap_deg))
	_rng.randomize()

	_background.color = _cfg.field.bg_color
	_hub.position = SimonBoard.CENTER
	_hub.color = _cfg.field.hub_color
	_hub.polygon = SimonBoard.circle_polygon(SimonBoard.INNER, int(_cfg.field.segments))

	for i in _pads.size():
		_pads[i].setup(i, _cfg.field.pad_colors[i], float(_cfg.field.dim_amount),
				int(_cfg.field.segments))

	_readout.configure(_cfg)
	_readout.pad_colors = _cfg.field.pad_colors
	_hud.build(_cfg)
	PixelFont.apply(_message, MESSAGE_FONT_SIZE)
	_message.add_theme_color_override("font_color", Color("E8F1FF"))
	_enter_title()


# --- states -----------------------------------------------------------------

func _enter_title() -> void:
	_state = State.TITLE
	_sequence.clear()
	_round = 1
	_playback_index = 0
	_input_index = 0
	_darken_pads()
	_hud.set_round(_round)
	_hud.set_best(_best)
	_message.text = "SIMON\n\nPRESS SPACE TO START\n\nREPEAT THE SEQUENCE"


func _start_run() -> void:
	_sequence.clear()
	for i in int(_cfg.play.start_length):
		_sequence.append(_roll_step())
	_round = 1
	_input_index = 0
	_notice_timer = 0.0
	_message.text = ""
	_hud.set_round(_round)
	_audio.play_start()
	_begin_playback()


func _begin_playback() -> void:
	_state = State.PLAYBACK
	_playback_index = 0
	# A beat of anticipation before the first pad lights.
	_play_timer = _step_seconds()
	_input_index = 0
	_darken_pads()


func _begin_input() -> void:
	_state = State.INPUT
	_input_index = 0


func _complete_round() -> void:
	var cleared := _round
	_round += 1
	if cleared > _best:
		_best = cleared
		_hud.set_best(_best)

	# The new step joins before playback, so the next thing shown is the
	# sequence the player has to give back.
	_sequence.append(_roll_step())
	_hud.set_round(_round)

	# Hold before replaying. Starting the next sequence the instant the last key
	# lands cuts off that key's flash and makes the new round feel like it
	# ambushed the player; the pads are deliberately left alone here so the flash
	# finishes on its own.
	_state = State.ROUND_CLEAR
	_state_timer = float(_cfg.play.round_pause)
	_show_notice("ROUND %d" % _round)


func _begin_failure() -> void:
	_state = State.FAILED
	_state_timer = float(_cfg.play.fail_pause)
	_notice_timer = 0.0
	_message.text = ""
	_audio.play_error()
	_darken_pads()


func _finish() -> void:
	_state = State.OVER
	_notice_timer = 0.0
	var cleared := maxi(0, _round - 1)
	if cleared > _best:
		_best = cleared
	_hud.set_best(_best)
	_message.text = "GAME OVER\n\nSEQUENCES CLEARED %d\n\nPRESS SPACE" % cleared


## The banner is used by the between-rounds beat. It shows in any state except
## the title screen, which owns the label itself.
func _show_notice(text: String) -> void:
	if _state == State.TITLE:
		return
	_message.text = text
	_notice_timer = NOTICE_TIME


func _tick_notice(delta: float) -> void:
	if _notice_timer <= 0.0:
		return
	_notice_timer -= delta
	if _notice_timer <= 0.0:
		_message.text = ""


# --- per-frame --------------------------------------------------------------

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		GameRouter.back_to_hub()
		return
	if Input.is_action_just_pressed("debug_toggle"):
		_readout.show_state = not _readout.show_state
	if Input.is_action_just_pressed("cheat_toggle"):
		_readout.show_peek = not _readout.show_peek

	_tick_notice(delta)

	match _state:
		State.TITLE, State.OVER:
			if Input.is_action_just_pressed("fire"):
				_start_run()
		State.PLAYBACK:
			_tick_playback(delta)
		State.INPUT:
			pass
		State.ROUND_CLEAR:
			_state_timer -= delta
			if _state_timer <= 0.0:
				_begin_playback()
		State.FAILED:
			_state_timer -= delta
			if _state_timer <= 0.0:
				_finish()

	_tick_pads(delta)
	_push_overlay()


func _tick_playback(delta: float) -> void:
	_play_timer -= delta
	if _play_timer > 0.0:
		return
	if _playback_index >= _sequence.size():
		_begin_input()
		return
	var pad := _sequence[_playback_index]
	_light(pad, _step_seconds() * float(_cfg.play.flash_ratio))
	_audio.play_tone(pad)
	_playback_index += 1
	_play_timer = _step_seconds()


## Seconds per step: one step shorter every round, down to a floor.
func _step_seconds() -> float:
	var decayed: float = float(_cfg.play.base_step) \
			- float(maxi(0, _round - 1)) * float(_cfg.play.step_decay)
	return maxf(float(_cfg.play.min_step), decayed)


# --- input ------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if _state != State.INPUT:
		return
	# Key events rather than polling, so two pads pressed in one frame keep their
	# order (same reasoning as 04-snake).
	for pad in PAD_ACTIONS.size():
		for action in PAD_ACTIONS[pad]:
			if event.is_action_pressed(str(action)):
				_press_pad(pad)
				return


## Mouse goes through gui_input, whose positions are already in this Control's
## own coordinates — no need to reason about the stretch transform.
func _gui_input(event: InputEvent) -> void:
	if _state != State.INPUT:
		return
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	_press_pad(SimonBoard.pad_at(click.position))


func _press_pad(pad: int) -> void:
	if _state != State.INPUT or pad < 0 or pad >= _pads.size():
		return
	_light(pad, float(_cfg.play.input_flash))
	_audio.play_tone(pad)

	if pad != _sequence[_input_index]:
		_begin_failure()
		return
	_input_index += 1
	if _input_index >= _sequence.size():
		_complete_round()


# --- pads -------------------------------------------------------------------

func _light(pad: int, seconds: float) -> void:
	_lit_timers[pad] = maxf(0.05, seconds)
	_pads[pad].set_lit(true)


func _tick_pads(delta: float) -> void:
	for i in _pads.size():
		if _lit_timers[i] <= 0.0:
			continue
		_lit_timers[i] -= delta
		if _lit_timers[i] <= 0.0:
			_pads[i].set_lit(false)


func _darken_pads() -> void:
	for i in _pads.size():
		_lit_timers[i] = 0.0
		_pads[i].set_lit(false)


func _roll_step() -> int:
	var pad := _rng.randi_range(0, SimonBoard.PAD_COUNT - 1)
	# Never three of the same in a row: it reads as a freeze rather than a beat.
	var last := _sequence.size()
	if last >= 2 and _sequence[last - 1] == pad and _sequence[last - 2] == pad:
		pad = (pad + 1 + _rng.randi_range(0, SimonBoard.PAD_COUNT - 2)) % SimonBoard.PAD_COUNT
	return pad


# --- read-only overlay ------------------------------------------------------

func _push_overlay() -> void:
	if not (_readout.show_state or _readout.show_peek):
		return
	_readout.sequence = _sequence
	_readout.peek_progress = _input_index if _state == State.INPUT else _sequence.size()
	_readout.state_text = "PHASE %s   STEP %d/%d   ROUND %d   STEP %.0fMS" % [
		_phase_name(), _step_position(), _sequence.size(), _round, _step_seconds() * 1000.0,
	]


func _step_position() -> int:
	match _state:
		State.PLAYBACK:
			return mini(_playback_index, _sequence.size())
		State.INPUT:
			return _input_index
		State.ROUND_CLEAR:
			return _sequence.size()
	return 0


func _phase_name() -> String:
	match _state:
		State.TITLE:
			return "TITLE"
		State.PLAYBACK:
			return "PLAYBACK"
		State.INPUT:
			return "INPUT"
		State.ROUND_CLEAR:
			return "CLEARED"
		State.FAILED:
			return "FAILED"
	return "OVER"
