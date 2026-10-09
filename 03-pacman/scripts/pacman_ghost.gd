class_name PacmanGhost
extends Area2D
## One ghost. All four share a state machine and the same junction logic; only
## the chase target differs (see _chase_target). Ghosts never reverse on their
## own — a reversal only happens on a state change, as in the original.

enum State { HOUSE, CHASE, SCATTER, FRIGHTENED, EATEN }

const TURN_TOLERANCE := 0.6
## Row above the house door; a released ghost is free once it is north of this.
const HOUSE_EXIT_ROW := 12
## Short pause in the house after an eaten ghost gets home.
const REVIVE_PAUSE := 0.7
## Tie-break order at a junction (up first, as in the arcade original).
const PREFERRED: Array[Vector2i] = [
	PacmanGrid.DIR_UP, PacmanGrid.DIR_LEFT, PacmanGrid.DIR_DOWN, PacmanGrid.DIR_RIGHT,
]

## The super cheat's colour, shared with the other games.
const SUPER_COLOR := Color("00E676")

var id := "blinky"
var tint := Color.RED
## The `]` super cheat. Kept out of State on purpose: chasing and fleeing share
## every other rule (junction choice, no reversing, house discipline), so this
## only swaps WHICH tile the ghost aims at.
var super_flee := false
var state: int = State.HOUSE
## Base speeds by situation; Game scales them per level via `level_scale`.
var speeds := {"normal": 95.0, "fright": 62.0, "tunnel": 58.0, "eaten": 210.0}
var level_scale := 1.0
## Set by Game: returns { "cell": Vector2i, "dir": Vector2i, "blinky_cell": Vector2i }
var pursuit: Callable

var dir := PacmanGrid.DIR_NONE
var target_cell := Vector2i.ZERO   ## last computed target — exposed for the debug overlay
## Set by Game during the last seconds of a power pellet: frightened ghosts
## then alternate between the blue and white frames.
var fright_flashing := false

@onready var _collision: CollisionShape2D = $Collision
@onready var _body: Sprite2D = $Visual/Body
@onready var _eyes: Sprite2D = $Visual/Eyes

var _maze: PacmanMaze
var _sprites: PacmanSprites
var _target_cell := Vector2i.ZERO
## Where the ghost starts the level (Blinky starts outside the house).
var _home_cell := Vector2i(13, 14)
## Where an eaten ghost must return to — always inside the house, whatever the
## start cell was. Using the start cell here sent Blinky wandering outside.
var _nest_cell := Vector2i(13, 14)
var _anim_t := 0.0
var _anim_index := 0
var _rng := RandomNumberGenerator.new()
## True from release until the ghost has cleared the house, so it may use the
## door while still inside.
var _exiting := false
## Counts down the pause in the house before a revived ghost heads out again.
var _exit_timer := 0.0


func setup(ghost_id: String, color: Color, maze: PacmanMaze, sprites: PacmanSprites,
		home: Vector2i, release_at: float) -> void:
	id = ghost_id
	tint = color
	_maze = maze
	_sprites = sprites
	_home_cell = home

	collision_layer = PacmanLayers.GHOST
	collision_mask = 0
	monitoring = false
	monitorable = true
	var shape := CircleShape2D.new()
	shape.radius = PacmanGrid.CELL * 0.4
	_collision.shape = shape

	_body.modulate = tint
	_rng.seed = hash(ghost_id)
	place_at(_home_cell, PacmanGrid.DIR_UP)
	state = State.HOUSE
	_body.visible = release_at <= 0.0


func place_at(cell: Vector2i, facing: Vector2i) -> void:
	_target_cell = cell
	position = PacmanGrid.cell_center(cell)
	dir = facing


func cell() -> Vector2i:
	return PacmanGrid.cell_of(position)


## Leaves the house. Ghosts exit upward through the door on row 12.
func release() -> void:
	state = State.CHASE
	_body.visible = true
	_exiting = true
	dir = PacmanGrid.DIR_UP


## Ghosts may cross the house door on their way out and on their way back in,
## but never while wandering the maze.
func _can_use_door() -> bool:
	if state == State.EATEN or _exiting:
		return true
	return state == State.HOUSE


## The `]` super cheat, set from Game. Repaints immediately so the green lands
## on the same frame as the key press, not on the next animation step.
func set_super_flee(value: bool) -> void:
	super_flee = value
	_refresh_look()


func set_state(new_state: int) -> void:
	if state == new_state:
		return
	# A state change is the only thing allowed to reverse a ghost.
	if new_state == State.FRIGHTENED or state == State.FRIGHTENED or new_state == State.EATEN:
		var back := -dir
		if _maze.is_open(cell() + back, new_state == State.EATEN):
			dir = back
	state = new_state
	_refresh_look()


func _physics_process(delta: float) -> void:
	if state == State.HOUSE:
		# Revived ghosts wait a beat, then head back out on their own.
		if _exit_timer > 0.0:
			_exit_timer -= delta
			if _exit_timer <= 0.0:
				release()
		return
	_advance(_current_speed() * delta)
	_animate(delta)
	# Once clear of the house row the door closes behind it.
	if _exiting and cell().y < HOUSE_EXIT_ROW:
		_exiting = false
	# An eaten ghost that made it home revives and heads back out.
	if state == State.EATEN and cell() == _nest_cell:
		_revive()


func _revive() -> void:
	state = State.HOUSE
	_exiting = false
	_body.visible = true
	_refresh_look()
	_exit_timer = REVIVE_PAUSE


func _current_speed() -> float:
	var base: float
	match state:
		State.FRIGHTENED:
			base = speeds["fright"]
		State.EATEN:
			base = speeds["eaten"]
		_:
			base = speeds["normal"]
	if state != State.EATEN and cell().y == PacmanGrid.TUNNEL_ROW:
		base = speeds["tunnel"]
	return base * level_scale


# --- movement ---------------------------------------------------------------

func _advance(budget: float) -> void:
	var guard := 0
	while budget > 0.0 and guard < 8:
		guard += 1
		var target := PacmanGrid.cell_center(_target_cell)
		var offset := target - position
		var distance := offset.length()
		if distance > TURN_TOLERANCE:
			var travel := minf(budget, distance)
			position += offset / distance * travel
			budget -= travel
			if travel < distance:
				return
			continue
		position = target
		budget = maxf(0.0, budget - distance)
		dir = _choose_direction()
		if dir == PacmanGrid.DIR_NONE:
			return
		_target_cell += dir
		var shift := PacmanGrid.tunnel_shift(_target_cell)
		if shift != Vector2.ZERO:
			_target_cell += PacmanGrid.tunnel_shift_cells(_target_cell)
			position += shift


## Pick the next direction at a junction: never reverse, prefer the neighbour
## closest to the current target, break ties in PREFERRED order.
func _choose_direction() -> Vector2i:
	var here := _target_cell
	var door := _can_use_door()
	var options: Array[Vector2i] = []
	for d in PREFERRED:
		if d == -dir:
			continue
		if _maze.is_open(here + d, door):
			options.append(d)
	if options.is_empty():
		return -dir if _maze.is_open(here - dir, door) else PacmanGrid.DIR_NONE
	if state == State.FRIGHTENED:
		return options[_rng.randi_range(0, options.size() - 1)]
	var target := _pick_target()
	target_cell = target
	var best := options[0]
	var best_distance := PacmanGrid.distance_sq(here + best, target)
	for d in options:
		var distance := PacmanGrid.distance_sq(here + d, target)
		if distance < best_distance:
			best_distance = distance
			best = d
	return best


# --- targeting --------------------------------------------------------------

func _pick_target() -> Vector2i:
	if state == State.EATEN:
		return _nest_cell
	if super_flee and not pursuit.is_null():
		# Pac-Man mirrored through this ghost. Aiming at the reflection of someone
		# is exactly running away from them, and it reuses the junction rule below
		# unchanged — the ghost walks toward a tile it can never reach.
		var pac: Vector2i = pursuit.call()["cell"]
		return cell() * 2 - pac
	if state == State.SCATTER or pursuit.is_null():
		var scatter: Vector2i = PacmanGrid.SCATTER_TARGETS.get(id, _home_cell)
		return scatter
	var info: Dictionary = pursuit.call()
	var pac: Vector2i = info["cell"]
	var pac_dir: Vector2i = info["dir"]
	return _chase_target(pac, pac_dir, info)


## Each ghost reads Pac-Man's position and facing differently — this is what
## makes the four of them behave distinctly.
func _chase_target(pac: Vector2i, pac_dir: Vector2i, info: Dictionary) -> Vector2i:
	match id:
		"blinky":
			return pac
		"pinky":
			# Four cells ahead of Pac-Man (the classic "ambusher").
			return pac + pac_dir * 4
		"inky":
			# Pivot two cells ahead, then double the vector from Blinky.
			var pivot := pac + pac_dir * 2
			var blinky: Vector2i = info.get("blinky_cell", pac)
			return pivot * 2 - blinky
		"clyde":
			# Chases until it gets close, then flees to its corner.
			var here := cell()
			if PacmanGrid.distance_sq(here, pac) > 64:
				return pac
			return PacmanGrid.SCATTER_TARGETS.get("clyde", _home_cell)
	return pac


# --- visuals ----------------------------------------------------------------

func _animate(delta: float) -> void:
	_anim_t += delta
	if _anim_t >= 0.12:
		_anim_t = 0.0
		_anim_index += 1
		_refresh_look()


func _refresh_look() -> void:
	match state:
		State.FRIGHTENED:
			_body.visible = true
			_body.modulate = Color.WHITE
			var tag := "flash" if (fright_flashing and (_anim_index % 2) == 1) else "blue"
			_body.texture = _sprites.texture("ghost_fright", tag, _anim_index)
			_eyes.visible = false
		State.EATEN:
			_body.visible = false
			_eyes.visible = true
		_:
			_body.visible = true
			# All four turning green is the whole explanation of the cheat.
			_body.modulate = SUPER_COLOR if super_flee else tint
			_body.texture = _sprites.texture("ghost_body", "walk", _anim_index)
			_eyes.visible = true
	_eyes.texture = _sprites.texture("ghost_eyes", PacmanGrid.dir_name(dir), 0)


## Used by the debug overlay to draw the ghost's intent.
func debug_state_name() -> String:
	match state:
		State.HOUSE: return "HOUSE"
		State.CHASE: return "CHASE"
		State.SCATTER: return "SCATTER"
		State.FRIGHTENED: return "FRIGHT"
		State.EATEN: return "EATEN"
	return "?"
