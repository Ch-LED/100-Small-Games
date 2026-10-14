class_name TetrisPlay
extends Node2D

## Drives one game: the piece in flight, gravity, locking, clearing, scoring.
##
## It knows the rules and nothing about pixels -- the field is told what to
## paint, never asked. The audio player is optional on purpose so the rules can
## run with no scene at all; that is what lets the assertion suite reach them.

signal finished(outcome: int, score: int, lines: int, elapsed_ms: int)
## What one lock did, for whoever is watching the run rather than playing it.
## The tutorial decides whether a lesson is passed from these two numbers.
signal locked(lines: int, spin: int)
signal restart_requested
signal menu_requested

const PAUSE_SCENE := preload("res://12-tetris/scenes/pause_menu.tscn")

## Sentinel for an empty hold well. Deliberately not a Tetromino.Kind, so it
## can never be mistaken for one.
const NO_PIECE := -1

## How many pieces the next queue shows. Must match the slot count in play.tscn.
const NEXT_PREVIEW := 5

## SRS searches five kick offsets, and landing on the last one promotes a
## T-spin from mini to full. That promotion is the guideline's, not a shortcut.
const KICK_COUNT := 5

enum Mode { MARATHON, SPRINT, TUTORIAL }
enum Outcome { RUNNING, TOPPED_OUT, SPRINT_DONE }
## What moved the piece last. Only ROTATE matters, for T-spin detection.
enum Action { NONE, MOVE, ROTATE }

@onready var _field: TetrisPlayfield = $Playfield
@onready var _hud: TetrisHud = $Stats
@onready var _debug: TetrisDebug = $Playfield/DebugLayer

var _settings: TetrisSettings
var _board: TetrisBoard
var _bag: PieceBag
var _scoring: TetrisScoring
var _audio: TetrisAudio

var _kind: int = 0
var _rotation: int = 0
var _origin: Vector2i = Vector2i.ZERO
var _fall_accum: float = 0.0
var _lock_timer: float = 0.0
var _lock_resets: int = 0
var _last_action: Action = Action.NONE
var _last_kick: int = 0
var _last_locked_cells: Array[Vector2i] = []

var _hold_kind: int = NO_PIECE
var _hold_spent: bool = false

var _shift_direction: int = 0
var _shift_latest: int = 0
var _das_timer: float = 0.0
var _arr_timer: float = 0.0
var _soft_drop_held: bool = false

var _over: bool = false
var _outcome: Outcome = Outcome.RUNNING
var _mode: Mode = Mode.MARATHON
var _elapsed: float = 0.0
## Two independent toggles, with different defaults on purpose. The landing
## preview starts ON -- it is what most players expect a falling piece to show,
## and hiding it by default made the game harder than the standard it follows.
## The debug overlay starts OFF, because it is a readout rather than a game aid.
var _ghost_on: bool = true
var _debug_on: bool = false
var _slow: bool = false
var _zero_gravity: bool = false
var _started: bool = false
## What the last lock did, in words, for the HUD. Kept here rather than pushed
## straight at the HUD so the rules never depend on the display.
var _last_event: String = ""


## Everything a run needs arrives here rather than in _ready: the scene is
## instantiated by the root, which owns the settings, the mode and the audio.
##
## `lesson` is empty for an ordinary game. A lesson hands over a starting
## position, a fixed deal order and sometimes a piece already in the hold --
## the rules are otherwise untouched, so anything learned in a lesson works in
## a real game.
func begin(
	settings: TetrisSettings,
	mode: int,
	audio: TetrisAudio,
	lesson: Dictionary = {}
) -> void:
	_audio = audio
	prepare(settings, mode, lesson)
	_field.setup(settings)
	_field.set_ghost_visible(_ghost_on)
	_debug.setup(settings)
	_debug.set_shown(_debug_on)
	_hud.build(settings)
	_hud.set_sprint(mode == Mode.SPRINT)


## The rules half of starting a run, with no scene involved. Split out so a run
## can be built and driven with nothing but the script -- which is how the
## assertion suite reaches the lessons.
func prepare(settings: TetrisSettings, mode: int, lesson: Dictionary = {}) -> void:
	_settings = settings
	_mode = mode
	_board = TetrisBoard.new()
	_bag = PieceBag.new()
	_scoring = TetrisScoring.new(settings.level_cap)
	if not lesson.is_empty():
		_board.load_rows(lesson.get("rows", []))
		_bag.set_sequence(lesson.get("pieces", []))
		if lesson.has("hold"):
			_hold_kind = int(lesson["hold"])
	_spawn_from_bag()
	_started = true


func _physics_process(delta: float) -> void:
	if not _started or _over:
		return
	_elapsed += delta
	_read_input(delta)
	_advance(delta)
	_refresh()
	_check_sprint_done()


func _unhandled_input(event: InputEvent) -> void:
	if not _started or _over:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_open_pause()


func _read_input(delta: float) -> void:
	_read_shift(delta)
	if Input.is_action_just_pressed(TetrisInput.ROTATE_CW):
		_try_rotate(true)
	if Input.is_action_just_pressed(TetrisInput.ROTATE_CCW):
		_try_rotate(false)
	if Input.is_action_just_pressed(TetrisInput.HARD_DROP):
		_hard_drop()
	if Input.is_action_just_pressed(TetrisInput.HOLD):
		_try_hold()
	if Input.is_action_just_pressed(TetrisInput.TOGGLE_GHOST):
		_ghost_on = not _ghost_on
		_field.set_ghost_visible(_ghost_on)
	if Input.is_action_just_pressed("debug_toggle"):
		_debug_on = not _debug_on
		_debug.set_shown(_debug_on)
	if Input.is_action_just_pressed("cheat_toggle"):
		_slow = not _slow
	if Input.is_action_just_pressed("super_cheat_toggle"):
		_zero_gravity = not _zero_gravity
		# The accumulator stops moving while gravity is off, so whatever it was
		# holding would otherwise be spent in one go on the way back.
		_fall_accum = 0.0


## One cell on press, then repeats after DAS at the ARR rate.
##
## Both keys held means the most recent press wins. Taking neither instead
## would make the two cancel out, and a piece that ignores a held key reads as
## a dropped input rather than as a design decision.
func _read_shift(delta: float) -> void:
	if Input.is_action_just_pressed(TetrisInput.MOVE_LEFT):
		_shift_latest = -1
	elif Input.is_action_just_pressed(TetrisInput.MOVE_RIGHT):
		_shift_latest = 1

	var held_left := Input.is_action_pressed(TetrisInput.MOVE_LEFT)
	var held_right := Input.is_action_pressed(TetrisInput.MOVE_RIGHT)
	var direction := 0
	if held_left and held_right:
		direction = _shift_latest
	elif held_left:
		direction = -1
	elif held_right:
		direction = 1

	if direction != _shift_direction:
		_shift_direction = direction
		_das_timer = 0.0
		_arr_timer = 0.0
		if direction != 0:
			_try_move(Vector2i(direction, 0))
		return

	if direction == 0:
		return

	_das_timer += delta
	if _das_timer < _settings.das:
		return
	if _settings.arr <= 0.0:
		# An ARR of zero means the piece slides all the way in one frame.
		while _try_move(Vector2i(direction, 0)):
			pass
		return
	_arr_timer += delta
	while _arr_timer >= _settings.arr:
		_arr_timer -= _settings.arr
		if not _try_move(Vector2i(direction, 0)):
			break


func _advance(delta: float) -> void:
	var soft := Input.is_action_pressed(TetrisInput.SOFT_DROP)
	var switched := soft != _soft_drop_held
	_soft_drop_held = soft
	if switched:
		# The accumulator means different things at the two rates: under
		# gravity it is allowed to build up a whole second, while soft drop
		# only ever holds 0.05 s of it. Carrying the value across the switch
		# pays off the difference all at once -- 0.9 s of gravity meeting a
		# 0.05 s interval lands the piece eighteen rows in a single frame.
		_fall_accum = 0.0

	if _is_grounded():
		_lock_timer += delta
		if _lock_timer >= _lock_delay():
			_lock_piece()
		return
	_lock_timer = 0.0

	if _zero_gravity and not soft:
		# Nothing pulls the piece down; it waits exactly where it was left.
		# Soft drop still works, because that is the player pushing, not time.
		return

	if switched and soft and _try_move(Vector2i(0, 1)):
		# Landing the first row on the press matches the horizontal shift,
		# which also moves on the press rather than after a delay.
		_scoring.add_soft_drop(1)

	var interval := _settings.soft_drop_interval if soft else _gravity_interval()
	_fall_accum += delta
	while _fall_accum >= interval:
		_fall_accum -= interval
		if not _try_move(Vector2i(0, 1)):
			break
		if soft:
			_scoring.add_soft_drop(1)


func _gravity_interval() -> float:
	var interval := TetrisScoring.gravity_interval(_scoring.level, _settings.level_cap)
	interval = maxf(interval, _min_fall_interval())
	return interval * (_settings.time_scale if _slow else 1.0)


func _lock_delay() -> float:
	return _settings.lock_delay * (_settings.time_scale if _slow else 1.0)


## The guideline tops out at 20G, which the curve overshoots by the capped
## level anyway. The floor is not there to slow anything down -- it is there
## because the curve is a power, and past the cap it undershoots toward zero,
## where the accumulator would loop without ever subtracting anything.
func _min_fall_interval() -> float:
	return 1.0 / float(Engine.physics_ticks_per_second) / _settings.min_fall_per_grid


func _try_move(offset: Vector2i) -> bool:
	var candidate := _origin + offset
	if not _board.is_free(Tetromino.cells(_kind, _rotation), candidate):
		return false
	_origin = candidate
	_last_action = Action.MOVE
	_note_ground_action()
	if offset.x != 0:
		_play(TetrisAudio.MOVE)
	return true


## Tries each SRS kick in order and takes the first that fits. If none do, the
## rotation simply does not happen -- a tetromino cannot be wedged into a space
## it does not fit, however much a player leans on the key.
func _try_rotate(clockwise: bool) -> void:
	var from := _rotation
	var to := Tetromino.rotation_step(from, clockwise)
	var rotated := Tetromino.cells(_kind, to)
	var kicks := Tetromino.kick_offsets(_kind, from, to)
	for index in kicks.size():
		if _board.is_free(rotated, _origin + kicks[index]):
			_rotation = to
			_origin += kicks[index]
			_last_action = Action.ROTATE
			_last_kick = index
			_note_ground_action()
			_play(TetrisAudio.ROTATE)
			return


## A successful move or rotation while the piece is already resting buys it a
## little more time -- but only so many times. Without the cap a player could
## spin a resting piece forever and it would never lock, which is the "infinity"
## hole the guideline closes at 15 resets.
func _note_ground_action() -> void:
	if not _is_grounded():
		return
	if _lock_resets >= _settings.lock_reset_cap:
		return
	_lock_resets += 1
	_lock_timer = 0.0


func _hard_drop() -> void:
	# A hard drop is not a rotation, so it closes any T-spin window -- even a
	# drop of zero rows, where nothing else would touch _last_action.
	_last_action = Action.MOVE
	var dropped := 0
	while _try_move(Vector2i(0, 1)):
		dropped += 1
	_scoring.add_hard_drop(dropped)
	_lock_piece()


## Once per piece: the held kind and the active kind change places, and an
## empty well means the piece comes out of the bag instead.
func _try_hold() -> void:
	if _hold_spent:
		return
	_hold_spent = true
	var swapped := _hold_kind
	_hold_kind = _kind
	if swapped == NO_PIECE:
		_spawn_from_bag()
	else:
		_spawn_kind(swapped)


func _lock_piece() -> void:
	var spin := _detect_spin()
	var level_before := _scoring.level
	_last_locked_cells = _active_cells()
	_board.lock(Tetromino.cells(_kind, _rotation), _origin, _kind)
	var lines := _board.clear_lines()
	_scoring.register(lines, spin)
	_last_event = TetrisScoring.describe(lines, spin)
	_hold_spent = false
	_play(TetrisAudio.LOCK)
	if spin != TetrisScoring.Spin.NONE:
		_play(TetrisAudio.TSPIN)
	if lines > 0:
		_play_clear(lines)
	if _scoring.level > level_before:
		_play(TetrisAudio.LEVEL)
	locked.emit(lines, spin)
	_spawn_from_bag()


## Stops the run where it is. The tutorial ends a lesson when its goal is met,
## which has nothing to do with the well filling up.
func stop() -> void:
	_over = true


## The guideline's test, all three parts of it. Leaving out "the last action
## was a rotation" is the classic mistake: ordinary rotations would then pay
## like T-spins, and the symptom is a score that climbs too fast rather than
## anything visibly broken.
func _detect_spin() -> TetrisScoring.Spin:
	if _kind != Tetromino.Kind.T or _last_action != Action.ROTATE:
		return TetrisScoring.Spin.NONE
	var counts := _board.t_corner_counts(_origin, _rotation)
	if counts.x < 3:
		return TetrisScoring.Spin.NONE
	if _last_kick == KICK_COUNT - 1:
		return TetrisScoring.Spin.FULL
	if counts.y == 2:
		return TetrisScoring.Spin.FULL
	return TetrisScoring.Spin.MINI


func _spawn_from_bag() -> void:
	_spawn_kind(_bag.next())


func _spawn_kind(kind: int) -> void:
	_kind = kind
	_rotation = 0
	_origin = Tetromino.spawn_offset(_kind) + Vector2i(0, TetrisBoard.SPAWN_ROWS)
	_fall_accum = 0.0
	_lock_timer = 0.0
	_lock_resets = 0
	_last_action = Action.NONE
	_last_kick = 0
	# Top out: the new piece does not fit where it was dealt.
	if not _board.is_free(Tetromino.cells(_kind, _rotation), _origin):
		_finish(Outcome.TOPPED_OUT)


func _check_sprint_done() -> void:
	if _mode == Mode.SPRINT and _scoring.lines_total >= _settings.sprint_lines:
		_finish(Outcome.SPRINT_DONE)


func _finish(outcome: Outcome) -> void:
	if _over:
		return
	_over = true
	_outcome = outcome
	finished.emit(outcome, _scoring.score, _scoring.lines_total, int(_elapsed * 1000.0))


func _open_pause() -> void:
	var menu: TetrisPauseMenu = PAUSE_SCENE.instantiate()
	add_child(menu)
	menu.configure(_settings)
	menu.resume_requested.connect(_close_pause)
	menu.restart_requested.connect(_on_restart)
	menu.menu_requested.connect(_on_menu)
	get_tree().paused = true


func _close_pause() -> void:
	get_tree().paused = false
	for child in get_children():
		if child is TetrisPauseMenu:
			child.queue_free()


func _on_restart() -> void:
	_close_pause()
	restart_requested.emit()


func _on_menu() -> void:
	_close_pause()
	menu_requested.emit()


func _play(sound: String) -> void:
	if _audio != null:
		_audio.play(sound)


func _play_clear(lines: int) -> void:
	if _audio != null:
		_audio.play_clear(lines)


func _is_grounded() -> bool:
	return not _board.is_free(Tetromino.cells(_kind, _rotation), _origin + Vector2i(0, 1))


func _refresh() -> void:
	var ghost: Array[Vector2i] = []
	if _ghost_on:
		ghost = _ghost_cells()
	_field.render_pile(_board, _active_cells(), _kind, ghost, _zero_gravity)
	_field.render_hold(_hold_kind)
	_field.render_next(_next_preview())
	_hud.update_stats(_scoring.score, _scoring.level, _scoring.lines_total)
	_hud.update_clock(int(_elapsed * 1000.0))
	_hud.show_event(_last_event)
	_debug.update_from(self)


# Read-only accessors for the debug overlay. Nothing in the rules reads them
# back, so they cannot become a second source of truth.
func piece_kind() -> int:
	return _kind


func piece_rotation() -> int:
	return _rotation


func piece_origin() -> Vector2i:
	return _origin


func active_cells() -> Array[Vector2i]:
	return _active_cells()


func gravity_interval() -> float:
	return _gravity_interval()


func lock_timer() -> float:
	return _lock_timer


func lock_resets() -> int:
	return _lock_resets


func bag_remaining() -> Array[int]:
	return _bag.remaining()


func last_locked_cells() -> Array[Vector2i]:
	return _last_locked_cells


func field() -> TetrisPlayfield:
	return _field


## Freezes the run without ending it. The tutorial holds a lesson here while
## its demonstration plays, and lets go when the player takes over.
##
## Paints once on the way in: the position has just been built and nothing has
## drawn it yet, so freezing first would leave the lesson sitting on a blank
## well with only the demonstration's ghost floating over it.
func set_frozen(frozen: bool) -> void:
	_started = not frozen
	if _board != null:
		_refresh()


func _active_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in Tetromino.cells(_kind, _rotation):
		result.append(_origin + cell)
	return result


## Where the piece would come to rest if it fell straight down.
func _ghost_cells() -> Array[Vector2i]:
	var cells := Tetromino.cells(_kind, _rotation)
	var landing := _origin
	while _board.is_free(cells, landing + Vector2i(0, 1)):
		landing += Vector2i(0, 1)
	var result: Array[Vector2i] = []
	for cell in cells:
		result.append(landing + cell)
	return result


func _next_preview() -> Array[int]:
	var result: Array[int] = []
	for index in NEXT_PREVIEW:
		result.append(_bag.peek(index))
	return result
