class_name BreakoutGame
extends Control
## Breakout controller: the brick board, the ball/level loop, paddle input, and
## the two overlay keys.

enum State { TITLE, READY, PLAYING, DYING, LEVEL_CLEAR, OVER }

const BRICK_SCENE := preload("res://07-breakout/scenes/brick.tscn")
const SHARD_SCENE := preload("res://07-breakout/scenes/shard_burst.tscn")
const MESSAGE_FONT_SIZE := 24

@onready var _background: ColorRect = $Background
@onready var _frame: Node2D = $Board/Frame
@onready var _bricks: Node2D = $Board/Bricks
@onready var _trail: Line2D = $Board/Trail
@onready var _shards: Node2D = $Board/Shards
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
## Bricks broken since the ball last touched the paddle. The slot behind the
## brick layer rattles the ball back and forth, and this is what makes that run
## pay instead of merely stalling.
var _combo := 0

var _cheat := false
var _debug_on := false
## Once the pointer has moved it drives the paddle until a key takes over.
var _pointer_mode := false

var _trail_cold: Gradient = null
var _trail_hot: Gradient = null
var _trail_is_hot := false

## Every level file on disk, in name order, read once at startup.
var _level_paths := PackedStringArray()
## The level being played. Its grid, not cfg, decides the board's shape.
var _level_data: BreakoutLevel = null


func _ready() -> void:
	_cfg = BreakoutSettings.load_all()
	if not _validate_tables():
		return

	_background.color = _cfg.field.bg_color
	_build_frame()
	_build_trail()

	_paddle.setup(_cfg.paddle, _cfg.field.paddle_color)
	_ball.setup(_cfg.ball, _paddle, _bricks, _cfg.field.ball_color)
	_ball.brick_hit.connect(_on_brick_hit)
	_ball.paddle_hit.connect(_on_paddle_hit)
	_ball.wall_hit.connect(_on_wall_hit)
	_ball.lost.connect(_on_ball_lost)
	_ball.caught.connect(_on_ball_caught)

	_level_paths = BreakoutLevel.available()
	if _level_paths.is_empty():
		# .txt files do not ship in an exported build unless the preset says so,
		# so a build that lost them must still be playable (DECISION_LOG 049).
		push_error("BreakoutGame: no level files under %s" % BreakoutLevel.DIR)

	_hud.build(_cfg)
	PixelFont.apply(_message, MESSAGE_FONT_SIZE)
	_message.add_theme_color_override("font_color", _cfg.field.ball_color)
	_enter_title()


## The three layer tables are indexed by the same number — how many hits — so a
## mismatch would silently draw the wrong colour or read a tone that is not there.
func _validate_tables() -> bool:
	var layers: int = (_cfg.field.layer_scores as Array).size()
	var ok: bool = (_cfg.field.layer_colors as Array).size() == layers \
			and (_cfg.field.layer_tones as Array).size() == layers
	if not ok:
		push_error("BreakoutGame: layer_colors, layer_scores and layer_tones must be the same length")
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


## The trail hangs off Board, not off the ball: Line2D points are in their own
## node's space, so a trail parented to the ball would carry its whole history
## along with it and never show a wake. Board has no transform, so absolute
## positions can be pushed into it directly.
func _build_trail() -> void:
	var alpha := float(_cfg.ball.trail_alpha)
	_trail.clear_points()
	_trail.width = float(_cfg.ball.trail_width)
	# Two gradients, built once and swapped: a hot ball's trail says the combo is
	# still riding on it, and swapping the resource is what forces the redraw.
	_trail_cold = _fade_gradient(_cfg.field.ball_color, alpha)
	_trail_hot = _fade_gradient(_cfg.ball.hot_color, alpha)
	_apply_trail_color(false)


func _fade_gradient(tint: Color, alpha: float) -> Gradient:
	var fade := Gradient.new()
	fade.set_color(0, Color(tint.r, tint.g, tint.b, 0.0))
	fade.set_color(1, Color(tint.r, tint.g, tint.b, alpha))
	return fade


func _apply_trail_color(hot: bool) -> void:
	_trail_is_hot = hot
	_trail.gradient = _trail_hot if hot else _trail_cold
	_trail.default_color = _cfg.ball.hot_color if hot else _cfg.field.ball_color


## Dashed away whenever the ball is not in play, so a launch never draws a line
## across the board from wherever the last ball died.
func _refresh_trail() -> void:
	if _ball.is_hot() != _trail_is_hot:
		_apply_trail_color(_ball.is_hot())
	if _state != State.PLAYING or not _ball.is_in_play():
		if _trail.get_point_count() > 0:
			_trail.clear_points()
		return

	var points := _trail.points
	points.append(_ball.position)
	while points.size() > maxi(2, int(_cfg.ball.trail_points)):
		points.remove_at(0)
	_trail.points = points


## Shards in the colour of the layer that just came off, fanned along the ball's
## travel.
func _spawn_shards(brick: BreakoutBrick, at_color: Color) -> void:
	if int(_cfg.shards.count) <= 0:
		return
	var burst: BreakoutShards = SHARD_SCENE.instantiate()
	# Add before setup: setup() drives @onready children (CONSTITUTION 五).
	_shards.add_child(burst)
	burst.setup(brick.global_rect().get_center(), at_color, _ball.velocity, _cfg.shards)


## Resolves the file for the current `_level`, wraps around when the files run
## out, and re-tiles the field to whatever grid it holds. Falls back to the
## built-in level when a file is missing or rejected, so a bad edit costs one
## level rather than the whole board.
func _load_level() -> void:
	_level_data = null
	if not _level_paths.is_empty():
		var index := posmod(_level - 1, _level_paths.size())
		_level_data = BreakoutLevel.load_file(_level_paths[index])
	if _level_data == null or not _level_fits():
		_level_data = BreakoutLevel.fallback()
	BreakoutField.configure(_cfg.field, _level_data)


## Rejections are loud and specific: a level that asks for more layers than the
## tables have entries would silently read the wrong colour and score, and a block
## that reaches the paddle is one the ball can get stuck in.
func _level_fits() -> bool:
	var layers: int = (_cfg.field.layer_scores as Array).size()
	var deepest := _level_data.max_hits()
	if deepest > layers:
		push_error("BreakoutGame: %s asks for %d layers, but the layer tables only go to %d"
				% [_level_data.source, deepest, layers])
		return false
	var paddle_top: float = _paddle.position.y - _paddle.half_height
	if BreakoutField.brick_block_bottom() > paddle_top - float(_cfg.field.brick_clearance):
		push_error("BreakoutGame: %s reaches y = %.1f, too close to the paddle at %.1f"
				% [_level_data.source, BreakoutField.brick_block_bottom(), paddle_top])
		return false
	return true


func _build_bricks() -> void:
	# retire() rather than queue_free(): the outgoing bricks have to leave the
	# ball's collision set now, not when their frees land at the end of the frame.
	for child in _bricks.get_children():
		var old := child as BreakoutBrick
		if old != null:
			old.retire()

	# Holes are simply not built, so a level with a shape is also a level with
	# fewer nodes for the ball's sweep to walk.
	_remaining = 0
	for row in _level_data.row_count():
		for col in _level_data.cols:
			var hits := _level_data.hits(row, col)
			if hits <= 0:
				continue
			var brick: BreakoutBrick = BRICK_SCENE.instantiate()
			# Add before setup: setup() drives @onready children, which only
			# resolve for a node already in the tree.
			_bricks.add_child(brick)
			brick.setup(BreakoutField.brick_rect(row, col),
					_cfg.field.layer_colors, hits)
			_remaining += 1


# --- states -----------------------------------------------------------------

func _enter_title() -> void:
	_state = State.TITLE
	_score = 0
	_level = 1
	_lives = int(_cfg.play.lives)
	_cheat = false
	_paddle.set_width_scale(1.0)
	_load_level()
	_build_bricks()
	_apply_level_speed()
	_reset_combo()
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
	_load_level()
	_build_bricks()
	_apply_level_speed()
	_hud.set_score(_score, _high)
	_hud.set_level(_level)
	_hud.set_lives(_lives)
	_enter_ready()


## The ball sits on the paddle so the player can line the shot up first.
func _enter_ready() -> void:
	_state = State.READY
	# A fresh ball is a fresh run at the bricks, so the combo starts over. This
	# is also the path a cleared level takes.
	_reset_combo()
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
	# `_load_level` wraps around once the files run out, so the campaign loops
	# while the speed keeps climbing (DECISION_LOG 049).
	_load_level()
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
			if Input.is_action_just_pressed("fire"):
				_try_swing()
		State.DYING:
			_state_timer -= delta
			if _state_timer <= 0.0:
				_after_life_lost()
		State.LEVEL_CLEAR:
			_state_timer -= delta
			if _state_timer <= 0.0:
				_after_level_clear()

	_refresh_trail()
	_refresh_debug()


## Swinging is the one thing the player does mid-rally: it both saves a ball
## heading past the paddle and puts real force behind the return, so it is worth
## a sound of its own. Idempotent — a swing already running swallows the input,
## so holding the key is not a free re-swing.
func _try_swing() -> void:
	if _paddle.swing():
		_audio.play_swing()


## Pointer or keys, whichever moved last. A click is handled in _unhandled_input
## (see there), which is why the root Control stays on IGNORE: that is what lets
## both the motion and the click reach this script.
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
		return

	# A click does what space does. With the pointer already in hand, reaching
	# for the keyboard to launch or restart is a needless trip.
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	match _state:
		State.TITLE, State.OVER:
			_start_run()
		State.READY:
			_launch()
		State.PLAYING:
			_try_swing()


func _toggle_cheat() -> void:
	_cheat = not _cheat
	_paddle.set_width_scale(float(_cfg.paddle.cheat_width_scale) if _cheat else 1.0)


# --- ball callbacks ---------------------------------------------------------

## A hit either chips a layer off a multi-layer brick or finishes it. The layer
## struck indexes both the score and the tone (DECISION_LOG 049), and it has to be
## read BEFORE the hit, because `hit()` already moved the brick on by one.
func _on_brick_hit(brick: BreakoutBrick) -> void:
	# Reached from the ball's physics step: only flags, score and a sound here.
	# Rebuilding anything waits for _process.
	if brick.is_out_of_play():
		return
	var layer := brick.hp
	var was_color := brick.color()
	var destroyed := brick.hit()

	# Every hit pays, so a two-layer brick is worth both of its layers. Only the
	# hit that removes a brick counts as part of a combo — a combo counts bricks
	# broken, and a chip is not one.
	if destroyed:
		_remaining -= 1
		_combo += 1
	var multiplier := _combo_multiplier()
	_add_score(int(_cfg.field.layer_scores[layer - 1]) * multiplier)
	_spawn_shards(brick, was_color)
	_audio.play_brick(layer - 1, _combo_pitch())

	if not destroyed:
		return
	_hud.set_combo(_combo, multiplier)
	if _remaining <= 0:
		_begin_level_clear()


## What a brick is worth right now. The first `combo_step` bricks of a run pay
## face value; after that the run starts multiplying.
func _combo_multiplier() -> int:
	var step := maxi(1, int(_cfg.scoring.combo_step))
	var reached := floori(float(maxi(0, _combo - 1)) / float(step))
	return clampi(1 + reached, 1, maxi(1, int(_cfg.scoring.combo_max)))


## The brick tone climbs with the run, so a long one plays as a rising line.
func _combo_pitch() -> float:
	var climb := 1.0 + float(maxi(0, _combo - 1)) \
			* float(_cfg.scoring.combo_pitch_per_hit)
	return minf(climb, float(_cfg.scoring.combo_pitch_max))


func _reset_combo() -> void:
	if _combo == 0:
		return
	_combo = 0
	_hud.set_combo(0, 1)


## A swing smash is not the ball coming home — it is the player reaching out and
## hitting it, so it does not break the run. The ball goes gold for as long as it
## carries the combo, which is the only thing that needs to be said about it.
func _on_paddle_hit(smashed: bool) -> void:
	if smashed:
		_audio.play_smash()
		return
	_audio.play_paddle()
	_reset_combo()


func _on_wall_hit() -> void:
	_audio.play_wall()


## The retract caught the ball. Back to READY, so it is the player's aim again —
## the point of the mechanic is that a save costs a life nothing but a re-aim.
func _on_ball_caught() -> void:
	if _state != State.PLAYING:
		return
	_audio.play_catch()
	_enter_ready()
	# The catch is worth nothing if the relaunch is as random as a fresh ball, so
	# say what it bought: the next shot is aimed tighter than usual.
	_message.text = "CAUGHT\n\nPRESS SPACE TO LAUNCH"


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
