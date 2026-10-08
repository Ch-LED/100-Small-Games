class_name BreakoutGame
extends Control
## Breakout controller: the brick board, the ball/level loop, paddle input, and
## the two overlay keys.

enum State { TITLE, READY, PLAYING, DYING, LEVEL_CLEAR, OVER }

const BRICK_SCENE := preload("res://07-breakout/scenes/brick.tscn")
const MESSAGE_FONT_SIZE := 24

@onready var _background: ColorRect = $Background
@onready var _frame: Node2D = $Board/Frame
@onready var _bricks: Node2D = $Board/Bricks
@onready var _paddle: BreakoutPaddle = $Board/Paddle
@onready var _ball: BreakoutBall = $Board/Ball
@onready var _debug: BreakoutDebug = $DebugDraw
@onready var _hud: BreakoutHud = $Hud
@onready var _message: Label = $Overlay/Message
@onready var _audio: BreakoutAudio = $Audio

var _cfg := {}

var _state: int = State.TITLE
var _score := 0
var _high := 0
var _lives := 3
var _level := 1
var _state_timer := 0.0
## Bricks still standing in the current board.
var _remaining := 0

var _cheat := false
var _debug_on := false
## Once the pointer has moved it drives the paddle until a key takes over.
var _pointer_mode := false


func _ready() -> void:
	_cfg = BreakoutSettings.load_all()
	if not _validate_rows():
		return
	BreakoutField.configure(_cfg.field, (_cfg.field.brick_scores as Array).size())

	_background.color = _cfg.field.bg_color
	_build_frame()

	_paddle.setup(_cfg.paddle, _cfg.field.paddle_color)
	_ball.setup(_cfg.ball, _paddle, _bricks, _cfg.field.ball_color)
	_ball.brick_hit.connect(_on_brick_hit)
	_ball.paddle_hit.connect(_on_paddle_hit)
	_ball.wall_hit.connect(_on_wall_hit)
	_ball.lost.connect(_on_ball_lost)

	_hud.build(_cfg)
	PixelFont.apply(_message, MESSAGE_FONT_SIZE)
	_message.add_theme_color_override("font_color", _cfg.field.ball_color)
	_enter_title()


## The three brick tables are indexed by row, so a mismatch would silently draw
## the wrong colours or crash on the tone lookup.
func _validate_rows() -> bool:
	var rows: int = (_cfg.field.brick_scores as Array).size()
	var ok: bool = (_cfg.field.brick_colors as Array).size() == rows \
			and (_cfg.field.row_tones as Array).size() == rows
	if not ok:
		push_error("BreakoutGame: brick_colors, brick_scores and row_tones must be the same length")
	return ok


# --- build ------------------------------------------------------------------

## The walls are three rects; their visible band is drawn from the same rects the
## ball bounces off, so what you see is exactly what stops it.
func _build_frame() -> void:
	for rect in BreakoutField.wall_rects():
		var band := ColorRect.new()
		band.color = _cfg.field.wall_color
		band.position = rect.position
		band.size = rect.size
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_frame.add_child(band)


func _build_bricks() -> void:
	# retire() rather than queue_free(): the outgoing bricks have to leave the
	# ball's collision set now, not when their frees land at the end of the frame.
	for child in _bricks.get_children():
		var old := child as BreakoutBrick
		if old != null:
			old.retire()

	_remaining = 0
	for row in BreakoutField.ROWS:
		for col in BreakoutField.COLS:
			var brick: BreakoutBrick = BRICK_SCENE.instantiate()
			# Add before setup: setup() drives @onready children, which only
			# resolve for a node already in the tree.
			_bricks.add_child(brick)
			brick.setup(BreakoutField.brick_rect(row, col),
					_cfg.field.brick_colors[row], row, _cfg.field.brick_scores[row])
			_remaining += 1


# --- states -----------------------------------------------------------------

func _enter_title() -> void:
	_state = State.TITLE
	_score = 0
	_level = 1
	_lives = int(_cfg.play.lives)
	_cheat = false
	_paddle.set_width_scale(1.0)
	_build_bricks()
	_apply_level_speed()
	_ball.set_frozen(false)
	_ball.attach_to_paddle()
	_hud.set_score(_score, _high)
	_hud.set_level(_level)
	_hud.set_lives(_lives)
	_message.text = "BREAKOUT\n\nPRESS SPACE TO START"


func _start_run() -> void:
	_score = 0
	_level = 1
	_lives = int(_cfg.play.lives)
	_cheat = false
	_paddle.set_width_scale(1.0)
	_build_bricks()
	_apply_level_speed()
	_hud.set_score(_score, _high)
	_hud.set_level(_level)
	_hud.set_lives(_lives)
	_enter_ready()


## The ball sits on the paddle so the player can line the shot up first.
func _enter_ready() -> void:
	_state = State.READY
	_ball.set_frozen(false)
	_ball.attach_to_paddle()
	_message.text = "PRESS SPACE TO LAUNCH"


func _launch() -> void:
	_state = State.PLAYING
	_ball.launch()
	_audio.play_launch()
	_message.text = ""


func _begin_level_clear() -> void:
	_state = State.LEVEL_CLEAR
	_state_timer = float(_cfg.play.level_pause)
	_ball.set_frozen(true)
	_audio.play_cleared()
	_message.text = "LEVEL %d CLEARED" % _level


func _after_level_clear() -> void:
	_level += 1
	_hud.set_level(_level)
	_build_bricks()
	_apply_level_speed()
	_message.text = ""
	_enter_ready()


func _after_life_lost() -> void:
	_lives -= 1
	_hud.set_lives(_lives)
	if _lives <= 0:
		_finish()
		return
	_enter_ready()


func _finish() -> void:
	_state = State.OVER
	_ball.set_frozen(true)
	if _score > _high:
		_high = _score
		_hud.set_score(_score, _high)
	_message.text = "GAME OVER\n\nSCORE %d\n\nPRESS SPACE" % _score


func _apply_level_speed() -> void:
	var effective: int = maxi(0, mini(_level, int(_cfg.play.level_speedup_cap)) - 1)
	_ball.set_level_multiplier(pow(float(_cfg.play.speed_step), float(effective)))


# --- per-frame --------------------------------------------------------------

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		GameRouter.back_to_hub()
		return
	if Input.is_action_just_pressed("debug_toggle"):
		_debug_on = not _debug_on
		_debug.enabled = _debug_on
	if Input.is_action_just_pressed("cheat_toggle"):
		_toggle_cheat()

	_read_paddle_input()

	match _state:
		State.TITLE, State.OVER:
			if Input.is_action_just_pressed("fire"):
				_start_run()
		State.READY:
			if Input.is_action_just_pressed("fire"):
				_launch()
		State.PLAYING:
			pass
		State.DYING:
			_state_timer -= delta
			if _state_timer <= 0.0:
				_after_life_lost()
		State.LEVEL_CLEAR:
			_state_timer -= delta
			if _state_timer <= 0.0:
				_after_level_clear()

	_refresh_debug()


## Pointer or keys, whichever moved last.
func _read_paddle_input() -> void:
	var direction := 0.0
	if Input.is_action_pressed("wasd_left") or Input.is_action_pressed("arrow_left"):
		direction -= 1.0
	if Input.is_action_pressed("wasd_right") or Input.is_action_pressed("arrow_right"):
		direction += 1.0

	if direction != 0.0:
		_pointer_mode = false
	if _pointer_mode:
		# get_GLOBAL_mouse_position(), not the local one: local is measured from
		# the paddle itself, so feeding that back as an absolute target makes the
		# paddle chase the pointer's offset from the paddle — it settles at half
		# the pointer's x and never reaches the right half.
		_paddle.follow_pointer(_paddle.get_global_mouse_position().x)
	else:
		_paddle.set_direction(direction)


func _unhandled_input(event: InputEvent) -> void:
	# Only used to hand control to the pointer; the position is polled.
	if event is InputEventMouseMotion:
		_pointer_mode = true


func _toggle_cheat() -> void:
	_cheat = not _cheat
	_paddle.set_width_scale(float(_cfg.paddle.cheat_width_scale) if _cheat else 1.0)


# --- ball callbacks ---------------------------------------------------------

func _on_brick_hit(brick: BreakoutBrick) -> void:
	# Reached from the ball's physics step: only flags, score and a sound here.
	# Rebuilding anything waits for _process.
	if not brick.break_brick():
		return
	_remaining -= 1
	_add_score(brick.score)
	_audio.play_brick(brick.row)
	if _remaining <= 0:
		_begin_level_clear()


func _on_paddle_hit() -> void:
	_audio.play_paddle()


func _on_wall_hit() -> void:
	_audio.play_wall()


func _on_ball_lost() -> void:
	if _state != State.PLAYING:
		return
	_state = State.DYING
	_state_timer = float(_cfg.play.life_pause)
	_message.text = ""
	_audio.play_lost()


func _add_score(value: int) -> void:
	_score += value
	if _score > _high:
		_high = _score
	_hud.set_score(_score, _high)


# --- debug overlay ----------------------------------------------------------

func _refresh_debug() -> void:
	if not _debug_on:
		return
	_debug.ball_position = _ball.position
	_debug.ball_radius = _ball.radius
	_debug.ball_velocity = _ball.velocity
	_debug.ball_speed = _ball.speed()
	_debug.paddle_rect = _paddle.global_rect()
	_debug.play_rect = BreakoutField.play_rect()
