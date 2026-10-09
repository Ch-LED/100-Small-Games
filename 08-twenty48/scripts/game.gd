class_name Twenty48Game
extends Control
## 2048 controller: input, the move/score/spawn loop, the board's rendering, and
## the three cheat/debug keys.
##
## The board's 16 cells are fixed scene structure arranged by a GridContainer, so
## this script never positions anything — it only swaps each cell's style and
## text to match the model.

enum State { TITLE, PLAYING, OVER }

## Each entry: the two actions that mean one direction, and the direction.
const KEY_ACTIONS := [
	["wasd_left", "arrow_left", Game2048Grid.Direction.LEFT],
	["wasd_right", "arrow_right", Game2048Grid.Direction.RIGHT],
	["wasd_up", "arrow_up", Game2048Grid.Direction.UP],
	["wasd_down", "arrow_down", Game2048Grid.Direction.DOWN],
]

const TITLE_FONT_SIZE := 48
const MESSAGE_FONT_SIZE := 24
const NOTICE_SECONDS := 1.2
## The debug readout sits in the gap between the HUD and the top of the board;
## banners live in the band under the board, so neither overlaps the tiles.
const DEBUG_GAP := 30.0

@onready var _background: ColorRect = $Background
@onready var _board: GridContainer = $Board
@onready var _debug: Game2048Debug = $DebugDraw
@onready var _hud: Game2048Hud = $Hud
@onready var _title: Label = $Overlay/Title
@onready var _message: Label = $Overlay/Message
@onready var _audio: Game2048Audio = $Audio
## The 16 cells, row-major: index = row * 4 + col. Declared explicitly so the
## scene's structure stays visible in the script rather than being guessed at.
@onready var _cells: Array[Panel] = [
	$Board/Cell0, $Board/Cell1, $Board/Cell2, $Board/Cell3,
	$Board/Cell4, $Board/Cell5, $Board/Cell6, $Board/Cell7,
	$Board/Cell8, $Board/Cell9, $Board/Cell10, $Board/Cell11,
	$Board/Cell12, $Board/Cell13, $Board/Cell14, $Board/Cell15,
]
@onready var _values: Array[Label] = [
	$Board/Cell0/Value, $Board/Cell1/Value, $Board/Cell2/Value, $Board/Cell3/Value,
	$Board/Cell4/Value, $Board/Cell5/Value, $Board/Cell6/Value, $Board/Cell7/Value,
	$Board/Cell8/Value, $Board/Cell9/Value, $Board/Cell10/Value, $Board/Cell11/Value,
	$Board/Cell12/Value, $Board/Cell13/Value, $Board/Cell14/Value, $Board/Cell15/Value,
]

var _cfg := {}
var _model: Game2048Grid
var _rng := RandomNumberGenerator.new()
## StyleBoxes are built once per colour and shared: a tile only ever swaps which
## one it points at.
var _styles := {}
var _empty_style: StyleBoxFlat

var _state: int = State.TITLE
var _score := 0
var _best := 0
var _moves := 0
var _cheat_no_spawn := false
## The `]` super cheat: every spawned tile is the board's largest, so a slide
## almost always has something to merge with.
var _cheat_max_spawn := false
var _debug_on := false
var _announced_2048 := false
var _notice_timer := 0.0
var _board_origin := Vector2.ZERO
var _board_size := Vector2.ZERO


func _ready() -> void:
	_cfg = Game2048Settings.load_all()
	if not _validate_tiles():
		return
	_model = Game2048Grid.new()
	_rng.randomize()

	_background.color = _cfg.board.bg_color
	_build_styles()
	_layout_board()
	_hud.build(_cfg)

	PixelFont.apply(_title, TITLE_FONT_SIZE)
	PixelFont.apply(_message, MESSAGE_FONT_SIZE)
	# Banners sit under the board on a cream background, so they take the dark
	# text colour: the light one is for text on a tile, and is invisible here.
	_title.add_theme_color_override("font_color", _cfg.tiles.dark_text_color)
	_message.add_theme_color_override("font_color", _cfg.tiles.dark_text_color)
	_enter_title()


## The value->colour table is indexed in step, so a length mismatch would draw
## the wrong colours or run off the end.
func _validate_tiles() -> bool:
	var values: Array = _cfg.tiles.values
	var colors: Array = _cfg.tiles.colors
	if values.size() == colors.size() and not values.is_empty():
		return true
	push_error("Twenty48Game: tiles.values and tiles.colors must be the same length")
	return false


# --- layout -----------------------------------------------------------------

func _build_styles() -> void:
	_empty_style = _make_style(_cfg.board.empty_color)
	for i in _cfg.tiles.values.size():
		_styles[int(_cfg.tiles.values[i])] = _make_style(_cfg.tiles.colors[i])


## Rounded tiles come from StyleBoxFlat's own corner radii, not from faking it
## with a plain colour rect.
func _make_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(int(_cfg.board.corner_radius))
	return style


## Sizing and centring only. The grid itself is laid out by the GridContainer,
## so no cell is ever positioned by hand.
func _layout_board() -> void:
	var tile := float(_cfg.board.tile_size)
	var gap := int(_cfg.board.gap)
	for cell in _cells:
		cell.custom_minimum_size = Vector2(tile, tile)
	for label in _values:
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_board.add_theme_constant_override("h_separation", gap)
	_board.add_theme_constant_override("v_separation", gap)

	_board_size = Vector2(tile, tile) * float(Game2048Grid.SIZE) \
			+ Vector2(gap, gap) * float(Game2048Grid.SIZE - 1)
	_board_origin = (Game2048Settings.FIELD - _board_size) * 0.5
	_board.position = _board_origin


func _refresh_board() -> void:
	for i in Game2048Grid.CELLS:
		var value := _model.cells[i]
		var label := _values[i]
		if value == 0:
			_cells[i].add_theme_stylebox_override("panel", _empty_style)
			label.text = ""
			continue
		_cells[i].add_theme_stylebox_override("panel", _style_for(value))
		label.text = str(value)
		label.add_theme_color_override("font_color", _text_color_for(value))
		PixelFont.apply(label, _font_for(value))


## The tile colour is the last table entry that is >= the value, so anything past
## the end of the table keeps the last look instead of falling off it.
func _style_for(value: int) -> StyleBoxFlat:
	var values: Array = _cfg.tiles.values
	for i in values.size():
		if value <= int(values[i]):
			return _styles[int(values[i])]
	return _styles[int(values[values.size() - 1])]


func _text_color_for(value: int) -> Color:
	if value <= int(_cfg.tiles.dark_text_upto):
		return _cfg.tiles.dark_text_color
	return _cfg.tiles.light_text_color


func _font_for(value: int) -> int:
	var sizes: Array = _cfg.board.font_sizes
	var digits := str(value).length()
	return int(sizes[clampi(digits - 1, 0, sizes.size() - 1)])


# --- states -----------------------------------------------------------------

func _enter_title() -> void:
	_state = State.TITLE
	_score = 0
	_moves = 0
	_cheat_no_spawn = false
	_cheat_max_spawn = false
	_announced_2048 = false
	_model.reset()
	_hud.set_score(_score, _best)
	_hud.set_max(0)
	_sync_cheat_hud()
	_title.text = "2048"
	_message.text = "PRESS SPACE TO START"
	_refresh_board()


func _start_run() -> void:
	_score = 0
	_moves = 0
	_cheat_no_spawn = false
	_cheat_max_spawn = false
	_announced_2048 = false
	_notice_timer = 0.0
	_model.reset()
	_spawn()
	_spawn()

	_hud.set_score(_score, _best)
	_hud.set_max(_model.largest())
	_sync_cheat_hud()
	_title.text = ""
	_message.text = ""
	_audio.play_start()
	_state = State.PLAYING
	_refresh_board()


func _finish() -> void:
	_state = State.OVER
	_audio.play_over()
	_title.text = "GAME OVER"
	_message.text = "SCORE %d\n\nPRESS SPACE" % _score


# --- the move loop ----------------------------------------------------------

func _try_move(direction: int) -> void:
	if _state != State.PLAYING:
		return
	var result := _model.slide(direction)
	# A move that changes nothing is not a move: no spawn, no sound, no score.
	if not bool(result.moved):
		return

	_moves += 1
	_audio.play_slide()

	var merges: Array = result.merges
	if not merges.is_empty():
		_add_score(int(result.gained))
		_audio.play_merge(int(merges.max()))

	if not _cheat_no_spawn:
		_spawn()

	_refresh_board()
	_hud.set_max(_model.largest())
	_check_reached_2048()
	_check_finished()


## The super cheat hands over the board's own largest tile. On an empty board
## that is 0, which is exactly the "roll it normally" case, so the opening two
## tiles are the usual 2s and 4s.
func _spawn() -> void:
	var forced := _model.largest() if _cheat_max_spawn else 0
	_model.spawn(_rng, float(_cfg.board.spawn_four_chance), forced)


func _add_score(value: int) -> void:
	_score += value
	if _score > _best:
		_best = _score
	_hud.set_score(_score, _best)


## Reaching 2048 is a milestone, not an ending: the original lets you carry on.
func _check_reached_2048() -> void:
	if _announced_2048 or _model.largest() < 2048:
		return
	_announced_2048 = true
	_audio.play_reached()
	_show_notice("2048!")


func _check_finished() -> void:
	if _model.can_move():
		return
	_finish()


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
	if Input.is_action_just_pressed("super_cheat_toggle"):
		_toggle_super_cheat()

	match _state:
		State.TITLE, State.OVER:
			if Input.is_action_just_pressed("fire"):
				_start_run()
		State.PLAYING:
			_tick_notice(delta)

	_refresh_debug()


## Key events rather than polling, and without echo: one press is exactly one
## move, so holding a key does not repeat.
func _unhandled_input(event: InputEvent) -> void:
	if _state != State.PLAYING:
		return
	for entry in KEY_ACTIONS:
		for i in 2:
			if event.is_action_pressed(str(entry[i])):
				_try_move(int(entry[2]))
				return


func _toggle_cheat() -> void:
	_cheat_no_spawn = not _cheat_no_spawn
	_sync_cheat_hud()
	_show_notice("NO SPAWN ON" if _cheat_no_spawn else "NO SPAWN OFF")


## The `]` super cheat: the board keeps being fed its own largest tile, so a
## merge is nearly always one slide away and 2048 arrives in a hurry.
func _toggle_super_cheat() -> void:
	_cheat_max_spawn = not _cheat_max_spawn
	_sync_cheat_hud()
	_show_notice("MAX SPAWN ON" if _cheat_max_spawn else "MAX SPAWN OFF")


func _sync_cheat_hud() -> void:
	_hud.set_cheat(_cheat_no_spawn, _cheat_max_spawn)


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
	_debug.text = "MOVES %d   EMPTY %d   MAX %d   " % [
		_moves, _model.empty_indices().size(), _model.largest()]
	_debug.legal = [
		_direction_legal(Game2048Grid.Direction.LEFT),
		_direction_legal(Game2048Grid.Direction.RIGHT),
		_direction_legal(Game2048Grid.Direction.UP),
		_direction_legal(Game2048Grid.Direction.DOWN),
	]
	_debug.origin = Vector2(_board_origin.x, _board_origin.y - DEBUG_GAP)


## Answered by actually trying the move on a copy, so the readout can never
## disagree with what a key press would do.
func _direction_legal(direction: int) -> bool:
	var before := _model.snapshot()
	var moved := bool(_model.slide(direction).moved)
	_model.restore(before)
	return moved
