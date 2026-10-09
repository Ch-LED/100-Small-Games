class_name PacmanGame
extends Control
## Pac-Man controller: builds the maze and actors, runs the level loop, drives
## the scatter/chase alternation, and owns scoring / lives / fruit.

enum State { READY, PLAYING, DYING, LEVEL_CLEAR, GAME_OVER }

const START_CELL := Vector2i(13, 23)
const PACMAN_START_FACING := PacmanGrid.DIR_LEFT
const FRUIT_CELL := Vector2i(13, 11)

## id, colour, and where the ghost waits. Blinky starts outside the house;
## the other three sit on separate in-house cells so they do not overlap.
const GHOST_DEFS := [
	{"id": "blinky", "color": Color("FF0000"), "home": Vector2i(13, 11)},
	{"id": "pinky", "color": Color("FFB8FF"), "home": Vector2i(13, 14)},
	{"id": "inky", "color": Color("00FFFF"), "home": Vector2i(11, 14)},
	{"id": "clyde", "color": Color("FFB852"), "home": Vector2i(15, 14)},
]

const PLAYER_SCENE := preload("res://03-pacman/scenes/player.tscn")
const GHOST_SCENE := preload("res://03-pacman/scenes/ghost.tscn")
const FRUIT_SCENE := preload("res://03-pacman/scenes/fruit.tscn")

@onready var _background: ColorRect = $Background
@onready var _maze: PacmanMaze = $Maze
@onready var _pellets: PacmanPellets = $Maze/Pellets
@onready var _playfield: Node2D = $Playfield
@onready var _pacman: PacmanPlayer = $Playfield/Pacman
@onready var _ghost_root: Node2D = $Playfield/Ghosts
@onready var _fruit_slot: Node2D = $Playfield/FruitSlot
@onready var _hud: PacmanHud = $Hud
@onready var _overlay: Control = $Overlay
@onready var _overlay_label: Label = $Overlay/Message
@onready var _audio: PacmanAudio = $Audio

var _cfg := {}
var _sprites: PacmanSprites
var _debug: PacmanDebug

var _ghosts: Array[PacmanGhost] = []
var _fruit: PacmanFruit = null

var _state: int = State.READY
var _score := 0
var _high := 0
var _lives := 3
var _level := 1
var _ghosts_eaten := 0
var _level_fruits := 0
## Remaining pellet counts that trigger a fruit this level (from cfg).
var _pending_fruits: Array = []

## The `]` super cheat, mirrored onto every ghost.
var _super_cheat := false
## The `[` cheat: Pac-Man walks through walls. Reset by `_restart` with the other.
var _cheat_noclip := false

var _mode_timer := 0.0
var _mode_index := 0
var _fright_timer := 0.0
var _release_timer := 0.0
var _state_timer := 0.0
var _death_index := -1


func _ready() -> void:
	_cfg = PacmanSettings.load_all()
	# Must run before anything lays out, since ORIGIN/MAZE_SIZE derive from it.
	PacmanGrid.configure(_cfg.field.cell_size)
	_sprites = PacmanSprites.new()
	_sprites.load_all()

	_background.color = _cfg.field.bg_color
	_maze.load_layout(_cfg.assets.layout)
	_pellets.setup(_maze, _sprites)
	_build_maze()
	_build_actors()
	_hud.build(_cfg, _sprites)

	_debug = PacmanDebug.new()
	_debug.ghosts = _ghosts
	add_child(_debug)
	if not _sprites.missing_layers().is_empty():
		push_warning("PacmanGame: placeholder art in use for %s" % str(_sprites.missing_layers()))
	_start_level(true)


# --- build ------------------------------------------------------------------

func _build_maze() -> void:
	_maze.build_tiles(PacmanGrid.CELL)


## Instantiates the reusable entity scenes; everything about their structure
## lives in the .tscn files, this only wires up references and parameters.
func _build_actors() -> void:
	_pacman.setup(_maze, _sprites, START_CELL, _cfg.player.speed)
	_pacman.pellet_eaten.connect(_on_pellet_eaten)

	var delays: Array = _cfg.ghost.release_delays
	for i in GHOST_DEFS.size():
		var def: Dictionary = GHOST_DEFS[i]
		var ghost: PacmanGhost = GHOST_SCENE.instantiate()
		var delay: float = delays[i] if i < delays.size() else 0.0
		_ghost_root.add_child(ghost)
		ghost.setup(def.id, def.color, _maze, _sprites, def["home"], delay)
		ghost.speeds = {
			"normal": _cfg.ghost.speed,
			"fright": _cfg.ghost.fright_speed,
			"tunnel": _cfg.ghost.tunnel_speed,
			"eaten": _cfg.ghost.eaten_speed,
		}
		ghost.pursuit = _pacman_info
		_ghosts.append(ghost)
	_overlay_label.add_theme_font_override("font", PixelFont.get_font())
	_overlay_label.add_theme_font_size_override("font_size", 24)
	_overlay_label.add_theme_color_override("font_color", Color("FFE600"))


# --- level loop -------------------------------------------------------------

func _start_level(first := false) -> void:
	_maze.remaining_pellets()
	_pending_fruits = _cfg.fruit.spawn_at.duplicate()
	_level_fruits = 0
	_fright_timer = 0.0
	_mode_timer = 0.0
	_mode_index = 0
	_ghosts_eaten = 0
	_reset_actors()
	_hud.set_score(_score, _high)
	_hud.set_lives(_lives)
	_hud.set_level_fruits(0)
	if _audio != null:
		_audio.play_intro() if first else _audio.stop_siren()
	_state = State.READY
	_state_timer = 1.8
	_overlay_label.text = "READY!"


func _reset_actors() -> void:
	_pacman.place_at(START_CELL)
	_pacman.dying = false
	_pacman.speed = _cfg.player.speed
	var delays: Array = _cfg.ghost.release_delays
	for i in _ghosts.size():
		var ghost := _ghosts[i]
		var home: Vector2i = GHOST_DEFS[i]["home"]
		var delay: float = delays[i] if i < delays.size() else 0.0
		var out_side := home.y < PacmanGhost.HOUSE_EXIT_ROW
		ghost.place_at(home, PacmanGrid.DIR_UP if not out_side else PacmanGrid.DIR_LEFT)
		ghost.set_state(PacmanGhost.State.HOUSE)
		if delay <= 0.0:
			ghost.release()
		elif out_side:
			# Starts outside the house, so it can hunt immediately.
			ghost.set_state(PacmanGhost.State.CHASE)
	_apply_level_scaling()
	_release_timer = 0.0


func _apply_level_scaling() -> void:
	var step: float = _cfg.level.ghost_speed_step
	var cap: int = _cfg.level.level_cap
	var effective := mini(_level, cap) - 1
	var scale := 1.0 + step * float(effective) / 100.0
	for ghost in _ghosts:
		ghost.level_scale = scale


func _fright_duration() -> float:
	var cap: int = _cfg.level.level_cap
	var effective := mini(_level, cap) - 1
	var duration: float = _cfg.ghost.fright_time - _cfg.ghost.fright_time_step * float(effective)
	return maxf(_cfg.ghost.fright_time_min, duration)


# --- per-frame --------------------------------------------------------------

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("debug_toggle"):
		_debug.enabled = not _debug.enabled
	if Input.is_action_just_pressed("cheat_toggle"):
		_toggle_cheat()
	if Input.is_action_just_pressed("super_cheat_toggle"):
		_toggle_super_cheat()
	if Input.is_action_just_pressed("ui_cancel"):
		GameRouter.back_to_hub()
		return

	match _state:
		State.READY:
			_tick_timer(delta, _advance_to_playing)
		State.PLAYING:
			_update_playing(delta)
			_tick_pellet_animation(delta)
		State.DYING:
			_update_dying(delta)
		State.LEVEL_CLEAR:
			_tick_timer(delta, _next_level)
		State.GAME_OVER:
			if Input.is_action_just_pressed("fire"):
				_restart()


func _tick_timer(delta: float, on_done: Callable) -> void:
	_state_timer -= delta
	if _state_timer <= 0.0:
		on_done.call()


func _advance_to_playing() -> void:
	_overlay_label.text = ""
	_state = State.PLAYING


func _update_playing(delta: float) -> void:
	_read_input()
	_tick_modes(delta)
	_tick_release(delta)
	_tick_fright(delta)
	_check_collisions()
	_check_fruit(0.0)
	_update_siren()


func _update_dying(delta: float) -> void:
	_state_timer -= delta
	if _state_timer < 0.0:
		_lives -= 1
		_hud.set_lives(_lives)
		if _lives <= 0:
			_finish_game()
		else:
			_reset_actors()
			_state = State.READY
			_state_timer = 1.4
			_overlay_label.text = "READY!"
			return
		return
	var frames := maxi(1, _sprites.frame_count("pacman", "death"))
	var progress := 1.0 - _state_timer / maxf(0.001, _cfg.player.death_time)
	var index := clampi(int(progress * float(frames)), 0, frames - 1)
	if index != _death_index:
		_death_index = index
		_pacman.play_death(index)


# --- input ------------------------------------------------------------------

func _read_input() -> void:
	var dir := PacmanGrid.DIR_NONE
	if Input.is_action_pressed("wasd_up") or Input.is_action_pressed("arrow_up"):
		dir = PacmanGrid.DIR_UP
	elif Input.is_action_pressed("wasd_down") or Input.is_action_pressed("arrow_down"):
		dir = PacmanGrid.DIR_DOWN
	elif Input.is_action_pressed("wasd_left") or Input.is_action_pressed("arrow_left"):
		dir = PacmanGrid.DIR_LEFT
	elif Input.is_action_pressed("wasd_right") or Input.is_action_pressed("arrow_right"):
		dir = PacmanGrid.DIR_RIGHT
	if dir != PacmanGrid.DIR_NONE:
		_pacman.set_desired(dir)


# --- ghosts -----------------------------------------------------------------

func _pacman_info() -> Dictionary:
	var blinky: Vector2i = _ghosts[0].cell() if not _ghosts.is_empty() else PacmanGrid.DIR_NONE
	return {"cell": _pacman.cell(), "dir": _pacman.dir, "blinky_cell": blinky}


func _tick_modes(delta: float) -> void:
	if _fright_timer > 0.0:
		return
	var durations: Array = _cfg.ghost.mode_durations
	_mode_timer += delta
	var duration: float = durations[_mode_index] if _mode_index < durations.size() else 1e9
	if _mode_timer < duration:
		return
	_mode_timer = 0.0
	_mode_index = mini(_mode_index + 1, durations.size() - 1)
	# Even index = scatter, odd index = chase (matches the cfg list layout).
	var scatter := _mode_index % 2 == 0
	for ghost in _ghosts:
		if ghost.state == PacmanGhost.State.CHASE or ghost.state == PacmanGhost.State.SCATTER:
			ghost.set_state(PacmanGhost.State.SCATTER if scatter else PacmanGhost.State.CHASE)


func _tick_release(delta: float) -> void:
	_release_timer += delta
	var delays: Array = _cfg.ghost.release_delays
	for i in _ghosts.size():
		var ghost := _ghosts[i]
		if ghost.state != PacmanGhost.State.HOUSE:
			continue
		var delay: float = delays[i] if i < delays.size() else 0.0
		if _release_timer >= delay:
			ghost.release()
			ghost.set_state(PacmanGhost.State.CHASE)


func _tick_fright(delta: float) -> void:
	if _fright_timer <= 0.0:
		return
	_fright_timer -= delta
	# The last stretch of the timer makes frightened ghosts flash white.
	var flashing := _fright_timer < 2.0
	for ghost in _ghosts:
		ghost.fright_flashing = flashing
	if _fright_timer <= 0.0:
		_ghosts_eaten = 0
		for ghost in _ghosts:
			ghost.fright_flashing = false
			if ghost.state == PacmanGhost.State.FRIGHTENED:
				ghost.set_state(PacmanGhost.State.CHASE)


func _start_fright() -> void:
	_fright_timer = _fright_duration()
	_ghosts_eaten = 0
	for ghost in _ghosts:
		if ghost.state != PacmanGhost.State.EATEN and ghost.state != PacmanGhost.State.HOUSE:
			ghost.set_state(PacmanGhost.State.FRIGHTENED)


func _eat_ghost(ghost: PacmanGhost) -> void:
	var scores: Array = _cfg.scoring.ghosts
	var value: int = scores[mini(_ghosts_eaten, scores.size() - 1)]
	_ghosts_eaten += 1
	_add_score(value)
	ghost.set_state(PacmanGhost.State.EATEN)
	_audio.play_eat_ghost()


func _check_collisions() -> void:
	for ghost in _ghosts:
		if ghost.state == PacmanGhost.State.EATEN:
			continue
		var dist := (_pacman.position - ghost.position).length()
		if dist > PacmanGrid.CELL * 0.7:
			continue
		if ghost.state == PacmanGhost.State.FRIGHTENED:
			_eat_ghost(ghost)
		elif ghost.state != PacmanGhost.State.HOUSE:
			_begin_death()
			return


func _begin_death() -> void:
	_state = State.DYING
	_death_index = -1
	_pacman.stop()
	_pacman.dying = true
	_state_timer = _cfg.player.death_time
	_audio.play_death()


# --- pellets / fruit / score ------------------------------------------------

func _on_pellet_eaten(kind: int, cell: Vector2i) -> void:
	if kind == PacmanMaze.PELLET_POWER:
		_add_score(int(_cfg.scoring.power_pellet))
		_audio.play_power()
		_start_fright()
	else:
		_add_score(int(_cfg.scoring.pellet))
		_audio.play_waka()
	_maybe_spawn_fruit(cell)
	if _maze.cleared():
		_begin_level_clear()


func _maybe_spawn_fruit(_cell: Vector2i) -> void:
	if _pending_fruits.is_empty():
		return
	var eaten := _maze.eaten_pellets()
	if eaten < int(_pending_fruits[0]):
		return
	_pending_fruits.pop_front()
	_spawn_fruit()


func _spawn_fruit() -> void:
	if is_instance_valid(_fruit):
		_fruit.queue_free()
	var types: Array = _cfg.fruit.types
	var kind: String = types[_level_fruits % types.size()]
	_fruit = FRUIT_SCENE.instantiate()
	_fruit_slot.add_child(_fruit)
	_fruit.setup(kind, _sprites, FRUIT_CELL, _cfg.fruit.lifetime)


func _check_fruit(_delta: float) -> void:
	if not is_instance_valid(_fruit):
		return
	if _pacman.cell() != PacmanGrid.cell_of(_fruit.position):
		return
	_add_score(_fruit.score())
	_audio.play_fruit()
	_level_fruits += 1
	_hud.set_level_fruits(_level_fruits)
	_fruit.queue_free()


func _add_score(value: int) -> void:
	_score += value
	if _score > _high:
		_high = _score
	_hud.set_score(_score, _high)
	if value > 0 and _score >= int(_cfg.player.extra_life_score) \
			and _score - value < int(_cfg.player.extra_life_score):
		_lives += 1
		_hud.set_lives(_lives)


func _begin_level_clear() -> void:
	_state = State.LEVEL_CLEAR
	_state_timer = 2.0
	_overlay_label.text = "LEVEL %d CLEARED" % _level
	_audio.stop_siren()


func _next_level() -> void:
	_level += 1
	_overlay_label.text = ""
	_maze.load_layout(_cfg.assets.layout)
	_start_level(false)


func _finish_game() -> void:
	_state = State.GAME_OVER
	_overlay_label.text = "GAME OVER\nPRESS SPACE"
	_audio.stop_siren()


## The `[` cheat: Pac-Man stops being stopped by walls, so the whole maze is
## reachable in a straight line. The walls stay drawn and the ghosts stay
## dangerous — what he gains is the map, not safety.
func _toggle_cheat() -> void:
	_cheat_noclip = not _cheat_noclip
	_pacman.set_noclip(_cheat_noclip)


## The `]` super cheat: every ghost flees instead of hunting, so the maze can be
## eaten at leisure. Turning them all green is the tell; there is nothing to read.
## Reset by `_restart`, like the other games' cheats are reset by a new run.
func _toggle_super_cheat() -> void:
	_super_cheat = not _super_cheat
	for ghost in _ghosts:
		ghost.set_super_flee(_super_cheat)


func _restart() -> void:
	_score = 0
	_level = 1
	_lives = int(_cfg.player.start_lives)
	_super_cheat = false
	_cheat_noclip = false
	_pacman.set_noclip(false)
	for ghost in _ghosts:
		ghost.set_super_flee(false)
	_maze.load_layout(_cfg.assets.layout)
	_start_level(true)


# --- audio ------------------------------------------------------------------

var _pellet_anim_t := 0.0


## The power pellets blink; step the frame on a slow clock.
func _tick_pellet_animation(delta: float) -> void:
	_pellet_anim_t += delta
	if _pellet_anim_t < 0.22:
		return
	_pellet_anim_t = 0.0
	_pellets.advance_animation()


func _update_siren() -> void:
	var hunting := 0
	for ghost in _ghosts:
		if ghost.state == PacmanGhost.State.CHASE or ghost.state == PacmanGhost.State.SCATTER:
			hunting += 1
	var step := clampi(_level - 1, 0, 3) if _fright_timer <= 0.0 else -1
	if hunting == 0:
		step = -1
	_audio.set_siren(step)
