class_name SnakeGame
extends Control
## Snake controller: builds the board and the snake, runs the step loop, and
## owns scoring, levels, food placement and the debug overlay.

enum State { READY, PLAYING, DEAD, GAME_OVER, WIN }

const FOOD_SCENE := preload("res://04-snake/scenes/food.tscn")
const READY_TIME := 1.2
const DEATH_TIME := 0.7
const NOTICE_TIME := 0.9
const OVERLAY_FONT_SIZE := 32
const CHEAT_ON_TEXT := "WALL PASS ON"
const CHEAT_OFF_TEXT := "WALL PASS OFF"

@onready var _background: ColorRect = $Background
@onready var _board: SnakeBoard = $Board
@onready var _body: SnakeBody = $Playfield/Body
@onready var _food_slot: Node2D = $Playfield/FoodSlot
@onready var _hud: SnakeHud = $Hud
@onready var _overlay_label: Label = $Overlay/Message
@onready var _audio: SnakeAudio = $Audio

var _cfg := {}
var _rng := RandomNumberGenerator.new()

var _food: SnakeFood = null
var _food_cell := Vector2i(-1, -1)

var _state: int = State.READY
var _score := 0
var _best := 0
var _level := 1
var _foods_eaten := 0
var _step_timer := 0.0
var _state_timer := 0.0
var _notice_timer := 0.0
var _debug := false
## Cheat key state: layered on top of the cfg's own wrap_edges, per run.
var _cheat_wrap := false


func _ready() -> void:
	_cfg = SnakeSettings.load_all()
	# Must run before anything lays out, since the grid derives from it.
	SnakeGrid.configure(_cfg.board.cell_size, _cfg.board.cols, _cfg.board.rows)
	_rng.randomize()

	_background.color = _cfg.field.bg_color
	_board.configure(_cfg.field.board_color, _cfg.field.grid_color,
			_cfg.field.border_color, _cfg.field.border_color_cheat, _cfg.field.border_width)
	_body.configure(SnakeGrid.CELL, _cfg.snake.segment_inset, _cfg.snake.body_color,
			_cfg.snake.head_color, _cfg.snake.dead_color, _cfg.snake.wrap_edges)
	_hud.build(_cfg)
	PixelFont.apply(_overlay_label, OVERLAY_FONT_SIZE)
	_overlay_label.add_theme_color_override("font_color", _cfg.snake.head_color)
	_start_run()


# --- run lifecycle ----------------------------------------------------------

func _start_run() -> void:
	_score = 0
	_level = 1
	_foods_eaten = 0
	_step_timer = 0.0
	_cheat_wrap = false
	_notice_timer = 0.0
	_body.reset(_starting_cells(), _start_direction())
	_apply_wrap()
	_hud.set_score(_score, _best)
	_hud.set_level(_level)
	_hud.set_length(_body.length())
	_spawn_food()
	_state = State.READY
	_state_timer = READY_TIME
	_overlay_label.text = "READY!"
	_board.set_marks([])
	_audio.play_start()
	_audio.play_music()


func _starting_cells() -> Array[Vector2i]:
	var dir := _start_direction()
	var head := Vector2i(int(SnakeGrid.COLS * 0.5), int(SnakeGrid.ROWS * 0.5))
	var cells: Array[Vector2i] = []
	for i in int(_cfg.snake.start_length):
		cells.append(head - dir * i)
	return cells


func _start_direction() -> Vector2i:
	var dir := SnakeGrid.dir_from_name(str(_cfg.snake.start_dir))
	return dir if dir != SnakeGrid.DIR_NONE else SnakeGrid.DIR_RIGHT


# --- per-frame --------------------------------------------------------------

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("debug_toggle"):
		_debug = not _debug
		_refresh_debug()
	if Input.is_action_just_pressed("cheat_toggle"):
		_toggle_cheat()
	if Input.is_action_just_pressed("ui_cancel"):
		GameRouter.back_to_hub()
		return

	match _state:
		State.READY:
			_tick(delta, _begin_play)
		State.PLAYING:
			_tick_step(delta)
		State.DEAD:
			_tick(delta, _finish_game)
		State.GAME_OVER, State.WIN:
			if Input.is_action_just_pressed("fire"):
				_start_run()


## Reads turns as key events so that two keys in one frame keep their order
## (polling would collapse them into a fixed priority).
func _unhandled_input(event: InputEvent) -> void:
	if _state != State.PLAYING:
		return
	if event.is_action_pressed("wasd_up") or event.is_action_pressed("arrow_up"):
		_body.queue_direction(SnakeGrid.DIR_UP)
	elif event.is_action_pressed("wasd_down") or event.is_action_pressed("arrow_down"):
		_body.queue_direction(SnakeGrid.DIR_DOWN)
	elif event.is_action_pressed("wasd_left") or event.is_action_pressed("arrow_left"):
		_body.queue_direction(SnakeGrid.DIR_LEFT)
	elif event.is_action_pressed("wasd_right") or event.is_action_pressed("arrow_right"):
		_body.queue_direction(SnakeGrid.DIR_RIGHT)


func _tick(delta: float, on_done: Callable) -> void:
	_state_timer -= delta
	if _state_timer <= 0.0:
		on_done.call()


func _begin_play() -> void:
	_overlay_label.text = ""
	_state = State.PLAYING
	_step_timer = 0.0
	_refresh_debug()


func _tick_step(delta: float) -> void:
	_tick_notice(delta)
	_step_timer += delta
	if _step_timer < _interval():
		return
	_step_timer = 0.0

	if not _body.advance():
		_begin_death()
		return
	_hud.set_length(_body.length())
	if _body.head_cell() == _food_cell:
		_on_eat()
	_refresh_debug()


## Seconds per grid step: shortens one step per level, down to a floor.
func _interval() -> float:
	var effective := mini(_level, int(_cfg.level.level_cap)) - 1
	var interval: float = _cfg.snake.base_interval - _cfg.snake.interval_step * float(effective)
	return maxf(_cfg.snake.min_interval, interval)


# --- food / score / level ---------------------------------------------------

func _spawn_food() -> void:
	var free_cells := _free_cells()
	if free_cells.is_empty():
		_begin_win()
		return
	_clear_food()
	_food_cell = free_cells[_rng.randi_range(0, free_cells.size() - 1)]
	_food = FOOD_SCENE.instantiate()
	_food_slot.add_child(_food)
	_food.configure(_food_cell, SnakeGrid.CELL, _cfg.food.color,
			_cfg.food.pulse_speed, _cfg.food.pulse_min)


func _clear_food() -> void:
	if is_instance_valid(_food):
		_food.queue_free()
	_food = null
	_food_cell = Vector2i(-1, -1)


func _free_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for row in SnakeGrid.ROWS:
		for col in SnakeGrid.COLS:
			var cell := Vector2i(col, row)
			if not _body.occupies(cell):
				out.append(cell)
	return out


func _on_eat() -> void:
	_foods_eaten += 1
	_score += int(_cfg.food.score)
	if _score > _best:
		_best = _score
	_body.grow(int(_cfg.snake.growth_per_food))
	_audio.play_eat()
	_hud.set_score(_score, _best)

	var per_level := maxi(1, int(_cfg.level.foods_per_level))
	if _foods_eaten % per_level == 0 and _level < int(_cfg.level.level_cap):
		_level += 1
		_hud.set_level(_level)
		_audio.play_level_up()
	_spawn_food()


# --- endings ----------------------------------------------------------------

func _begin_death() -> void:
	_state = State.DEAD
	_state_timer = DEATH_TIME
	_notice_timer = 0.0
	_overlay_label.text = ""
	_body.set_dead_tint(true)
	_audio.stop_music()
	_audio.play_death()
	_board.set_marks([])


func _finish_game() -> void:
	_state = State.GAME_OVER
	_overlay_label.text = "GAME OVER\nPRESS SPACE"


func _begin_win() -> void:
	_state = State.WIN
	_overlay_label.text = "YOU WIN\nPRESS SPACE"


# --- debug overlay ----------------------------------------------------------

## Read-only aid: outlines the three cells the head could turn into next step,
## red when entering would be fatal. Uses the same rule the step itself uses.
func _refresh_debug() -> void:
	if not _debug or _state != State.PLAYING:
		_board.set_marks([])
		return
	var marks: Array[Dictionary] = []
	var dir := _body.direction()
	for candidate in SnakeGrid.DIRECTIONS:
		if SnakeGrid.is_opposite(candidate, dir):
			continue
		var target := _body.step_target(candidate)
		marks.append({"cell": target, "lethal": _body.would_die_entering(target)})
	_board.set_marks(marks)


# --- cheat ------------------------------------------------------------------

## The cheat key toggles wall pass: the snake comes out the far side instead of
## dying.
## Reset at the start of every run, so a fresh run always plays by real rules.
func _toggle_cheat() -> void:
	_cheat_wrap = not _cheat_wrap
	_apply_wrap()
	_refresh_debug()
	_show_notice(CHEAT_ON_TEXT if _cheat_wrap else CHEAT_OFF_TEXT)


## The cfg can already ask for wrapping; the cheat layers on top of it.
func _apply_wrap() -> void:
	_body.wrap_edges = bool(_cfg.snake.wrap_edges) or _cheat_wrap
	_board.set_wrapping(_body.wrap_edges)


func _show_notice(text: String) -> void:
	if _state != State.PLAYING:
		return
	_overlay_label.text = text
	_notice_timer = NOTICE_TIME


func _tick_notice(delta: float) -> void:
	if _notice_timer <= 0.0:
		return
	_notice_timer -= delta
	if _notice_timer <= 0.0:
		_overlay_label.text = ""
