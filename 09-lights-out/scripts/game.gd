class_name LightsOutGame
extends Control
## Lights Out controller: input, the press/level loop, the board's rendering, and
## the two overlay keys.
##
## The board's 25 cells are fixed scene structure arranged by a GridContainer, so
## this script never positions anything — a cell is a light, and a press only
## swaps which style it points at.

enum State { TITLE, PLAYING, SOLVED }

const TITLE_FONT_SIZE := 40
const MESSAGE_FONT_SIZE := 24
const NOTICE_SECONDS := 1.0
## The readout sits between the HUD and the top of the board, so it never covers
## a light; the banner lives in the band under the board.
const DEBUG_GAP := 30.0

@onready var _background: ColorRect = $Background
@onready var _backing: Panel = $BoardBacking
@onready var _board: GridContainer = $Board
@onready var _debug: LightsOutDebug = $DebugDraw
@onready var _hud: LightsOutHud = $Hud
@onready var _title: Label = $Overlay/Title
@onready var _message: Label = $Overlay/Message
@onready var _audio: LightsOutAudio = $Audio
## The 25 cells, row-major. Declared explicitly so the scene's structure stays
## visible in the script rather than being guessed at.
@onready var _cells: Array[Panel] = [
	$Board/Cell0, $Board/Cell1, $Board/Cell2, $Board/Cell3, $Board/Cell4,
	$Board/Cell5, $Board/Cell6, $Board/Cell7, $Board/Cell8, $Board/Cell9,
	$Board/Cell10, $Board/Cell11, $Board/Cell12, $Board/Cell13, $Board/Cell14,
	$Board/Cell15, $Board/Cell16, $Board/Cell17, $Board/Cell18, $Board/Cell19,
	$Board/Cell20, $Board/Cell21, $Board/Cell22, $Board/Cell23, $Board/Cell24,
]

var _cfg := {}
var _model: LightsOutGrid
var _rng := RandomNumberGenerator.new()
## Styles are keyed by the three flags that decide one (lit / hint / cursor), so
## the eight combinations are built lazily instead of being spelled out.
var _styles := {}

var _state: int = State.TITLE
var _level := 1
var _presses := 0
var _solved := 0
var _cheat_hint := false
var _debug_on := false
var _cursor := Vector2i(0, 0)
var _cursor_visible := false
var _state_timer := 0.0
var _notice_timer := 0.0
var _board_origin := Vector2.ZERO
var _board_size := Vector2.ZERO
## The solver is the most expensive thing here; recompute only after a change.
var _optimal_cache: Array[int] = []
var _optimal_dirty := true
## Which cells the `[` hint is currently marking.
var _hint_marks: Array[bool] = []


func _ready() -> void:
	_cfg = LightsOutSettings.load_all()
	_model = LightsOutGrid.new()
	_rng.randomize()

	_background.color = _cfg.board.bg_color
	# The slab the lights sit on, so the gaps read as part of the board rather
	# than as holes in the background.
	_backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backing.add_theme_stylebox_override("panel", _make_flat(
			_cfg.board.panel_color, int(_cfg.board.corner_radius) + 4))
	_layout_board()
	_hud.build(_cfg)

	PixelFont.apply(_title, TITLE_FONT_SIZE)
	PixelFont.apply(_message, MESSAGE_FONT_SIZE)
	_title.add_theme_color_override("font_color", _cfg.board.on_color)
	_message.add_theme_color_override("font_color", _cfg.board.cursor_color)
	_enter_title()


# --- build ------------------------------------------------------------------

## Sizing and centring only. The grid itself is laid out by the GridContainer,
## so no cell is ever positioned by hand.
func _layout_board() -> void:
	var cell := float(_cfg.board.cell_size)
	var gap := int(_cfg.board.gap)
	for panel in _cells:
		panel.custom_minimum_size = Vector2(cell, cell)
	_board.add_theme_constant_override("h_separation", gap)
	_board.add_theme_constant_override("v_separation", gap)

	_board_size = Vector2(cell, cell) * float(LightsOutGrid.SIZE) \
			+ Vector2(gap, gap) * float(LightsOutGrid.SIZE - 1)
	_board_origin = (LightsOutSettings.FIELD - _board_size) * 0.5
	_board.position = _board_origin

	var pad := float(gap) * 1.5
	_backing.position = _board_origin - Vector2(pad, pad)
	_backing.size = _board_size + Vector2(pad, pad) * 2.0


func _make_flat(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	return style


func _style_for(lit: bool, hint: bool, cursor: bool) -> StyleBoxFlat:
	var key := (1 if lit else 0) | (2 if hint else 0) | (4 if cursor else 0)
	if _styles.has(key):
		return _styles[key]

	var style := _make_flat(
			_cfg.board.on_color if lit else _cfg.board.off_color,
			int(_cfg.board.corner_radius))
	if hint or cursor:
		style.set_border_width_all(int(_cfg.board.hint_border))
		style.border_color = _cfg.board.hint_color if hint else _cfg.board.cursor_color
	_styles[key] = style
	return style


func _refresh_board() -> void:
	# Kept as a member rather than a local so what the hint highlights can be
	# read back and checked against the solver.
	_hint_marks.resize(LightsOutGrid.CELLS)
	_hint_marks.fill(false)
	if _cheat_hint:
		for index in _optimal():
			_hint_marks[int(index)] = true

	for row in LightsOutGrid.SIZE:
		for col in LightsOutGrid.SIZE:
			var index := row * LightsOutGrid.SIZE + col
			var style := _style_for(
					_model.get_cell(row, col),
					_hint_marks[index],
					_cursor_visible and _cursor == Vector2i(col, row))
			_cells[index].add_theme_stylebox_override("panel", style)


# --- solver access ----------------------------------------------------------

## Shortest solution to the board as it stands. Cached because the solver is the
## only real work in this game, and the board changes between calls.
func _optimal() -> Array[int]:
	if _optimal_dirty:
		_optimal_cache = _model.optimal_solution()
		_optimal_dirty = false
	return _optimal_cache


# --- states -----------------------------------------------------------------

func _enter_title() -> void:
	_state = State.TITLE
	_level = 1
	_presses = 0
	_solved = 0
	_cheat_hint = false
	_cursor = Vector2i(0, 0)
	_cursor_visible = false
	_model.reset()
	_optimal_dirty = true
	_hud.set_level(_level)
	_hud.set_presses(_presses)
	_hud.set_solved(_solved)
	_title.text = "LIGHTS OUT"
	_message.text = "PRESS SPACE TO START"
	_refresh_board()


func _start_run() -> void:
	_level = 1
	_presses = 0
	_solved = 0
	_cheat_hint = false
	_cursor = Vector2i(0, 0)
	_cursor_visible = false
	_notice_timer = 0.0
	_new_puzzle()

	_hud.set_level(_level)
	_hud.set_presses(_presses)
	_hud.set_solved(_solved)
	_title.text = ""
	_message.text = ""
	_audio.play_fresh()
	_state = State.PLAYING


## A fresh board, always generated by pressing distinct cells from the solved
## state, so it can always be finished (see LightsOutGrid.scramble).
func _new_puzzle() -> void:
	_model.scramble(_rng, _presses_for_level())
	_optimal_dirty = true
	_refresh_board()


func _presses_for_level() -> int:
	var wanted: int = int(_cfg.play.start_presses) \
			+ (_level - 1) * int(_cfg.play.presses_step)
	return mini(wanted, int(_cfg.play.presses_cap))


func _next_puzzle() -> void:
	_level += 1
	_presses = 0
	_cursor = Vector2i(0, 0)
	_cursor_visible = false
	_new_puzzle()
	_hud.set_level(_level)
	_hud.set_presses(_presses)
	_title.text = ""
	_show_notice("LEVEL %d" % _level)
	_audio.play_fresh()
	_state = State.PLAYING


func _check_solved() -> void:
	if not _model.is_solved():
		return
	_state = State.SOLVED
	_solved += 1
	_hud.set_solved(_solved)
	_audio.play_solved()
	_cursor_visible = false
	_title.text = "SOLVED IN %d" % _presses
	_refresh_board()
	_state_timer = float(_cfg.play.solve_pause)


# --- the press loop ---------------------------------------------------------

func _press_cell(row: int, col: int) -> void:
	if _state != State.PLAYING or not _model.is_inside(row, col):
		return
	_model.press(row, col)
	_optimal_dirty = true
	_presses += 1
	_hud.set_presses(_presses)
	_audio.play_press(row)
	_cursor = Vector2i(col, row)
	_title.text = ""
	_refresh_board()
	_check_solved()


# --- per-frame --------------------------------------------------------------

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		GameRouter.back_to_hub()
		return
	if Input.is_action_just_pressed("debug_toggle"):
		_debug_on = not _debug_on
		_debug.enabled = _debug_on
	if Input.is_action_just_pressed("cheat_toggle"):
		_toggle_hint()

	match _state:
		State.TITLE:
			if Input.is_action_just_pressed("fire"):
				_start_run()
		State.PLAYING:
			_tick_notice(delta)
		State.SOLVED:
			_state_timer -= delta
			if _state_timer <= 0.0:
				_next_puzzle()

	_refresh_debug()


## Key events rather than polling, and without echo: one press moves the cursor
## one cell, and holding a key does not run away with it.
func _unhandled_input(event: InputEvent) -> void:
	if _state != State.PLAYING:
		return
	var step := Vector2i.ZERO
	if event.is_action_pressed("wasd_left") or event.is_action_pressed("arrow_left"):
		step = Vector2i(-1, 0)
	elif event.is_action_pressed("wasd_right") or event.is_action_pressed("arrow_right"):
		step = Vector2i(1, 0)
	elif event.is_action_pressed("wasd_up") or event.is_action_pressed("arrow_up"):
		step = Vector2i(0, -1)
	elif event.is_action_pressed("wasd_down") or event.is_action_pressed("arrow_down"):
		step = Vector2i(0, 1)

	if step != Vector2i.ZERO:
		_cursor = Vector2i(
				clampi(_cursor.x + step.x, 0, LightsOutGrid.SIZE - 1),
				clampi(_cursor.y + step.y, 0, LightsOutGrid.SIZE - 1))
		_cursor_visible = true
		_refresh_board()
		return

	if event.is_action_pressed("fire"):
		_press_cell(_cursor.y, _cursor.x)


## Mouse goes through gui_input, whose positions are already in this Control's
## own coordinates — no need to reason about the stretch transform.
func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	# A click does what space does on the title screen (same note as in
	# 06-simon): the pointer is already in hand.
	if _state == State.TITLE:
		_start_run()
		return
	if _state != State.PLAYING:
		return
	var cell := _cell_at(click.position)
	if cell.x < 0:
		return
	# The pointer takes over as the indicator; the keyboard cursor steps aside.
	_cursor_visible = false
	_press_cell(cell.y, cell.x)


## Which light a point lands on, or (-1, -1) for the gaps and the surround.
func _cell_at(point: Vector2) -> Vector2i:
	var cell := float(_cfg.board.cell_size)
	var step := cell + float(_cfg.board.gap)
	var local := point - _board_origin
	if local.x < 0.0 or local.y < 0.0:
		return Vector2i(-1, -1)
	var col := int(local.x / step)
	var row := int(local.y / step)
	if col >= LightsOutGrid.SIZE or row >= LightsOutGrid.SIZE:
		return Vector2i(-1, -1)
	if local.x - float(col) * step > cell or local.y - float(row) * step > cell:
		return Vector2i(-1, -1)
	return Vector2i(col, row)


func _toggle_hint() -> void:
	_cheat_hint = not _cheat_hint
	_refresh_board()
	_show_notice("SOLUTION ON" if _cheat_hint else "SOLUTION OFF")


func _show_notice(text: String) -> void:
	if _state != State.PLAYING:
		return
	_message.text = text
	_notice_timer = NOTICE_SECONDS


func _tick_notice(delta: float) -> void:
	if _notice_timer <= 0.0:
		return
	_notice_timer -= delta
	if _notice_timer <= 0.0:
		_message.text = ""


# --- debug overlay ----------------------------------------------------------

func _refresh_debug() -> void:
	if not _debug_on:
		return
	_debug.text = "PRESSES %d   LIT %d   OPTIMAL %d" % [
		_presses, _model.lit_count(), _optimal().size()]
	_debug.origin = Vector2(_board_origin.x, _board_origin.y - DEBUG_GAP)
