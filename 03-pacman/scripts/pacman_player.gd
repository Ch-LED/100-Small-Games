class_name PacmanPlayer
extends Area2D
## Pac-Man: moves cell-to-cell, decides only when it reaches a cell centre.
## Direction presses are buffered as `desired`, so a turn entered slightly
## early still happens at the next junction — the classic feel.

signal pellet_eaten(kind: int, cell: Vector2i)

const TURN_TOLERANCE := 0.6   ## px; avoids jitter when snapping to a centre

var speed := 105.0
var dir := PacmanGrid.DIR_NONE
var desired := PacmanGrid.DIR_NONE
var dying := false

@onready var _collision: CollisionShape2D = $Collision
@onready var _sprite: Sprite2D = $Visual/Sprite

var _maze: PacmanMaze
var _sprites: PacmanSprites
var _target_cell := Vector2i.ZERO
var _anim_t := 0.0
var _anim_index := 0


## Call after the node is in the tree — it relies on @onready children.
func setup(maze: PacmanMaze, sprites: PacmanSprites, start_cell: Vector2i,
		move_speed: float) -> void:
	_maze = maze
	_sprites = sprites
	speed = move_speed

	collision_layer = PacmanLayers.PLAYER
	collision_mask = 0
	monitoring = false
	monitorable = true

	var shape := CircleShape2D.new()
	shape.radius = PacmanGrid.CELL * 0.4
	_collision.shape = shape

	place_at(start_cell)


func place_at(cell: Vector2i) -> void:
	_target_cell = cell
	position = PacmanGrid.cell_center(cell)
	dir = PacmanGrid.DIR_NONE
	desired = PacmanGrid.DIR_NONE
	# Respawn must undo the death pose, otherwise the ship stays as the last
	# (empty) death frame.
	dying = false
	_anim_index = 0
	_refresh_sprite()


func cell() -> Vector2i:
	return PacmanGrid.cell_of(position)


func set_desired(direction: Vector2i) -> void:
	desired = direction


func _physics_process(delta: float) -> void:
	if dying:
		return
	_advance(speed * delta)
	_animate(delta)
	_eat_here()


# --- movement ---------------------------------------------------------------

## Walks `budget` pixels toward the current target centre, resolving decisions
## whenever a centre is reached (possibly several per frame at high speed).
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
		_decide()
		if dir == PacmanGrid.DIR_NONE:
			return
		var next := _target_cell + dir
		if not _maze.is_open(next, false):
			dir = PacmanGrid.DIR_NONE
			return
		_target_cell = next
		# Walked off the tunnel edge: carry cell and position across together.
		var shift := PacmanGrid.tunnel_shift(_target_cell)
		if shift != Vector2.ZERO:
			_target_cell += PacmanGrid.tunnel_shift_cells(_target_cell)
			position += shift


## At a cell centre: apply the buffered turn if it is legal, otherwise keep
## going while the current direction stays open.
func _decide() -> void:
	var here := _target_cell
	if desired != PacmanGrid.DIR_NONE and _maze.is_open(here + desired, false):
		dir = desired
		desired = PacmanGrid.DIR_NONE
	elif dir != PacmanGrid.DIR_NONE and not _maze.is_open(here + dir, false):
		dir = PacmanGrid.DIR_NONE


func _eat_here() -> void:
	var here := cell()
	var kind := _maze.take_pellet(here)
	if kind != PacmanMaze.PELLET_NONE:
		pellet_eaten.emit(kind, here)


# --- visuals ----------------------------------------------------------------

func _animate(delta: float) -> void:
	if dir == PacmanGrid.DIR_NONE:
		return
	_anim_t += delta
	if _anim_t < 0.055:
		return
	_anim_t = 0.0
	_anim_index += 1
	_refresh_sprite()


func _refresh_sprite() -> void:
	var facing := dir
	if facing == PacmanGrid.DIR_NONE:
		facing = PacmanGrid.DIR_RIGHT
	# The art ships up/down/right only — facing left is the right set mirrored.
	var tag := PacmanGrid.dir_name(facing)
	var mirrored := false
	if tag == "left":
		tag = "right"
		mirrored = true
	var frames := _sprites.frame_count("pacman", tag)
	_sprite.texture = _sprites.texture("pacman", tag, _anim_index if frames > 0 else 0)
	_sprite.flip_h = mirrored


func play_death(index: int) -> void:
	dying = true
	dir = PacmanGrid.DIR_NONE
	_sprite.flip_h = false
	_sprite.texture = _sprites.texture("pacman", "death", index)


func stop() -> void:
	dir = PacmanGrid.DIR_NONE
	desired = PacmanGrid.DIR_NONE
